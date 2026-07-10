#!/usr/bin/env bash

# Extra function to get container metrics

monitor_help() {
cat << EOF
${BOLD_CYAN}dockero monitor ${GREEN}<top|stats|health|logs|watch> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Monitor Docker containers.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}top [container]${RESET_COLOR}                         Show processes.
     - ${GREEN}stats [container] [-f]${RESET_COLOR}                  Resource usage (-f to follow).
     - ${GREEN}health [container]${RESET_COLOR}                      Health status.
     - ${GREEN}logs <container> [-f] [-t <lines>]${RESET_COLOR}      View logs.
     - ${GREEN}watch [container] [--interval <s>] [--duration <s>]${RESET_COLOR}  Continuous monitoring.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker top / stats / inspect / logs${RESET_COLOR}
EOF
}

monitor() {
    local subcommand="${args[1]:-}"
    
    if [[ -z "$subcommand" ]]; then
        log.hint "Usage: dockero monitor <top|stats|health|logs|watch> [options]"
        return 1
    fi
    
    case "$subcommand" in
        "top")
            monitor_top "${args[@]:2}"
            ;;
        "stats")
            monitor_stats "${args[@]:2}"
            ;;
        "health")
            monitor_health "${args[@]:2}"
            ;;
        "logs")
            monitor_logs "${args[@]:2}"
            ;;
        "watch")
            monitor_watch "${args[@]:2}"
            ;;
        *)
            log.error "Unknown monitor subcommand: ${BOLD}$subcommand${RESET_COLOR}"
            log.hint "Usage: dockero monitor <top|stats|health|logs|watch> [options]"
            return 1
            ;;
    esac
}

monitor_top() {
    local container_name="${1:-}"
    
    log.setline "📈 Container Top Processes"

    if [[ -n "$container_name" ]]; then
        log.info "Top processes in container: ${BOLD}$container_name${RESET_COLOR}"
        ${DOCKERO_RUNTIME:-docker} top "$container_name"
    else
        log.info "Running containers:"
        ${DOCKERO_RUNTIME:-docker} ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Command}}" | sed '1s/.*/'"${COLOR_GENERIC}${BOLD}"'&\033[0m/' # Color header using log.sh vars
    fi
}

monitor_stats() {
    local container_name="${1:-}"
    local follow="${params[f]:-false}" # Still using params for flags -f
    
    log.setline "📊 Container Statistics"

    if [[ "$follow" == "true" ]]; then
        if [[ -n "$container_name" ]]; then
            log.info "Live statistics for container: ${BOLD}$container_name${RESET_COLOR}"
            ${DOCKERO_RUNTIME:-docker} stats --no-stream=false "$container_name"
        else
            log.info "Live statistics for all containers"
            ${DOCKERO_RUNTIME:-docker} stats --no-stream=false
        fi
    else
        if [[ -n "$container_name" ]]; then
            log.info "Statistics for container: ${BOLD}$container_name${RESET_COLOR}"
            ${DOCKERO_RUNTIME:-docker} stats --no-stream=true "$container_name"
        else
            log.info "Statistics for all containers"
            ${DOCKERO_RUNTIME:-docker} stats --no-stream=true
        fi
    fi
}

monitor_health() {
    local container_name="${1:-}"
    local container_exists=0
    
    if [[ -z "$container_name" ]]; then
        log.info "Health status for all containers:"
        log.setline "❤️  Container Health Status"

        # Batch inspect all running containers in one call
        local names
        names=$(${DOCKERO_RUNTIME:-docker} ps --format "{{.Names}}" 2>/dev/null)
        [[ -z "$names" ]] && log.warn "No running containers." && return 0

        # Single docker inspect call for all containers
        local inspect_json
        # shellcheck disable=SC2086
        inspect_json=$(${DOCKERO_RUNTIME:-docker} inspect $names 2>/dev/null)

        echo "$names" | while IFS= read -r name; do
            local status image health_status health_color
            status=$(${DOCKERO_RUNTIME:-docker} ps --filter "name=^${name}$" --format "{{.Status}}" 2>/dev/null)
            image=$(${DOCKERO_RUNTIME:-docker} ps --filter "name=^${name}$" --format "{{.Image}}" 2>/dev/null)
            health_status=$(echo "$inspect_json" | jq -r --arg n "$name" \
                '.[] | select(.Name == "/"+$n) | if .State.Health then .State.Health.Status else "N/A" end' 2>/dev/null || echo "N/A")
            health_color="${RESET_COLOR}"
            case "$health_status" in
                healthy)   health_color="${COLOR_DONE}"  ;;
                unhealthy) health_color="${COLOR_ERROR}" ;;
                starting)  health_color="${COLOR_WARN}"  ;;
            esac
            printf "${BOLD}${COLOR_SUB}%-25s${RESET_COLOR} %-35s %-25s ${health_color}%s${RESET_COLOR}\n" \
                "$name" "$status" "$image" "$health_status"
        done
        return 0
    fi
    
    # Check if container exists
    if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        container_exists=1
    fi

    if [[ "$container_exists" -eq 0 ]]; then
        log.error "Container not found: ${BOLD}$container_name${RESET_COLOR}"
        return 1
    fi

    log.setline "❤️  Health Check for ${BOLD}$container_name${RESET_COLOR}"
    local health_json
    health_json=$(${DOCKERO_RUNTIME:-docker} inspect --format='{{json .State.Health}}' "$container_name" 2>/dev/null)

    if [[ -n "$health_json" ]] && [[ "$health_json" != "null" ]]; then
        # Parse with jq
        local status
        status=$(echo "$health_json" | jq -r '.Status')
        local failing_streak
        failing_streak=$(echo "$health_json" | jq -r '.FailingStreak')
        local log_entries
        log_entries=$(echo "$health_json" | jq -r '.Log[] | "\(.Start) - \(.End) (\(.ExitCode)): \(.Output)"')

        local status_color="${RESET_COLOR}"
        if [[ "$status" == "healthy" ]]; then
            status_color="${COLOR_DONE}"
        elif [[ "$status" == "unhealthy" ]]; then
            status_color="${COLOR_ERROR}"
        elif [[ "$status" == "starting" ]]; then
            status_color="${COLOR_WARN}"
        fi

        log.sub "Status: $status"
        log.sub "Failing Streak: $failing_streak"

        if [[ -n "$log_entries" ]]; then
            log.sub "Recent logs:"
            echo "$log_entries" | while IFS= read -r log_line; do
                log.sub "  $log_line"
            done
        fi
    else
        log.warn "Health check not enabled or no health status available for container: ${BOLD}$container_name${RESET_COLOR}"
        log.sub "Use HEALTHCHECK instruction in Dockerfile or --health-cmd at runtime."
    fi
}

monitor_logs() {
    local container_name="${1:-}"
    local follow=false
    local tail="${params[t]:-${params[tail]:-10}}"

    [[ -n "${params[f]+set}" || -n "${params[follow]+set}" ]] && follow=true

    if [[ -z "$container_name" ]]; then
        log.error "Container name required."
        log.hint "Usage: dockero monitor logs <container> [-f] [-t <lines>]"
        return 1
    fi

    log.setline "Logs for ${BOLD}$container_name${RESET_COLOR} (last ${BOLD}$tail${RESET_COLOR} lines)"

    local docker_logs_cmd=("${DOCKERO_RUNTIME:-docker}" logs)
    [[ "$follow" == "true" ]] && docker_logs_cmd+=(-f)
    docker_logs_cmd+=(--tail "$tail" "$container_name")
    "${docker_logs_cmd[@]}"
}

monitor_watch() {
    local container_name="${1:-}"
    local interval="${params[interval]:-5}"
    local duration="${params[duration]:-0}"

    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        log.error "Invalid --interval value. Must be a number."; return 1
    fi
    if ! [[ "$duration" =~ ^[0-9]+$ ]]; then
        log.error "Invalid --duration value. Must be a number."; return 1
    fi

    log.setline "👁️  Container Watch System"
    log.info "Monitoring containers (interval: ${BOLD}$interval${RESET_COLOR}s)${duration:+, duration: ${BOLD}$duration${RESET_COLOR}s}"
    log.sub "Press Ctrl+C to stop monitoring."

    local docker_stats_cmd=("${DOCKERO_RUNTIME:-docker}" stats --no-stream=true)
    [[ -n "$container_name" ]] && docker_stats_cmd+=("$container_name")

    local count=0 max_iterations=999999
    if [[ "$duration" -gt 0 ]]; then
        max_iterations=$(( duration / interval ))
        [[ "$max_iterations" -eq 0 ]] && max_iterations=1
    fi

    while [[ "$count" -lt "$max_iterations" ]]; do
        clear
        echo -e "${COLOR_GENERIC}${BOLD}=== Dockero Container Monitoring ===${RESET_COLOR}"
        echo -e "${COLOR_DATE}$(date): Monitoring containers...\n${RESET_COLOR}"
        "${docker_stats_cmd[@]}"
        sleep "$interval"
        (( count++ ))
    done

    log.done "Monitoring session ended."
}