#!/usr/bin/env bash

# Helper function to get services from compose file
_compose_get_services() {
    local compose_file="$1"
    local -a services=()
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]$ ]]; then
            local service_name
            service_name=$(echo "$line" | sed 's/\[service://g' | sed 's/\]//g' | cut -d':' -f2) # Fixed service_name extraction
            if [[ -n "$service_name" && "$service_name" != "global" ]]; then
                services+=("$service_name")
            fi
        fi
    done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file") # SC2002: Don't use 'cat' to pipe into 'grep'
    echo "${services[@]}"
}

compose() {
    local subcommand="${args[1]:-}" # Safely access subcommand
    
    if [[ -z "$subcommand" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero compose <up|down|start|stop|restart|ps|logs> [options]${RESET_COLOR}"
        return 1
    fi
    
    case "$subcommand" in
        "up")
            compose_up
            ;;
        "down")
            compose_down
            ;;
        "start")
            compose_start
            ;;
        "stop")
            compose_stop
            ;;
        "restart")
            compose_restart
            ;;
        "ps")
            compose_ps
            ;;
        "logs")
            compose_logs "${args[@]:2}"
            ;;
        *)
            log.error "Unknown compose subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
            log.hint "Usage: ${BOLD_YELLOW}dockero compose <up|down|start|stop|restart|ps|logs> [options]${RESET_COLOR}"
            return 1
            ;;
    esac
}

# Find the compose file, looking for environment-specific first then default
find_compose_file() {
    local env_name="${params[env]:-${params[e]:-}}"
    local compose_file=""
    
    # Sanitize env_name to prevent path traversal
    if [[ -n "$env_name" ]]; then
        if [[ ! "$env_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            log.error "Invalid environment name: ${RED}$env_name${RESET_COLOR}. Environment names can only contain alphanumeric characters, underscores, and hyphens."
            return 1
        fi
    fi

    # Check for environment-specific compose file first
    if [[ -n "$env_name" ]]; then
        if [[ -f ".dockero-compose.$env_name" ]]; then
            compose_file=".dockero-compose.$env_name"
        elif [[ -f ".dockero-compose-$env_name" ]]; then
            compose_file=".dockero-compose-$env_name"
        fi
    fi
    
    # Fall back to default if environment-specific not found or no env specified
    if [[ -z "$compose_file" ]]; then
        if [[ -f ".dockero-compose" ]]; then
            compose_file=".dockero-compose"
        elif [[ -f ".dockero-compose.yml" ]]; then
            log.error "Error: ${RED}.dockero-compose.yml${RESET_COLOR} files are not supported. Please use ${BOLD_YELLOW}.dockero-compose${RESET_COLOR} format."
            return 1 # Indicate error
        fi
    fi
    
    echo "$compose_file"
    return 0
}

compose_up() {
    local compose_file
    compose_file=$(find_compose_file) || return 1 # Exit if find_compose_file fails
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (${BOLD_YELLOW}.dockero-compose${RESET_COLOR} or ${BOLD_YELLOW}.dockero-compose.<env>${RESET_COLOR})."
        log.hint "Create a ${BOLD_YELLOW}.dockero-compose${RESET_COLOR} file to define multi-container services."
        return 1
    fi
    
    log.setline "${BOLD_CYAN}⬆️ Compose Up${RESET_COLOR}"
    log.info "Starting services from compose file: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"
    
    # Parse services from compose file using helper
    local services_str
    services_str=$(_compose_get_services "$compose_file")
    local -a services=($services_str) # Re-read into array
    
    if [[ ${#services[@]} -eq 0 ]]; then
        log.warn "No services found in compose file: ${BOLD_YELLOW}$compose_file${RESET_COLOR}."
        return 1
    fi
    
    # Start each service
    for service in "${services[@]}"; do
        log.info "Processing service: ${BOLD_YELLOW}$service${RESET_COLOR}"
        
        # Get service configuration
        local container_name
        container_name=$(inipars.get "service:$service" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$service${RESET_COLOR}."; return 1; }
        local image
        image=$(inipars.get "service:$service" "image" "$compose_file") || { log.error "Failed to get image for service ${RED}$service${RESET_COLOR}."; return 1; }
        local command_str # Renamed to avoid conflicts
        command_str=$(inipars.get "service:$service" "command" "$compose_file")
        local ports
        ports=$(inipars.get "service:$service" "ports" "$compose_file")
        local volumes
        volumes=$(inipars.get "service:$service" "volumes" "$compose_file")
        local environment # All environment variables as a single string
        environment=$(inipars.get "service:$service" "environment" "$compose_file")
        local depends_on # All dependencies as a single string
        depends_on=$(inipars.get "service:$service" "depends_on" "$compose_file")
        local restart_policy
        restart_policy=$(inipars.get "service:$service" "restart" "$compose_file")

        # --- VALIDATION of INI fetched parameters ---
        if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."; return 1; fi
        if ! validate_image_name "$image"; then log.error "Invalid image '${RED}$image${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."; return 1; fi
        
        # Validate ports
        local -a port_args=()
        if [[ -n "$ports" ]]; then
            IFS=',' read -ra port_array <<< "$ports"
            for p in "${port_array[@]}"; do
                if [[ ! "$p" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
                    log.error "Invalid port format '${RED}$p${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}. Expected H:C or C."
                    return 1
                fi
                port_args+=(-p "$p")
            done
        fi

        # Validate volumes
        local -a volume_args=()
        if [[ -n "$volumes" ]]; then
            IFS=',' read -ra vol_array <<< "$volumes"
            for v in "${vol_array[@]}"; do
                if [[ ! "$v" =~ ^[^:]+:[^:]+$ ]]; then # Basic check for host:container format
                    log.error "Invalid volume format '${RED}$v${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}. Expected HOST_PATH:CONTAINER_PATH."
                    return 1
                fi
                volume_args+=(-v "$v")
            done
        fi

        # Validate environment variables
        local -a env_args=()
        if [[ -n "$environment" ]]; then
            IFS=',' read -ra env_array <<< "$environment"
            for e_var in "${env_array[@]}"; do
                if [[ ! "$e_var" =~ ^[^=]+=[^=]*$ ]]; then # Basic check for KEY=VALUE format
                    log.error "Invalid environment variable format '${RED}$e_var${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}. Expected KEY=VALUE."
                    return 1
                fi
                # Further check value for malicious shell commands here if needed, but docker handles it.
                env_args+=(-e "$e_var")
            done
        fi

        # Validate restart policy
        if [[ -n "$restart_policy" ]]; then
            if [[ ! "$restart_policy" =~ ^(no|always|on-failure|unless-stopped)$ ]]; then
                log.error "Invalid restart policy '${RED}$restart_policy${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."
                return 1
            fi
        fi

        # Check dependencies if specified
        if [[ -n "$depends_on" ]]; then
            local dep_service
            local -a deps=()
            IFS=', ' read -ra deps <<< "$depends_on"
            for dep_service in "${deps[@]}"; do
                local escaped_dep_service=$(_inipars_escape_regex "$dep_service") # Escape for regex
                log.sub "Waiting for dependency ${BOLD_YELLOW}$dep_service${RESET_COLOR} to be ready..."
                local max_wait=30
                local count=0
                while [[ $count -lt $max_wait ]]; do
                    if docker ps --format '{{.Names}}' | grep -q "^$escaped_dep_service$"; then
                        log.sub "Dependency ${BOLD_GREEN}$dep_service${RESET_COLOR} is ready."
                        break
                    fi
                    sleep 1
                    ((count++))
                done
                if [[ $count -eq $max_wait ]]; then
                    log.error "Dependency ${RED}$dep_service${RESET_COLOR} not ready after ${max_wait} seconds."
                    return 1
                fi
            done
        fi
        
        # Check if container exists
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            # Container exists, start it if not running
            if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                log.sub "Service ${BOLD_GREEN}$service${RESET_COLOR} already running as ${BOLD_YELLOW}$container_name${RESET_COLOR}."
            else
                log.sub "Starting existing container: ${BOLD_YELLOW}$container_name${RESET_COLOR}."
                docker start "$container_name" > /dev/null || {
                    log.error "Failed to start container: ${RED}$container_name${RESET_COLOR}."
                    return 1
                }
            fi
        else
            # Container doesn't exist, create and start it
            log.sub "Creating and starting container: ${BOLD_YELLOW}$container_name${RESET_COLOR}."
            
            # Use the global docker_run helper
            if ! docker_run "$container_name" "$image" "true" "$command_str" "$volume_mount" "$ports" "$restart_policy" "" ""; then
                log.error "Failed to create container: ${RED}$container_name${RESET_COLOR}."
                return 1
            fi
        fi
    done
    
    log.done "All services started successfully."
    return 0
}

compose_down() {
    local compose_file
    compose_file=$(find_compose_file) || return 1
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (${BOLD_YELLOW}.dockero-compose${RESET_COLOR} or ${BOLD_YELLOW}.dockero-compose.<env>${RESET_COLOR})."
        return 1
    fi
    
    log.setline "${BOLD_CYAN}⬇️ Compose Down${RESET_COLOR}"
    log.info "Stopping and removing services from: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"
    
    # Parse services from compose file using helper
    local services_str
    services_str=$(_compose_get_services "$compose_file")
    local -a services=($services_str) # Re-read into array
    
    # Stop and remove each service in reverse order
    for (( idx=${#services[@]}-1 ; idx>=0 ; idx-- )) ; do
        local service="${services[idx]}"
        local container_name
        container_name=$(inipars.get "service:$service" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$service${RESET_COLOR}."; return 1; }
        
        # Validate container_name before use
        if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."; return 1; fi

        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.info "Stopping service: ${BOLD_YELLOW}$service${RESET_COLOR} (${BOLD_YELLOW}$container_name${RESET_COLOR})."
            if docker stop "$container_name" > /dev/null 2>&1; then
                log.sub "Container ${BOLD_GREEN}$container_name${RESET_COLOR} stopped."
            else
                log.warn "Failed to stop container: ${RED}$container_name${RESET_COLOR}."
            fi
        else
            log.sub "Service ${BOLD_YELLOW}$service${RESET_COLOR} (${BOLD_YELLOW}$container_name${RESET_COLOR}) not running."
        fi
        
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.info "Removing container: ${BOLD_YELLOW}$container_name${RESET_COLOR}."
            if docker rm "$container_name" > /dev/null 2>&1; then
                log.sub "Container ${BOLD_GREEN}$container_name${RESET_COLOR} removed."
            else
                log.warn "Failed to remove container: ${RED}$container_name${RESET_COLOR}."
            fi
        fi
    done
    
    log.done "Compose services stopped and removed."
    return 0
}

compose_start() {
    local compose_file
    compose_file=$(find_compose_file) || return 1

    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (${BOLD_YELLOW}.dockero-compose${RESET_COLOR} or ${BOLD_YELLOW}.dockero-compose.<env>${RESET_COLOR})."
        return 1
    fi

    log.setline "${BOLD_CYAN}▶️ Compose Start${RESET_COLOR}"
    log.info "Starting services from: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"

    # Parse services from compose file using helper
    local services_str
    services_str=$(_compose_get_services "$compose_file")
    local -a services=($services_str) # Re-read into array

    for service in "${services[@]}"; do
        local container_name
        container_name=$(inipars.get "service:$service" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$service${RESET_COLOR}."; return 1; }
        
        # Validate container_name before use
        if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."; return 1; fi

        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                log.sub "Service ${BOLD_YELLOW}$service${RESET_COLOR} already running."
            else
                log.info "Starting service: ${BOLD_YELLOW}$service${RESET_COLOR}."
                docker start "$container_name" > /dev/null 2>&1 && \
                    log.sub "Service ${BOLD_GREEN}$service${RESET_COLOR} started." || \
                    log.error "Failed to start service: ${RED}$service${RESET_COLOR}."
            fi
        else
            log.warn "Container ${BOLD_YELLOW}$container_name${RESET_COLOR} for service ${BOLD_YELLOW}$service${RESET_COLOR} does not exist."
        fi
    done
    
    log.done "Compose start completed."
    return 0
}

compose_stop() {
    local compose_file
    compose_file=$(find_compose_file) || return 1

    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (${BOLD_YELLOW}.dockero-compose${RESET_COLOR} or ${BOLD_YELLOW}.dockero-compose.<env>${RESET_COLOR})."
        return 1
    fi

    log.setline "${BOLD_CYAN}⏹️ Compose Stop${RESET_COLOR}"
    log.info "Stopping services from: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"

    # Parse services from compose file using helper
    local services_str
    services_str=$(_compose_get_services "$compose_file")
    local -a services=($services_str) # Re-read into array

    for service in "${services[@]}"; do
        local container_name
        container_name=$(inipars.get "service:$service" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$service${RESET_COLOR}."; return 1; }
        
        # Validate container_name before use
        if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."; return 1; fi

        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.info "Stopping service: ${BOLD_YELLOW}$service${RESET_COLOR}."
            docker stop "$container_name" > /dev/null 2>&1 && \
                log.sub "Service ${BOLD_GREEN}$service${RESET_COLOR} stopped." || \
                log.error "Failed to stop service: ${RED}$service${RESET_COLOR}."
        else
            log.sub "Service ${BOLD_YELLOW}$service${RESET_COLOR} not running."
        fi
    done
    
    log.done "Compose stop completed."
    return 0
}

compose_ps() {
    local compose_file
    compose_file=$(find_compose_file) || return 1
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (${BOLD_YELLOW}.dockero-compose${RESET_COLOR} or ${BOLD_YELLOW}.dockero-compose.<env>${RESET_COLOR})."
        return 1
    fi
    
    log.setline "${BOLD_CYAN}📊 Compose Status${RESET_COLOR}"
    log.info "Status of services from: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"
    
    printf "${BOLD_WHITE}%-20s %-30s %-25s %-15s${RESET_COLOR}\n" "SERVICE" "CONTAINER" "STATUS" "PORTS"

    # Parse services from compose file using helper
    local services_str
    services_str=$(_compose_get_services "$compose_file")
    local -a services=($services_str) # Re-read into array

    for service in "${services[@]}"; do
        local container_name
        container_name=$(inipars.get "service:$service" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$service${RESET_COLOR}."; return 1; }
        
        # Validate container_name before use
        if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$service${RESET_COLOR}."; return 1; fi

        local status="${BOLD_YELLOW}(not created)${RESET_COLOR}"
        local ports="${BOLD_YELLOW}(none)${RESET_COLOR}"
        
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            local raw_status
            raw_status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
            
            local status_color="${RESET_COLOR}"
            if [[ "$raw_status" == "running" ]]; then status_color="${GREEN}";
            elif [[ "$raw_status" == "exited" ]]; then status_color="${RED}";
            elif [[ "$raw_status" == "paused" ]]; then status_color="${YELLOW}"; fi
            status="${status_color}$raw_status${RESET_COLOR}"

            ports=$(docker port "$container_name" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
            if [[ -n "$ports" ]]; then
                ports="${MAGENTA}$ports${RESET_COLOR}"
            else
                ports="${BOLD_YELLOW}(none)${RESET_COLOR}"
            fi
        fi
        
        printf "${GREEN}%-20s${RESET_COLOR} ${BOLD_YELLOW}%-30s${RESET_COLOR} %-25s %-15s\n" "$service" "$container_name" "$status" "$ports"
    done
    return 0
}

compose_logs() {
    local service_name_arg="$1" # Renamed to avoid conflict with local service_name
    local compose_file
    compose_file=$(find_compose_file) || return 1
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (${BOLD_YELLOW}.dockero-compose${RESET_COLOR} or ${BOLD_YELLOW}.dockero-compose.<env>${RESET_COLOR})."
        return 1
    fi
    
    log.setline "${BOLD_CYAN}📜 Compose Logs${RESET_COLOR}"

    # If no service specified, show logs for all services, otherwise for specific service
    if [[ -z "$service_name_arg" ]]; then
        log.info "Showing logs for all services in: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"
        local services_str
        services_str=$(_compose_get_services "$compose_file")
        local -a services=($services_str) # Re-read into array
        
        for svc in "${services[@]}"; do
            local container_name
            container_name=$(inipars.get "service:$svc" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$svc${RESET_COLOR}."; return 1; }

            # Validate container_name before use
            if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$svc${RESET_COLOR}."; return 1; fi

            if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
                log.setline "${BOLD_CYAN}Logs for service: ${GREEN}$svc${RESET_COLOR}"
                docker logs "$container_name" --tail 50
            fi
        done
    else
        log.info "Showing logs for service: ${BOLD_YELLOW}$service_name_arg${RESET_COLOR} from: ${BOLD_YELLOW}$compose_file${RESET_COLOR}"
        local container_name
        container_name=$(inipars.get "service:$service_name_arg" "container_name" "$compose_file") || { log.error "Failed to get container_name for service ${RED}$service_name_arg${RESET_COLOR}."; return 1; }
        
        if [[ -z "$container_name" ]]; then
            log.error "Service '${RED}$service_name_arg${RESET_COLOR}' not found in compose file ${BOLD_YELLOW}$compose_file${RESET_COLOR}."
            return 1
        fi
        
        # Validate container_name before use
        if ! validate_container_name "$container_name"; then log.error "Invalid container_name '${RED}$container_name${RESET_COLOR}' for service ${RED}$service_name_arg${RESET_COLOR}."; return 1; fi

        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.setline "${BOLD_CYAN}Logs for service: ${GREEN}$service_name_arg${RESET_COLOR}"
            docker logs "$container_name" "${args[@]:3}" # Pass additional args like --tail
        else
            log.error "Container ${RED}$container_name${RESET_COLOR} for service ${RED}$service_name_arg${RESET_COLOR} is not running."
            return 1
        fi
    fi
    return 0
}

compose_restart() {
    log.setline "${BOLD_CYAN}🔄 Compose Restart${RESET_COLOR}"
    log.info "Restarting all services."
    compose_stop || return 1 # Stop all services, exit if failed
    sleep 2  # Brief pause to ensure containers are stopped
    compose_start || return 1 # Start all services, exit if failed
    log.done "All services restarted successfully."
    return 0
}