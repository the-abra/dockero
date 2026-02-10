#!/usr/bin/env bash

# Extra function to get container metrics
monitor() {
    local subcommand="${args[1]}"
    
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
        docker top "$container_name"
    else
        log.info "Running containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Command}}" | sed '1s/.*/'"${COLOR_GENERIC}${BOLD}"'&\033[0m/' # Color header using log.sh vars
    fi
}

monitor_stats() {
    local container_name="${1:-}"
    local follow="${params[f]:-false}" # Still using params for flags -f
    
    log.setline "📊 Container Statistics"

    if [[ "$follow" == "true" ]]; then
        if [[ -n "$container_name" ]]; then
            log.info "Live statistics for container: ${BOLD}$container_name${RESET_COLOR}"
            docker stats --no-stream=false "$container_name"
        else
            log.info "Live statistics for all containers"
            docker stats --no-stream=false
        fi
    else
        if [[ -n "$container_name" ]]; then
            log.info "Statistics for container: ${BOLD}$container_name${RESET_COLOR}"
            docker stats --no-stream=true "$container_name"
        else
            log.info "Statistics for all containers"
            docker stats --no-stream=true
        fi
    fi
}

monitor_health() {
    local container_name="${1:-}"
    local container_exists=0
    
    if [[ -z "$container_name" ]]; then
        log.info "Health status for all containers:"
        log.setline "❤️  Container Health Status"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | tail -n +2 | while IFS= read -r line; do
            local name=$(echo "$line" | awk '{print $1}')
            local status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' "$name" 2>/dev/null || echo "N/A")
            local health_color="${RESET_COLOR}"
            if [[ "$status" == "healthy" ]]; then
                health_color="${COLOR_DONE}"
            elif [[ "$status" == "unhealthy" ]]; then
                health_color="${COLOR_ERROR}"
            elif [[ "$status" == "starting" ]]; then
                health_color="${COLOR_WARN}"
            fi
            printf "${BOLD}${COLOR_SUB}%-25s${RESET_COLOR} %-35s %-25s ${health_color}%s${RESET_COLOR}\n" "$name" "$(echo "$line" | awk '{print $2}')" "$(echo "$line" | awk '{print $3}')" "$status"
        done
        return 0
    fi
    
    # Check if container exists
    if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        container_exists=1
    fi

    if [[ "$container_exists" -eq 0 ]]; then
        log.error "Container not found: ${BOLD}$container_name${RESET_COLOR}"
        return 1
    fi

    log.setline "❤️  Health Check for ${BOLD}$container_name${RESET_COLOR}"
    local health_json
    health_json=$(docker inspect --format='{{json .State.Health}}' "$container_name" 2>/dev/null)

    if [[ $? -eq 0 ]] && [[ -n "$health_json" ]] && [[ "$health_json" != "null" ]]; then
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

        echo -e "  ${BOLD}${COLOR_SUB}Status:${RESET_COLOR} ${status_color}$status${RESET_COLOR}"
        echo -e "  ${BOLD}${COLOR_SUB}Failing Streak:${RESET_COLOR} ${COLOR_WARN}$failing_streak${RESET_COLOR}"

        if [[ -n "$log_entries" ]]; then
            echo -e "  ${BOLD}${COLOR_SUB}Recent logs:${RESET_COLOR}"
            echo "$log_entries" | while IFS= read -r log_line; do
                echo -e "    ${COLOR_HINT}$log_line${RESET_COLOR}"
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
    local tail=10 # Default to 10 lines

    # Parse remaining arguments for flags like -f and -t
    local ARGS_ARRAY=("${@:2}") # All arguments after container_name
    local i=0
    while [[ $i -lt ${#ARGS_ARRAY[@]} ]]; do
        case "${ARGS_ARRAY[$i]}" in
            -f|--follow)
                follow=true
                ;;
            -t|--tail)
                if [[ -n "${ARGS_ARRAY[$((i+1))]}" && ! "${ARGS_ARRAY[$((i+1))]}" =~ ^- ]]; then
                    tail="${ARGS_ARRAY[$((i+1))]}"
                    i=$((i+1)) # Consume the next argument
                else
                    log.error "Missing value for --tail."
                    return 1
                fi
                ;;
        esac
        i=$((i+1))
    done
    
    if [[ -z "$container_name" ]]; then
        log.error "Container name required."
        log.hint "Usage: dockero monitor logs <container> [-f|--follow] [-t|--tail <lines>]"
        return 1
    fi
    
    log.setline "📜 Logs for ${BOLD}$container_name${RESET_COLOR} (last ${BOLD}$tail${RESET_COLOR} lines)"

    local docker_logs_cmd=(docker logs)
    if [[ "$follow" == "true" ]]; then
        docker_logs_cmd+=(-f)
    fi
    docker_logs_cmd+=(--tail "$tail" "$container_name")

    # Execute the docker logs command
    "${docker_logs_cmd[@]}"
}

monitor_watch() {
    local container_name="${1:-}"
    local interval=5 # Default interval
    local duration=0 # Default duration (0 means indefinite)

    # Parse remaining arguments for flags like --interval and --duration
    local ARGS_ARRAY=("${@:2}") # All arguments after container_name
    local i=0
    while [[ $i -lt ${#ARGS_ARRAY[@]} ]]; do
        case "${ARGS_ARRAY[$i]}" in
            --interval)
                if [[ -n "${ARGS_ARRAY[$((i+1))]}" && "${ARGS_ARRAY[$((i+1))]}" =~ ^[0-9]+$ ]]; then
                    interval="${ARGS_ARRAY[$((i+1))]}"
                    i=$((i+1))
                else
                    log.error "Invalid or missing value for --interval. Must be a number."
                    return 1
                fi
                ;;
            --duration)
                if [[ -n "${ARGS_ARRAY[$((i+1))]}" && "${ARGS_ARRAY[$((i+1))]}" =~ ^[0-9]+$ ]]; then
                    duration="${ARGS_ARRAY[$((i+1))]}"
                    i=$((i+1))
                else
                    log.error "Invalid or missing value for --duration. Must be a number."
                    return 1
                fi
                ;;
        esac
        i=$((i+1))
    done

    log.setline "👁️  Container Watch System"
    log.info "Monitoring containers (interval: ${BOLD}$interval${RESET_COLOR}s)${duration:+, duration: ${BOLD}$duration${RESET_COLOR}s}"
    log.sub "Press Ctrl+C to stop monitoring."
    
    local docker_stats_cmd=(docker stats --no-stream=true)
    if [[ -n "$container_name" ]]; then
        docker_stats_cmd+=("$container_name")
    fi
    
    local count=0
    local max_iterations=999999
    if [[ "$duration" -gt 0 ]]; then
        max_iterations=$((duration / interval))
        if [[ "$max_iterations" -eq 0 ]]; then # Ensure at least one iteration if duration < interval
            max_iterations=1
        fi
    fi
    
    while [[ "$count" -lt "$max_iterations" ]]; do
        clear
        echo -e "${COLOR_GENERIC}${BOLD}=== Dockero Container Monitoring ===${RESET_COLOR}" # Use COLOR_GENERIC
        echo -e "${COLOR_DATE}$(date): Monitoring containers...\n${RESET_COLOR}" # Use COLOR_DATE
        
        "${docker_stats_cmd[@]}"
        
        sleep "$interval"
        ((count++))
    done
    
    log.done "Monitoring session ended."
}