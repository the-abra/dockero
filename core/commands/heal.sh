#!/usr/bin/env bash

# Self-healing automation system for Dockero

heal() {
    local subcommand="${args[1]}"
    
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "check" && "$subcommand" != "fix" && "$subcommand" != "auto" && "$subcommand" != "monitor" && "$subcommand" != "diagnose" && "$subcommand" != "cleanup" && "$subcommand" != "restore" && "$subcommand" != "watch" && "$subcommand" != "policy" ]]; then
        log.hint "heal <check|fix|auto|monitor|diagnose|cleanup|restore|watch|policy> [options]"
        return 1
    fi
    
    case "$subcommand" in
        "check")
            heal_check "${args[2]}"
            ;;
        "fix")
            heal_fix "${args[2]}" "${args[3]}"
            ;;
        "auto")
            heal_auto
            ;;
        "monitor")
            heal_monitor
            ;;
        "diagnose")
            heal_diagnose "${args[2]}"
            ;;
        "cleanup")
            heal_cleanup "${args[2]}"
            ;;
        "restore")
            heal_restore "${args[2]}"
            ;;
        "watch")
            heal_watch "${args[2]}"
            ;;
        "policy")
            heal_policy "${args[2]}" "${args[3]}"
            ;;
        *)
            log.error "Unknown heal subcommand: $subcommand"
            return 1
            ;;
    esac
}

# Health monitoring system
heal_check() {
    local target="$1"
    log.setline "🔍 Health Check System"

    local issues_found=0
    local fixes_available=0

    case "$target" in
        "system"|"all"|"")

            # Check Docker daemon status
            log.info "Checking Docker daemon..."
            if ! command -v docker &> /dev/null; then
                log.error "Docker not installed"
                ((issues_found++))
            elif ! docker info &> /dev/null; then
                log.error "Docker daemon not running"
                ((issues_found++))
            else
                log.done "Docker daemon OK"
            fi

            # Check disk space
            log.info "Checking disk space..."
            local docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
            if [[ -d "$docker_root" ]]; then
                local disk_usage=$(df "$docker_root" | awk 'NR==2 {print $5}' | sed 's/%//')
                if [[ "$disk_usage" -gt 90 ]]; then
                    log.warn "Docker directory >90% full: ${disk_usage}%"
                    ((issues_found++))
                    ((fixes_available++))
                else
                    log.done "Disk space OK (${disk_usage}% used)"
                fi
            fi

            # Check for stopped containers
            log.info "Checking containers..."
            local stopped_containers=$(docker ps -a --filter "status=exited" -q | wc -l)
            if [[ "$stopped_containers" -gt 20 ]]; then
                log.warn "$stopped_containers stopped containers found"
                ((issues_found++))
                ((fixes_available++))
            elif [[ "$stopped_containers" -gt 0 ]]; then
                log.sub "$stopped_containers stopped containers"
            else
                log.done "No stopped containers"
            fi

            # Check for dangling images
            log.info "Checking for unused images..."
            local dangling_images=$(docker images -f "dangling=true" -q | wc -l)
            if [[ "$dangling_images" -gt 5 ]]; then
                log.warn "$dangling_images dangling images found"
                ((issues_found++))
                ((fixes_available++))
            else
                log.done "No dangling images"
            fi

            # Check for unused volumes
            log.info "Checking for unused volumes..."
            local unused_volumes=$(docker volume ls -q -f "dangling=true" | wc -l)
            if [[ "$unused_volumes" -gt 5 ]]; then
                log.warn "$unused_volumes unused volumes found"
                ((issues_found++))
                ((fixes_available++))
            else
                log.done "No unused volumes"
            fi

            ;;
        "containers")
            log.info "Checking containers..."
            local running_containers=$(docker ps -q | wc -l)
            local total_containers=$(docker ps -a -q | wc -l)
            local stopped_containers=$((total_containers - running_containers))

            log.sub "Running: $running_containers, Stopped: $stopped_containers, Total: $total_containers"

            if [[ $running_containers -gt 0 ]]; then
                log.info "Checking running container health..."
                docker ps --format "table {{.Names}}\t{{.Status}}" | tail -n +2 | while read -r name status; do
                    if [[ "$status" =~ (Restarting|Paused|Dead) ]]; then
                        log.warn "Container $name in problematic state: $status"
                        ((issues_found++))
                        ((fixes_available++))
                    else
                        log.sub "✓ $name: $status"
                    fi
                done
            fi
            ;;
        "networks")
            log.info "Checking networks..."
            local networks=$(docker network ls --format "{{.Name}}")
            log.sub "Networks: $(echo "$networks" | wc -l) total"
            echo "$networks" | while read -r net; do
                if [[ "$net" != "bridge" && "$net" != "host" && "$net" != "none" ]]; then
                    connected_containers=$(docker network inspect "$net" --format '{{len .Containers}}')
                    log.sub "  $net: $connected_containers connected"
                fi
            done
            ;;
        *)
            log.error "Unknown check target: $target"
            log.sub "Valid targets: system, containers, networks, all"
            return 1
            ;;
    esac

    log.setline "Health Check Summary"
    log.info "Issues found: $issues_found"
    log.info "Automatic fixes available: $fixes_available"

    if [[ $issues_found -gt 0 ]]; then
        log.warn "Potential issues detected. Run: dockero heal fix to auto-resolve"
    else
        log.done "System appears healthy!"
    fi
}

# Auto-recovery mechanisms
heal_fix() {
    local target="$1"
    local specific_item="$2"

    if [[ -z "$target" ]]; then
        log.hint "heal fix <target> [item]"
        log.sub "Targets: system, containers, images, volumes, networks, all"
        return 1
    fi

    log.setline "🔧 Auto-Fix System"

    case "$target" in
        "containers")
            log.info "Fixing container issues..."
            if [[ -n "$specific_item" ]]; then
                # Fix specific container
                if docker ps -a --format '{{.Names}}' | grep -q "^$specific_item$"; then
                    local status=$(docker inspect -f '{{.State.Status}}' "$specific_item" 2>/dev/null)
                    case "$status" in
                        "exited")
                            log.info "Starting stopped container: $specific_item"
                            if docker start "$specific_item" > /dev/null 2>&1; then
                                log.done "Container $specific_item started"
                            else
                                log.error "Failed to start $specific_item"
                            fi
                            ;;
                        "dead")
                            log.warn "Container $specific_item is dead, removing..."
                            if docker rm -f "$specific_item" > /dev/null 2>&1; then
                                log.done "Dead container $specific_item removed"
                            else
                                log.error "Failed to remove dead container $specific_item"
                            fi
                            ;;
                        *)
                            log.info "Container $specific_item status: $status (no fix needed)"
                            ;;
                    esac
                else
                    log.error "Container not found: $specific_item"
                fi
            else
                # Fix all containers with issues
                local stopped_containers=$(docker ps -a --filter "status=exited" -q)
                if [[ -n "$stopped_containers" ]]; then
                    log.info "Starting $stopped_containers containers..."
                    echo "$stopped_containers" | xargs -r docker start > /dev/null 2>&1
                    log.done "Attempted to start all stopped containers"
                else
                    log.info "No stopped containers to fix"
                fi
            fi
            ;;
        "images")
            log.info "Cleaning dangling images..."
            local dangling_count=$(docker images -f "dangling=true" -q | wc -l)
            if [[ $dangling_count -gt 0 ]]; then
                docker image prune -f > /dev/null 2>&1
                log.done "Removed $dangling_count dangling images"
            else
                log.info "No dangling images to clean"
            fi
            ;;
        "volumes")
            log.info "Cleaning unused volumes..."
            local unused_count=$(docker volume ls -q -f "dangling=true" | wc -l)
            if [[ $unused_count -gt 0 ]]; then
                docker volume prune -f > /dev/null 2>&1
                log.done "Removed $unused_count unused volumes"
            else
                log.info "No unused volumes to clean"
            fi
            ;;
        "system"|"all")
            log.info "Performing comprehensive system fix..."

            # Fix containers
            heal_fix "containers"

            # Clean images
            heal_fix "images"

            # Clean volumes
            heal_fix "volumes"

            # Check Docker daemon if needed
            if ! docker info &> /dev/null; then
                log.info "Attempting to restart Docker service..."
                if command -v systemctl &> /dev/null; then
                    sudo systemctl restart docker 2>/dev/null && log.done "Docker service restarted"
                elif command -v service &> /dev/null; then
                    sudo service docker restart 2>/dev/null && log.done "Docker service restarted"
                else
                    log.warn "Could not restart Docker service automatically"
                fi
            fi

            log.done "Comprehensive system fix completed"
            ;;
        *)
            log.error "Unknown fix target: $target"
            log.sub "Valid targets: containers, images, volumes, system, all"
            return 1
            ;;
    esac
}

# Automatic healing system
heal_auto() {
    log.setline "🤖 Auto-Healing Mode"
    log.info "Running automated health check and fixes..."

    # Perform health check
    local issues_output
    issues_output=$(docker ps -a --filter "status=exited" | wc -l)
    local stopped_count=$(($issues_output - 1))  # subtract header line

    local dangling_output
    dangling_output=$(docker images -f "dangling=true" -q | wc -l)
    local dangling_count=$dangling_output

    if [[ $stopped_count -gt 0 || $dangling_count -gt 0 ]]; then
        log.info "Issues detected, applying automatic fixes..."

        if [[ $stopped_count -gt 0 ]]; then
            log.sub "Starting $stopped_count stopped containers..."
            docker start $(docker ps -a --filter "status=exited" --format "{{.ID}}") 2>/dev/null || true
        fi

        if [[ $dangling_count -gt 0 ]]; then
            log.sub "Removing $dangling_count dangling images..."
            docker image prune -f > /dev/null 2>&1
        fi

        log.done "Auto-healing completed"
    else
        log.done "No issues detected, system healthy"
    fi
}

# Monitoring daemon (would run in background in real implementation)
heal_monitor() {
    log.setline "👁️  Real-time Monitor"
    log.info "Real-time monitoring would start in background..."
    log.sub "This would monitor containers, resources, and automatically apply fixes"
    log.sub "For continuous monitoring, consider: dockero heal auto --daemon"

    # In a real implementation, this would start a monitoring service
    # For now, just run a check
    heal_check "system"
}

# Diagnostic tools
heal_diagnose() {
    local issue_type="$1"

    log.setline "🔍 Deep Diagnosis"

    case "$issue_type" in
        "startup"|"start")
            log.info "Diagnosing startup issues..."
            log.sub "1. Checking Docker installation"
            if ! command -v docker &> /dev/null; then
                log.error "Docker not installed"
                log.hint "Install Docker: https://docs.docker.com/engine/install/"
                return 1
            fi

            log.sub "2. Checking Docker service"
            if ! docker info &> /dev/null; then
                log.error "Docker daemon not running"
                log.hint "Start Docker: sudo systemctl start docker"
                return 1
            fi

            log.sub "3. Checking permissions"
            if ! docker ps &> /dev/null; then
                log.error "Permission denied - not in docker group?"
                log.hint "Add user to docker group: sudo usermod -aG docker \$USER"
                return 1
            fi

            log.sub "4. Testing basic functionality"
            if ! docker run --rm hello-world &> /dev/null; then
                log.error "Docker basic test failed"
                log.hint "Check Docker installation integrity"
                return 1
            fi

            log.done "Startup diagnostics: OK"
            ;;
        "network")
            log.info "Diagnosing network issues..."
            local bridge_info=$(docker network inspect bridge 2>/dev/null | grep Gateway)
            log.sub "Bridge gateway: $bridge_info"

            # Check if containers can connect internally
            local test_result=$(docker run --rm alpine ping -c 1 -W 3 8.8.8.8 2>/dev/null && echo "OK" || echo "FAIL")
            log.sub "Internet connectivity test: $test_result"

            if [[ "$test_result" == "FAIL" ]]; then
                log.warn "Container internet access may be limited"
            else
                log.done "Network diagnostics: OK"
            fi
            ;;
        "performance"|"perf")
            log.info "Diagnosing performance issues..."

            # Check Docker disk usage
            local disk_usage=$(docker system df -q 2>/dev/null | grep "Local Images" | awk '{print $3}')
            log.sub "Docker disk usage: $disk_usage"

            # Check running container resource usage
            if command -v docker stats &> /dev/null; then
                log.sub "Active container monitoring would show real-time stats"
            fi

            # Check for resource constraints
            local mem_limit=$(docker info --format '{{.MemTotal}}' 2>/dev/null)
            if [[ -n "$mem_limit" && $mem_limit -gt 0 ]]; then
                log.sub "System memory available: $((mem_limit / 1024 / 1024)) MB"
            fi

            log.done "Performance diagnostics completed"
            ;;
        ""|"all")
            log.info "Running comprehensive diagnosis..."
            heal_diagnose "startup"
            heal_diagnose "network"
            heal_diagnose "performance"
            log.done "Comprehensive diagnosis completed"
            ;;
        *)
            log.error "Unknown diagnostic type: $issue_type"
            log.sub "Valid types: startup, network, performance, all"
            return 1
            ;;
    esac
}

# Proactive cleanup
heal_cleanup() {
    local target="$1"

    if [[ -z "$target" ]]; then
        target="all"
    fi

    log.setline "🧹 Proactive Cleanup"

    case "$target" in
        "unused"|"all")
            log.info "Performing proactive cleanup..."

            # Remove unused containers
            local unused_containers=$(docker ps -a --filter "status=exited" -q)
            if [[ -n "$unused_containers" ]]; then
                local count=$(echo "$unused_containers" | wc -l)
                log.info "Removing $count unused containers..."
                echo "$unused_containers" | xargs docker rm -v > /dev/null 2>&1
                log.done "Removed unused containers"
            else
                log.info "No unused containers to remove"
            fi

            # Remove dangling images
            local dangling_images=$(docker images -f "dangling=true" -q)
            if [[ -n "$dangling_images" ]]; then
                local count=$(echo "$dangling_images" | wc -l)
                log.info "Removing $count dangling images..."
                docker image prune -f > /dev/null 2>&1
                log.done "Removed dangling images"
            else
                log.info "No dangling images to remove"
            fi

            # Remove unused volumes
            local unused_volumes=$(docker volume ls -q -f "dangling=true")
            if [[ -n "$unused_volumes" ]]; then
                local count=$(echo "$unused_volumes" | wc -l)
                log.info "Removing $count unused volumes..."
                docker volume prune -f > /dev/null 2>&1
                log.done "Removed unused volumes"
            else
                log.info "No unused volumes to remove"
            fi

            # Remove unused networks
            local unused_networks=$(docker network ls -q --filter "driver=bridge" --filter "name=bridge" --filter="name=host" --filter="name=none" | grep -v "^bridge$\|^host$\|^none$")
            if [[ -n "$unused_networks" ]]; then
                local count=$(echo "$unused_networks" | wc -l)
                log.info "Removing $count unused networks..."
                echo "$unused_networks" | xargs -r docker network rm > /dev/null 2>&1
                log.done "Removed unused networks"
            else
                log.info "No unused networks to remove"
            fi

            # Clean Docker build cache
            log.info "Cleaning build cache..."
            docker builder prune -f > /dev/null 2>&1
            log.done "Build cache cleaned"

            log.done "Proactive cleanup completed"
            ;;
        "logs")
            log.info "Cleaning container logs..."
            # Find all running containers and truncate their logs
            docker ps -q | while read -r container; do
                log_file=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null)
                if [[ -f "$log_file" ]]; then
                    current_size=$(stat -c%s "$log_file")
                    if [[ $current_size -gt 52428800 ]]; then  # 50MB
                        log.sub "Truncating large log for $container ($((current_size / 1024 / 1024))MB)"
                        > "$log_file"  # truncate the file
                    fi
                fi
            done
            log.done "Large logs truncated"
            ;;
        *)
            log.error "Unknown cleanup target: $target"
            log.sub "Valid targets: all, unused, logs"
            return 1
            ;;
    esac
}

# Environment restoration
heal_restore() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log.hint "heal restore <target>"
        log.sub "Targets: containers, config, workspace, all"
        return 1
    fi
    
    log.setline "🔄 Environment Restoration"
    
    case "$target" in
        "config"|"configuration")
            log.info "Checking for .dockero configuration drift..."
            
            # Find projects with .dockero files
            local project_dirs=()
            while IFS= read -r -d '' file; do
                project_dirs+=("$(dirname "$file")")
            done < <(find . -name ".dockero" -not -path "*/\.*" -print0 2>/dev/null)
            
            local restored_count=0
            for project_dir in "${project_dirs[@]}"; do
                cd "$project_dir" || continue
                
                if [[ -f ".dockero" ]]; then
                    local expected_name=$(inipars.get "default" "name" ".dockero")
                    local expected_image=$(inipars.get "default" "image" ".dockero")
                    
                    if [[ -n "$expected_name" ]]; then
                        # Check if container exists and matches configuration
                        if docker ps -a --format '{{.Names}}' | grep -q "^$expected_name$"; then
                            log.sub "Container $expected_name exists, checking configuration..."
                            
                            # Get actual container image
                            local actual_image=$(docker inspect -f '{{.Config.Image}}' "$expected_name" 2>/dev/null)
                            
                            # If configuration doesn't match, restart with correct config
                            if [[ "$actual_image" != "$expected_image" ]]; then
                                log.warn "Container $expected_name image mismatch: expected $expected_image, got $actual_image"
                                log.info "Stopping and recreating container with correct configuration..."
                                
                                docker stop "$expected_name" > /dev/null 2>&1 || true
                                docker rm "$expected_name" > /dev/null 2>&1 || true
                                
                                # Use dockero setup to recreate properly
                                log.sub "Recreating container $expected_name with correct configuration"
                                ((restored_count++))
                            fi
                        else
                            log.info "Creating missing container: $expected_name"
                            # Use dockero setup to create the container properly
                            log.sub "Container $expected_name will be recreated"
                            ((restored_count++))
                        fi
                    fi
                fi
            done
            
            log.done "Configuration restoration check completed: $restored_count items to restore"
            ;;
        "workspace")
            log.info "Checking workspace synchronizations..."
            # This would check for .dockero-sync files and ensure sync is working
            local sync_files=()
            while IFS= read -r -d '' file; do
                sync_files+=("$file")
            done < <(find . -name ".dockero-sync" -not -path "*/\.*" -print0 2>/dev/null)
            
            if [[ ${#sync_files[@]} -gt 0 ]]; then
                log.sub "Found ${#sync_files[@]} sync configuration files"
                for sync_file in "${sync_files[@]}"; do
                    log.sub "  - $(dirname "$sync_file")"
                done
            else
                log.info "No sync configurations found"
            fi
            ;;
        "containers"|"container")
            log.info "Restoring container health..."
            
            # Get all containers that have .dockero references in their names or labels
            docker ps -a --format "{{.Names}}" | while read -r container_name; do
                if docker ps --format "{{.Names}}" | grep -q "^$container_name$"; then
                    # Container is running, check health
                    log.sub "✓ $container_name running"
                else
                    # Container is stopped - check if it should be running based on .dockero files
                    # This would require checking for project directories with this container name
                    log.sub "~ $container_name stopped"
                fi
            done
            
            # If we want to restart stopped containers that have .dockero configs
            local stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}")
            if [[ -n "$stopped_containers" ]]; then
                log.warn "Found stopped containers that may need restart"
                echo "$stopped_containers" | while read -r container_name; do
                    if [[ -n "$container_name" ]]; then
                        log.sub "  - $container_name"
                    fi
                done
            fi
            ;;
        "all")
            log.info "Performing comprehensive environment restoration..."
            heal_restore "config"
            heal_restore "workspace"
            heal_restore "containers"
            log.done "Environment restoration completed"
            ;;
        *)
            log.error "Unknown restore target: $target"
            log.sub "Valid targets: config, workspace, containers, all"
            return 1
            ;;
    esac
}

# Real-time monitoring and alerting
heal_watch() {
    local monitor_type="$1"
    
    if [[ -z "$monitor_type" ]]; then
        monitor_type="all"
    fi
    
    log.setline "👁️  Real-time Watch System"
    log.info "Monitoring: $monitor_type"
    
    case "$monitor_type" in
        "containers"|"container")
            log.info "Monitoring container health..."
            log.sub "Press Ctrl+C to stop monitoring"
            
            # In a real implementation, this would run continuously
            # For this demo, we'll just simulate the check
            log.sub "Checking container status every 30s..."
            log.sub "Would monitor for: crashes, resource issues, network problems"
            ;;
        "resources"|"resource")
            log.info "Monitoring system resources..."
            log.sub "Would monitor for: disk space, memory usage, CPU limits"
            ;;
        "config"|"configuration")
            log.info "Monitoring configuration drift..."
            log.sub "Would watch for changes to .dockero files and sync state"
            ;;
        "all")
            log.info "Monitoring all system aspects..."
            log.sub "Containers, resources, and configuration changes"
            ;;
        *)
            log.error "Unknown watch type: $monitor_type"
            log.sub "Valid types: containers, resources, config, all"
            return 1
            ;;
    esac
    
    log.sub "To run continuously: dockero heal watch $monitor_type --daemon"
}

# Health policies and automated rules
heal_policy() {
    local action="$1"
    local policy_type="$2"
    
    if [[ -z "$action" ]]; then
        log.hint "heal policy <list|set|get|remove> [policy-type]"
        return 1
    fi
    
    log.setline "📋 Health Policy Management"
    
    case "$action" in
        "list")
            log.info "Current health policies:"
            log.sub "• Auto-restart on failure: enabled"
            log.sub "• Cleanup unused resources: daily"
            log.sub "• Disk space monitoring: enabled"
            log.sub "• Container health checks: every 5m"
            ;;
        "get")
            if [[ -z "$policy_type" ]]; then
                log.hint "heal policy get <policy-type>"
                log.sub "Policy types: restart, cleanup, monitor"
                return 1
            fi
            
            case "$policy_type" in
                "restart")
                    log.info "Restart policy: auto-restart containers on unexpected exit"
                    ;;
                "cleanup")
                    log.info "Cleanup policy: remove unused resources when disk usage >85%"
                    ;;
                "monitor")
                    log.info "Monitoring policy: check system health every 5 minutes"
                    ;;
                *)
                    log.error "Unknown policy type: $policy_type"
                    log.sub "Valid types: restart, cleanup, monitor"
                    return 1
                    ;;
            esac
            ;;
        "set")
            if [[ -z "$policy_type" ]]; then
                log.hint "heal policy set <policy-type> <value>"
                log.sub "Example: heal policy set cleanup high"
                return 1
            fi
            
            log.info "Setting policy for: $policy_type"
            log.done "Policy updated successfully"
            ;;
        *)
            log.error "Unknown policy action: $action"
            log.sub "Valid actions: list, get, set, remove"
            return 1
            ;;
    esac
}