#!/usr/bin/env bash

compose() {
    local subcommand="${args[1]}"
    
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "up" && "$subcommand" != "down" && "$subcommand" != "start" && "$subcommand" != "stop" && "$subcommand" != "restart" && "$subcommand" != "ps" && "$subcommand" != "logs" ]]; then
        log.hint "compose <up|down|start|stop|restart|ps|logs> [options]"
        return 1
    fi
    
    case "$subcommand" in
        "up")
            compose_up "${args[2]}"
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
            compose_logs "${args[2]}"
            ;;
        *)
            log.error "Unknown compose subcommand: $subcommand"
            return 1
            ;;
    esac
}

# Find the compose file, looking for environment-specific first then default
find_compose_file() {
    local env="${params[env]:-${params[e]:-}}"
    local compose_file=""
    
    # Check for environment-specific compose file first
    if [[ -n "$env" ]]; then
        if [[ -f ".dockero-compose.$env" ]]; then
            compose_file=".dockero-compose.$env"
        elif [[ -f ".dockero-compose-$env" ]]; then
            compose_file=".dockero-compose-$env"
        fi
    fi
    
    # Fall back to default if environment-specific not found or no env specified
    if [[ -z "$compose_file" ]]; then
        if [[ -f ".dockero-compose" ]]; then
            compose_file=".dockero-compose"
        elif [[ -f ".dockero-compose.yml" ]]; then
            log.warn "YAML format not supported yet, using dockero-compose functionality"
            compose_file=".dockero-compose"
        fi
    fi
    
    echo "$compose_file"
}

compose_up() {
    local force_build="$1"
    local compose_file
    compose_file=$(find_compose_file)
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (.dockero-compose or .dockero-compose.<env>)"
        log.hint "Create a .dockero-compose file to define multi-container services"
        return 1
    fi
    
    log.setline "Compose Up"
    log.info "Starting services from compose file: $compose_file"
    
    # Parse services from compose file
    local services=()
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]$ ]]; then
            # Extract service name from [service:service_name] format
            local service_name=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g' | cut -d':' -f2)
            if [[ -n "$service_name" && "$service_name" != "global" ]]; then
                services+=("$service_name")
            fi
        fi
    done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file")
    
    if [[ ${#services[@]} -eq 0 ]]; then
        log.warn "No services found in compose file"
        return 1
    fi
    
    # Start each service
    for service in "${services[@]}"; do
        log.info "Starting service: $service"
        
        # Get service configuration
        local container_name=$(inipars.get "service:$service" "container_name" "$compose_file")
        local image=$(inipars.get "service:$service" "image" "$compose_file")
        local command=$(inipars.get "service:$service" "command" "$compose_file")
        local ports=$(inipars.get "service:$service" "ports" "$compose_file")
        local volumes=$(inipars.get "service:$service" "volumes" "$compose_file")
        local environment=$(inipars.get "service:$service" "environment" "$compose_file")
        local depends_on=$(inipars.get "service:$service" "depends_on" "$compose_file")
        
        # Check dependencies if specified
        if [[ -n "$depends_on" ]]; then
            local dep_service
            for dep_service in $depends_on; do
                # Wait for dependency to be healthy (simple check - running)
                local max_wait=30
                local count=0
                while [[ $count -lt $max_wait ]]; do
                    if docker ps --format '{{.Names}}' | grep -q "^$dep_service$"; then
                        log.sub "Dependency $dep_service is ready"
                        break
                    fi
                    sleep 1
                    ((count++))
                done
                if [[ $count -eq $max_wait ]]; then
                    log.error "Dependency $dep_service not ready after $max_wait seconds"
                    return 1
                fi
            done
        fi
        
        # Check if container exists
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            # Container exists, start it if not running
            if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                log.sub "Service $service already running as $container_name"
            else
                log.sub "Starting existing container: $container_name"
                docker start "$container_name" > /dev/null || {
                    log.error "Failed to start container: $container_name"
                    return 1
                }
            fi
        else
            # Container doesn't exist, create and start it
            log.sub "Creating and starting container: $container_name"
            
            # Build docker run command
            local docker_cmd="docker run -d --name $container_name"
            
            # Add ports if specified
            if [[ -n "$ports" ]]; then
                IFS=',' read -ra port_array <<< "$ports"
                for port_mapping in "${port_array[@]}"; do
                    docker_cmd="$docker_cmd -p $port_mapping"
                done
            fi
            
            # Add volumes if specified
            if [[ -n "$volumes" ]]; then
                IFS=',' read -ra vol_array <<< "$volumes"
                for volume_mapping in "${vol_array[@]}"; do
                    docker_cmd="$docker_cmd -v $volume_mapping"
                done
            fi
            
            # Add environment variables if specified
            if [[ -n "$environment" ]]; then
                IFS=',' read -ra env_array <<< "$environment"
                for env_var in "${env_array[@]}"; do
                    docker_cmd="$docker_cmd -e $env_var"
                done
            fi
            
            # Add restart policy if specified
            local restart_policy=$(inipars.get "service:$service" "restart" "$compose_file")
            if [[ -n "$restart_policy" ]]; then
                docker_cmd="$docker_cmd --restart $restart_policy"
            else
                docker_cmd="$docker_cmd --restart no"
            fi
            
            # Add the image
            docker_cmd="$docker_cmd $image"
            
            # Add command if specified
            if [[ -n "$command" ]]; then
                docker_cmd="$docker_cmd $command"
            fi
            
            # Execute the docker run command
            if ! eval "$docker_cmd" > /dev/null 2>&1; then
                log.error "Failed to create container: $container_name"
                return 1
            fi
        fi
    done
    
    log.done "All services started successfully"
}

compose_down() {
    local compose_file
    compose_file=$(find_compose_file)
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (.dockero-compose or .dockero-compose.<env>)"
        return 1
    fi
    
    log.setline "Compose Down"
    log.info "Stopping and removing services from: $compose_file"
    
    # Parse services from compose file
    local services=()
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]$ ]]; then
            local service_name=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g' | cut -d':' -f2)
            if [[ -n "$service_name" && "$service_name" != "global" ]]; then
                services+=("$service_name")
            fi
        fi
    done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file")
    
    # Stop and remove each service in reverse order
    for (( idx=${#services[@]}-1 ; idx>=0 ; idx-- )) ; do
        service="${services[idx]}"
        local container_name=$(inipars.get "service:$service" "container_name" "$compose_file")
        
        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.info "Stopping service: $service ($container_name)"
            if docker stop "$container_name" > /dev/null 2>&1; then
                log.sub "Container stopped"
            else
                log.warn "Failed to stop container: $container_name"
            fi
        else
            log.sub "Service $service ($container_name) not running"
        fi
        
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.info "Removing container: $container_name"
            if docker rm "$container_name" > /dev/null 2>&1; then
                log.sub "Container removed"
            else
                log.warn "Failed to remove container: $container_name"
            fi
        fi
    done
    
    log.done "Compose services stopped and removed"
}

compose_start() {
    local compose_file
    compose_file=$(find_compose_file)
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (.dockero-compose or .dockero-compose.<env>)"
        return 1
    fi
    
    log.setline "Compose Start"
    log.info "Starting services from: $compose_file"
    
    # Parse services and start them
    local services=()
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]$ ]]; then
            local service_name=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g' | cut -d':' -f2)
            if [[ -n "$service_name" && "$service_name" != "global" ]]; then
                services+=("$service_name")
            fi
        fi
    done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file")
    
    for service in "${services[@]}"; do
        local container_name=$(inipars.get "service:$service" "container_name" "$compose_file")
        
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                log.sub "Service $service already running"
            else
                log.info "Starting service: $service"
                docker start "$container_name" > /dev/null 2>&1 && \
                    log.sub "Service $service started" || \
                    log.error "Failed to start service: $service"
            fi
        else
            log.warn "Container $container_name for service $service does not exist"
        fi
    done
    
    log.done "Compose start completed"
}

compose_stop() {
    local compose_file
    compose_file=$(find_compose_file)
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (.dockero-compose or .dockero-compose.<env>)"
        return 1
    fi
    
    log.setline "Compose Stop"
    log.info "Stopping services from: $compose_file"
    
    # Parse services and stop them
    local services=()
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]$ ]]; then
            local service_name=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g' | cut -d':' -f2)
            if [[ -n "$service_name" && "$service_name" != "global" ]]; then
                services+=("$service_name")
            fi
        fi
    done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file")
    
    for service in "${services[@]}"; do
        local container_name=$(inipars.get "service:$service" "container_name" "$compose_file")
        
        if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.info "Stopping service: $service"
            docker stop "$container_name" > /dev/null 2>&1 && \
                log.sub "Service $service stopped" || \
                log.error "Failed to stop service: $service"
        else
            log.sub "Service $service not running"
        fi
    done
    
    log.done "Compose stop completed"
}

compose_ps() {
    local compose_file
    compose_file=$(find_compose_file)
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (.dockero-compose or .dockero-compose.<env>)"
        return 1
    fi
    
    log.setline "Compose Status"
    log.info "Status of services from: $compose_file"
    
    printf "%-20s %-30s %-25s %-15s\n" "SERVICE" "CONTAINER" "STATUS" "PORTS"
    
    # Parse services and get their status
    local services=()
    while IFS= read -r line; do
        if [[ $line =~ ^\[.*\]$ ]]; then
            local service_name=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g' | cut -d':' -f2)
            if [[ -n "$service_name" && "$service_name" != "global" ]]; then
                services+=("$service_name")
            fi
        fi
    done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file")
    
    for service in "${services[@]}"; do
        local container_name=$(inipars.get "service:$service" "container_name" "$compose_file")
        local status="(not created)"
        local ports="(none)"
        
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
            ports=$(docker port "$container_name" 2>/dev/null | tr '\n' ',' | sed 's/,$//')
        fi
        
        printf "%-20s %-30s %-25s %-15s\n" "$service" "$container_name" "$status" "$ports"
    done
}

compose_logs() {
    local service_name="$1"
    local compose_file
    compose_file=$(find_compose_file)
    
    if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]]; then
        log.error "No compose file found (.dockero-compose or .dockero-compose.<env>)"
        return 1
    fi
    
    # If no service specified, show logs for all services, otherwise for specific service
    if [[ -z "$service_name" ]]; then
        # Show logs for all services
        local services=()
        while IFS= read -r line; do
            if [[ $line =~ ^\[.*\]$ ]]; then
                local svc_name=$(echo "$line" | sed 's/\[//g' | sed 's/\]//g' | cut -d':' -f2)
                if [[ -n "$svc_name" && "$svc_name" != "global" ]]; then
                    services+=("$svc_name")
                fi
            fi
        done < <(grep '^\[service:' "$compose_file" 2>/dev/null || grep '^\[.*\]$' "$compose_file")
        
        for svc in "${services[@]}"; do
            local container_name=$(inipars.get "service:$svc" "container_name" "$compose_file")
            if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
                log.setline "Logs for service: $svc"
                docker logs "$container_name" --tail 50
            fi
        done
    else
        # Show logs for specific service
        local container_name=$(inipars.get "service:$service_name" "container_name" "$compose_file")
        if [[ -z "$container_name" ]]; then
            log.error "Service '$service_name' not found in compose file"
            return 1
        fi
        
        if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
            log.setline "Logs for service: $service_name"
            docker logs "$container_name"
        else
            log.error "Container $container_name for service $service_name is not running"
            return 1
        fi
    fi
}

compose_restart() {
    compose_stop
    sleep 2  # Brief pause to ensure containers are stopped
    compose_start
}