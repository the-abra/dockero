#!/usr/bin/env bash

# Extra function to get container metrics
monitor() {
    local subcommand="${args[1]}"
    
    case "$subcommand" in
        "top"|"stats"|"health"|"logs"|"watch")
            shift 2  # Remove 'monitor' and subcommand from args
            "monitor_$subcommand" "$@"
            ;;
        "")
            log.error "Subcommand required. Use: dockero monitor [top|stats|health|logs|watch]"
            return 1
            ;;
        *)
            log.error "Unknown monitor subcommand: $subcommand"
            log.hint "Use: dockero monitor [top|stats|health|logs|watch]"
            return 1
            ;;
    esac
}

monitor_top() {
    local container_name="${args[1]:-""}"
    
    if [[ -n "$container_name" ]]; then
        log.info "Top processes in container: $container_name"
        docker top "$container_name"
    else
        log.info "Running containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Command}}"
    fi
}

monitor_stats() {
    local container_name="${args[1]:-""}"
    local follow="${params[f]:-false}"
    
    if [[ "$follow" == "true" ]]; then
        if [[ -n "$container_name" ]]; then
            log.info "Live statistics for container: $container_name"
            docker stats --no-stream=false "$container_name"
        else
            log.info "Live statistics for all containers"
            docker stats --no-stream=false
        fi
    else
        if [[ -n "$container_name" ]]; then
            log.info "Statistics for container: $container_name"
            docker stats --no-stream=true "$container_name"
        else
            log.info "Statistics for all containers"
            docker stats --no-stream=true
        fi
    fi
}

monitor_health() {
    local container_name="${args[1]:-""}"
    
    if [[ -n "$container_name" ]]; then
        log.info "Checking health of container: $container_name"
        local health_status
        health_status=$(docker inspect --format='{{json .State.Health}}' "$container_name" 2>/dev/null)

        if [[ $? -eq 0 ]] && [[ -n "$health_status" ]] && [[ "$health_status" != "null" ]]; then
            # Parse the health status
            local status
            status=$(echo "$health_status" | grep -o '"Status":"[^"]*"' | cut -d'"' -f4)
            local failing_streak
            failing_streak=$(echo "$health_status" | grep -o '"FailingStreak":[0-9]*' | cut -d':' -f2)

            echo "  Status: $status"
            echo "  Failing Streak: $failing_streak"

            # Show recent health check logs
            local log_output
            log_output=$(echo "$health_status" | grep -o '"Log":\[[^]]*\]' | head -c 200)
            if [[ -n "$log_output" ]]; then
                echo "  Recent logs: $log_output"
            fi
        else
            log.warn "Health check not enabled for container: $container_name"
            log.sub "Use HEALTHCHECK instruction in Dockerfile or --health-cmd at runtime"
        fi
    else
        log.info "Health status for all containers:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | while IFS= read -r line; do
            if [[ "$line" =~ ^CONTAINER ]]; then
                echo "$line"
                continue
            fi

            local name
            name=$(echo "$line" | awk '{print $1}')
            if [[ -n "$name" && "$name" != "NAMES" ]]; then
                local status
                status=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' "$name" 2>/dev/null || echo "N/A")
                echo "$line $status" | awk '{print $1 "\t" $2 "\t" $3 "\t" $4}'
            fi
        done
    fi
}

monitor_logs() {
    local container_name="${args[1]}"
    local follow="${params[f]:-false}"
    local tail="${params[t]:-10}"
    
    if [[ -z "$container_name" ]]; then
        log.error "Container name required"
        log.hint "Usage: dockero monitor logs <container> [-f] [-t <lines>]"
        return 1
    fi
    
    log.info "Logs for container: $container_name (last $tail lines)"

    if [[ "$follow" == "true" ]]; then
        docker logs -f --tail "$tail" "$container_name"
    else
        docker logs --tail "$tail" "$container_name"
    fi
}

monitor_watch() {
    local container_name="${args[1]:-""}"
    local interval="${params[interval]:-5}"
    local duration="${params[duration]:-false}"
    
    log.info "Monitoring containers (interval: ${interval}s)${duration:+, duration: ${duration}s}"
    
    local cmd="docker stats --no-stream=true"
    if [[ -n "$container_name" ]]; then
        cmd="$cmd $container_name"
    fi
    
    local count=0
    local max_iterations=999999
    if [[ -n "$duration" && "$duration" != "false" ]]; then
        max_iterations=$((duration / interval))
    fi
    
    while [[ $count -lt $max_iterations ]]; do
        clear
        echo -e "$(tput setaf 4)=== Dockero Container Monitoring ===$(tput sgr0)"
        echo -e "$(date): Monitoring containers...\n"
        
        eval "$cmd"
        
        sleep "$interval"
        ((count++))
    done
}