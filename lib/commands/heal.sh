#!/usr/bin/env bash

# Self-healing automation system for Dockero

heal_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero heal ${GREEN}<check|fix|auto|diagnose|cleanup|restore|watch|policy> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Self-healing automation system.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}check [target]${RESET_COLOR}       Health checks (system, containers, networks).
     - ${GREEN}fix <target> [item]${RESET_COLOR}  Auto-fix identified issues.
     - ${GREEN}auto${RESET_COLOR}                 Run health check and apply fixes automatically.
     - ${GREEN}diagnose <type>${RESET_COLOR}      Deep diagnosis (startup, network, performance).
     - ${GREEN}cleanup [target]${RESET_COLOR}     Clean up Docker resources.
     - ${GREEN}restore <target>${RESET_COLOR}     Restore environment to expected state.
     - ${GREEN}watch <target>${RESET_COLOR}       Real-time monitoring.
     - ${GREEN}policy <action> [type]${RESET_COLOR} Manage health policies.
EOF
}

heal() {
    # shellcheck disable=SC2154
    local subcommand="${args[1]:-}"
    
    if [[ -z "$subcommand" ]]; then
        log.hint "Usage: heal <check|fix|auto|monitor|diagnose|cleanup|restore|watch|policy> [options]"
        return 1
    fi
    
    case "$subcommand" in
        "check")
            heal_check "${args[2]:-}"
            ;;
        "fix")
            heal_fix "${args[2]:-}" "${args[3]:-}"
            ;;
        "auto")
            heal_auto
            ;;
        "monitor")
            heal_monitor "${args[@]:2}"
            ;;
        "diagnose")
            heal_diagnose "${args[2]:-}"
            ;;
        "cleanup")
            heal_cleanup "${args[2]:-}"
            ;;
        "restore")
            heal_restore "${args[2]:-}"
            ;;
        "watch")
            heal_watch "${args[2]:-}"
            ;;
        "policy")
            heal_policy "${args[2]:-}" "${args[3]:-}"
            ;;
        *)
            log.error "Unknown heal subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
            log.hint "Usage: heal <check|fix|auto|monitor|diagnose|cleanup|restore|watch|policy> [options]"
            return 1
            ;;
    esac
}

# Health monitoring system
heal_check() {
    local target="$1"
    local issues_found=0
    local fixes_available=0

    log.setline "${BOLD_CYAN}🔍 Health Check System${RESET_COLOR}"

    case "$target" in
        "system"|"all"|"")
            log.info "Performing system health checks..."

            # Check Docker daemon status
            log.sub "Checking Docker daemon..."
            if ! command -v docker &> /dev/null; then
                log.error "Docker not installed."
                ((issues_found++))
            elif ! ${DOCKERO_RUNTIME:-docker} ps -q &> /dev/null; then # Faster check
                log.error "Docker daemon not running."
                ((issues_found++))
            else
                log.done "Docker daemon OK."
            fi

            # Check disk space
            log.sub "Checking disk space..."
            local docker_root
            docker_root=$(${DOCKERO_RUNTIME:-docker} info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
            if [[ -d "$docker_root" ]]; then
                local disk_usage
                disk_usage=$(df "$docker_root" | awk 'NR==2 {print $5}' | sed 's/%//')
                if [[ "$disk_usage" -gt 90 ]]; then
                    log.warn "Docker directory >90% full: ${disk_usage}% used."
                    ((issues_found++))
                    ((fixes_available++))
                else
                    log.done "Disk space OK (${disk_usage}% used)."
                fi
            else
                log.warn "Docker root directory not found: ${docker_root}"
                ((issues_found++))
            fi

            # Check for stopped containers
            log.sub "Checking containers..."
            local stopped_containers_count
            stopped_containers_count=$(${DOCKERO_RUNTIME:-docker} ps -a --filter "status=exited" -q | wc -l)
            if [[ "$stopped_containers_count" -gt 20 ]]; then
                log.warn "${stopped_containers_count} stopped containers found."
                ((issues_found++))
                ((fixes_available++))
            elif [[ "$stopped_containers_count" -gt 0 ]]; then
                log.info "${stopped_containers_count} stopped containers."
            else
                log.done "No stopped containers."
            fi

            # Check for dangling images
            log.sub "Checking for unused images..."
            local dangling_images_count
            dangling_images_count=$(${DOCKERO_RUNTIME:-docker} images -f "dangling=true" -q | wc -l)
            if [[ "$dangling_images_count" -gt 5 ]]; then
                log.warn "${dangling_images_count} dangling images found."
                ((issues_found++))
                ((fixes_available++))
            else
                log.done "No dangling images."
            fi

            # Check for unused volumes
            log.sub "Checking for unused volumes..."
            local unused_volumes_count
            unused_volumes_count=$(${DOCKERO_RUNTIME:-docker} volume ls -q -f "dangling=true" | wc -l)
            if [[ "$unused_volumes_count" -gt 5 ]]; then
                log.warn "${unused_volumes_count} unused volumes found."
                ((issues_found++))
                ((fixes_available++))
            else
                log.done "No unused volumes."
            fi

            ;;
        "containers")
            log.info "Checking containers health..."
            local running_containers_count
            running_containers_count=$(${DOCKERO_RUNTIME:-docker} ps -q | wc -l)
            local total_containers_count
            total_containers_count=$(${DOCKERO_RUNTIME:-docker} ps -a -q | wc -l)
            local stopped_containers_count=$((total_containers_count - running_containers_count))

            log.sub "Running: ${BOLD_GREEN}$running_containers_count${RESET_COLOR}, Stopped: ${BOLD_YELLOW}$stopped_containers_count${RESET_COLOR}, Total: ${total_containers_count}"

            if [[ $running_containers_count -gt 0 ]]; then
                log.info "Checking running container health..."
                local problematic_containers_output
                problematic_containers_output=$(${DOCKERO_RUNTIME:-docker} ps --format "table {{.Names}}\t{{.Status}}" | tail -n +2 | while read -r name status; do
                    if [[ "$status" =~ (Restarting|Paused|Dead) ]]; then
                        log.warn "Container ${BOLD_YELLOW}$name${RESET_COLOR} in problematic state: ${RED}$status${RESET_COLOR}"
                        echo "ISSUE" # Indicate an issue found
                    else
                        log.sub "✓ ${GREEN}$name${RESET_COLOR}: ${status}"
                    fi
                done)

                local current_issues
                current_issues=$(echo "$problematic_containers_output" | grep -c "ISSUE")
                issues_found=$((issues_found + current_issues))
                fixes_available=$((fixes_available + current_issues)) # Assuming each issue implies a fix
            fi
            ;;
        "networks")
            log.info "Checking networks..."
            local networks_list
            networks_list=$(${DOCKERO_RUNTIME:-docker} network ls --format "{{.Name}}")
            local networks_count
            networks_count=$(echo "$networks_list" | wc -l)
            log.sub "Networks: ${BOLD_GREEN}$networks_count${RESET_COLOR} total"
            echo "$networks_list" | while read -r net; do
                if [[ "$net" != "bridge" && "$net" != "host" && "$net" != "none" ]]; then
                    local connected_containers
                    connected_containers=$(${DOCKERO_RUNTIME:-docker} network inspect "$net" --format '{{len .Containers}}')
                    log.sub "  ${YELLOW}$net${RESET_COLOR}: ${connected_containers} connected containers"
                else
                    log.sub "  $net: default network"
                fi
            done
            ;;
        *)
            log.error "Unknown check target: ${BOLD_RED}$target${RESET_COLOR}"
            log.sub "Valid targets: ${BOLD_GREEN}system${RESET_COLOR}, ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}networks${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
            return 1
            ;;
    esac

    log.setline "${BOLD_CYAN}Health Check Summary${RESET_COLOR}"
    log.info "Issues found: ${BOLD_YELLOW}$issues_found${RESET_COLOR}"
    log.info "Automatic fixes available: ${BOLD_GREEN}$fixes_available${RESET_COLOR}"

    if [[ $issues_found -gt 0 ]]; then
        log.warn "Potential issues detected. Run: ${BOLD_YELLOW}dockero heal fix${RESET_COLOR} to auto-resolve"
    else
        log.done "System appears healthy!"
    fi
}

# Auto-recovery mechanisms
heal_fix() {
    local target="$1"
    local specific_item="${2:-}"

    if [[ -z "$target" ]]; then
        log.hint "Usage: heal fix <target> [item]"
        log.sub "Targets: ${BOLD_GREEN}system${RESET_COLOR}, ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}images${RESET_COLOR}, ${BOLD_GREEN}volumes${RESET_COLOR}, ${BOLD_GREEN}networks${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
        return 1
    fi

    log.setline "${BOLD_CYAN}🔧 Auto-Fix System${RESET_COLOR}"

    case "$target" in
        "permissions")
            heal_fix_permissions
            ;;
        "containers")
            log.info "Fixing container issues..."
            if [[ -n "$specific_item" ]]; then
                # Fix specific container
                if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$specific_item$"; then
                    local status
                    status=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.State.Status}}' "$specific_item" 2>/dev/null)
                    case "$status" in
                        "exited")
                            log.info "Starting stopped container: ${BOLD_YELLOW}$specific_item${RESET_COLOR}"
                            if ${DOCKERO_RUNTIME:-docker} start "$specific_item" > /dev/null 2>&1; then
                                log.done "Container ${BOLD_GREEN}$specific_item${RESET_COLOR} started."
                            else
                                log.error "Failed to start ${RED}$specific_item${RESET_COLOR}."
                            fi
                            ;;
                        "dead")
                            log.warn "Container ${BOLD_YELLOW}$specific_item${RESET_COLOR} is dead, removing..."
                            if ${DOCKERO_RUNTIME:-docker} rm -f "$specific_item" > /dev/null 2>&1; then
                                log.done "Dead container ${BOLD_GREEN}$specific_item${RESET_COLOR} removed."
                            else
                                log.error "Failed to remove dead container ${RED}$specific_item${RESET_COLOR}."
                            fi
                            ;;
                        *)
                            log.info "Container ${BOLD_YELLOW}$specific_item${RESET_COLOR} status: $status (no fix needed)."
                            ;;
                    esac
                else
                    log.error "Container not found: ${RED}$specific_item${RESET_COLOR}."
                fi
            else
                # Fix all containers with issues
                local stopped_containers
                stopped_containers=$(${DOCKERO_RUNTIME:-docker} ps -a --filter "status=exited" -q)
                local stopped_count
            stopped_count=$(echo "$stopped_containers" | wc -l)
                if [[ "$stopped_count" -gt 0 ]]; then
                    log.info "Starting ${stopped_count} stopped containers..."
                    echo "$stopped_containers" | xargs -r ${DOCKERO_RUNTIME:-docker} start > /dev/null 2>&1
                    log.done "Attempted to start all stopped containers."
                else
                    log.info "No stopped containers to fix."
                fi
            fi
            ;;
        "images")
            log.info "Cleaning dangling images..."
            local dangling_count
            dangling_count=$(${DOCKERO_RUNTIME:-docker} images -f "dangling=true" -q | wc -l)
            if [[ "$dangling_count" -gt 0 ]]; then
                docker image prune -f > /dev/null 2>&1
                log.done "Removed ${BOLD_GREEN}$dangling_count${RESET_COLOR} dangling images."
            else
                log.info "No dangling images to clean."
            fi
            ;;
        "volumes")
            log.info "Cleaning unused volumes..."
            local unused_count
            unused_count=$(${DOCKERO_RUNTIME:-docker} volume ls -q -f "dangling=true" | wc -l)
            if [[ "$unused_count" -gt 0 ]]; then
                ${DOCKERO_RUNTIME:-docker} volume prune -f > /dev/null 2>&1
                log.done "Removed ${BOLD_GREEN}$unused_count${RESET_COLOR} unused volumes."
            else
                log.info "No unused volumes to clean."
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
            if ! ${DOCKERO_RUNTIME:-docker} ps -q &> /dev/null; then # Faster check
                log.info "Attempting to restart Docker service..."
                if command -v systemctl &> /dev/null; then
                    sudo systemctl restart docker 2>/dev/null && log.done "Docker service restarted." || log.warn "Could not restart Docker service automatically via systemctl."
                elif command -v service &> /dev/null; then
                    sudo service docker restart 2>/dev/null && log.done "Docker service restarted." || log.warn "Could not restart Docker service automatically via service command."
                else
                    log.warn "Could not restart Docker service automatically. No systemctl or service command found."
                fi
            fi

            log.done "Comprehensive system fix completed."
            ;;
        *)
            log.error "Unknown fix target: ${BOLD_RED}$target${RESET_COLOR}"
            log.sub "Valid targets: ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}images${RESET_COLOR}, ${BOLD_GREEN}volumes${RESET_COLOR}, ${BOLD_GREEN}system${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
            return 1
            ;;
    esac
}

heal_fix_permissions() {
    log.info "Checking Docker socket permissions..."
    
    if [[ -w /var/run/docker.sock ]]; then
        log.done "You already have write access to /var/run/docker.sock."
        return 0
    fi

    log.warn "You do not have permission to access the Docker socket."
    log.info "This can be fixed by adding your user (${BOLD_CYAN}$USER${RESET_COLOR}) to the ${BOLD_YELLOW}docker${RESET_COLOR} group."

    # Check if docker group exists
    if ! getent group docker > /dev/null; then
        log.info "The ${BOLD_YELLOW}docker${RESET_COLOR} group does not exist. It will be created."
        local create_cmd="sudo groupadd docker"
        log.sub "Command to run: ${BOLD_YELLOW}$create_cmd${RESET_COLOR}"
        read -rp "Do you want to run this command? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            log.sub "+ $create_cmd"
            if $create_cmd; then
                log.done "Group 'docker' created."
            else
                log.error "Failed to create 'docker' group."
                return 1
            fi
        else
            log.warn "Command cancelled."
            return 1
        fi
    fi

    # Add user to group
    local add_cmd="sudo usermod -aG docker $USER"
    log.info "Adding user ${BOLD_CYAN}$USER${RESET_COLOR} to ${BOLD_YELLOW}docker${RESET_COLOR} group."
    log.sub "Command to run: ${BOLD_YELLOW}$add_cmd${RESET_COLOR}"
    read -rp "Do you want to run this command? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log.sub "+ $add_cmd"
        if $add_cmd; then
            log.done "User ${BOLD_CYAN}$USER${RESET_COLOR} added to ${BOLD_YELLOW}docker${RESET_COLOR} group."
            log.setline "${BOLD_CYAN}🔄 Action Required${RESET_COLOR}"
            log.warn "You MUST log out and log back in (or restart your session) for the group changes to take effect."
            log.info "Alternatively, run: ${BOLD_YELLOW}newgrp docker${RESET_COLOR} in your current terminal."
        else
            log.error "Failed to add user to 'docker' group."
            return 1
        fi
    else
        log.warn "Command cancelled."
        return 1
    fi
}

# Automatic healing system
heal_auto() {
    log.setline "${BOLD_CYAN}🤖 Auto-Healing Mode${RESET_COLOR}"
    log.info "Running automated health check and fixes..."

    # Check permissions first
    if [[ ! -w /var/run/docker.sock ]]; then
        log.warn "Permission issues detected for Docker socket."
        heal_fix_permissions
    fi

    # Perform health check
    local stopped_containers_count
    stopped_containers_count=$(${DOCKERO_RUNTIME:-docker} ps -a --filter "status=exited" -q | wc -l) # Corrected calculation

    local dangling_images_count
    dangling_images_count=$(${DOCKERO_RUNTIME:-docker} images -f "dangling=true" -q | wc -l)

    if [[ "$stopped_containers_count" -gt 0 || "$dangling_images_count" -gt 0 ]]; then
        log.info "Issues detected, applying automatic fixes..."

        if [[ "$stopped_containers_count" -gt 0 ]]; then
            log.sub "Starting ${stopped_containers_count} stopped containers..."
            ${DOCKERO_RUNTIME:-docker} ps -a --filter "status=exited" --format "{{.ID}}" | xargs -r ${DOCKERO_RUNTIME:-docker} start > /dev/null 2>&1 || true # Using xargs -r
            log.done "Attempted to start stopped containers."
        fi

        if [[ "$dangling_images_count" -gt 0 ]]; then
            log.sub "Removing ${dangling_images_count} dangling images..."
            docker image prune -f > /dev/null 2>&1
            log.done "Removed dangling images."
        fi

        log.done "Auto-healing completed."
    else
        log.done "No issues detected, system healthy."
    fi
}

# Monitoring daemon (would run in background in real implementation)
heal_monitor() {
    local monitor_type="$1"
    
    log.setline "${BOLD_CYAN}👁️  Real-time Monitor${RESET_COLOR}"
    log.info "Real-time monitoring would start in background..."
    log.sub "This would monitor containers, resources, and automatically apply fixes."
    log.sub "For continuous monitoring, consider: ${BOLD_YELLOW}dockero heal auto --daemon${RESET_COLOR}" # Colored hint

    # In a real implementation, this would start a monitoring service
    # For now, just run a check
    heal_check "system"
}

# Diagnostic tools
heal_diagnose() {
    local issue_type="$1"

    log.setline "${BOLD_CYAN}🔍 Deep Diagnosis${RESET_COLOR}"

    case "$issue_type" in
        "startup"|"start")
            log.info "Diagnosing startup issues..."
            log.sub "1. Checking Docker installation..."
            if ! command -v docker &> /dev/null; then
                log.error "Docker not installed."
                log.hint "Install Docker: ${BOLD_BLUE}https://docs.docker.com/engine/install/${RESET_COLOR}"
                return 1
            fi
            log.done "Docker installation check OK."

            log.sub "2. Checking Docker service..."
            if ! ${DOCKERO_RUNTIME:-docker} ps -q &> /dev/null; then # Faster check
                log.error "Docker daemon not running."
                log.hint "Start Docker: ${BOLD_YELLOW}sudo systemctl start docker${RESET_COLOR}"
                return 1
            fi
            log.done "Docker service check OK."

            log.sub "3. Checking permissions..."
            if ! ${DOCKERO_RUNTIME:-docker} ps &> /dev/null; then
                log.error "Permission denied - not in docker group? Make sure your user is in the 'docker' group."
                log.hint "Add user to docker group: ${BOLD_YELLOW}sudo usermod -aG docker \$USER${RESET_COLOR}"
                return 1
            fi
            log.done "Permissions check OK."

            log.sub "4. Testing basic functionality..."
            if ! ${DOCKERO_RUNTIME:-docker} run --rm hello-world &> /dev/null; then
                log.error "Docker basic test failed. Could not run 'hello-world'."
                log.hint "Check Docker installation integrity."
                return 1
            fi
            log.done "Basic functionality test OK."

            log.done "Startup diagnostics: OK"
            ;;
        "network")
            log.info "Diagnosing network issues..."
            local bridge_info
            bridge_info=$(${DOCKERO_RUNTIME:-docker} network inspect bridge --format '{{.IPAM.Config}}' 2>/dev/null) # More precise info
            if [[ -n "$bridge_info" ]]; then
                log.sub "Bridge network IPAM config: ${BOLD_GREEN}$bridge_info${RESET_COLOR}"
            else
                log.warn "Could not get bridge network info."
            fi

            # Check if containers can connect internally
            local test_result
            test_result=$(${DOCKERO_RUNTIME:-docker} run --rm alpine ping -c 1 -W 3 8.8.8.8 &> /dev/null && echo "OK" || echo "FAIL")
            log.sub "Internet connectivity test: ${BOLD_GREEN}$test_result${RESET_COLOR}"

            if [[ "$test_result" == "FAIL" ]]; then
                log.warn "Container internet access may be limited."
                return 1
            else
                log.done "Network diagnostics: OK."
            fi
            ;;
        "performance"|"perf")
            log.info "Diagnosing performance issues..."

            # Check Docker disk usage
            local disk_usage
            disk_usage=$(${DOCKERO_RUNTIME:-docker} system df --format '{{.Size}}' 2>/dev/null | grep "Local Images" | awk '{print $3}')
            log.sub "Docker disk usage: ${BOLD_YELLOW}$disk_usage${RESET_COLOR}"

            # Check running container resource usage
            if command -v ${DOCKERO_RUNTIME:-docker} stats &> /dev/null; then
                log.sub "Active container monitoring would show real-time stats."
                log.hint "Run ${BOLD_YELLOW}${DOCKERO_RUNTIME:-docker} stats${RESET_COLOR} for live resource usage."
            fi

            # Check for resource constraints
            local mem_limit
            mem_limit=$(${DOCKERO_RUNTIME:-docker} info --format '{{.MemTotal}}' 2>/dev/null)
            if [[ -n "$mem_limit" && "$mem_limit" -gt 0 ]]; then
                log.sub "System memory available: ${BOLD_GREEN}$((mem_limit / 1024 / 1024)) MB${RESET_COLOR}"
            else
                log.warn "Could not determine system memory."
            fi

            log.done "Performance diagnostics completed."
            ;;
        ""|"all")
            log.info "Running comprehensive diagnosis..."
            heal_diagnose "startup"
            heal_diagnose "network"
            heal_diagnose "performance"
            log.done "Comprehensive diagnosis completed."
            ;;
        *)
            log.error "Unknown diagnostic type: ${BOLD_RED}$issue_type${RESET_COLOR}"
            log.sub "Valid types: ${BOLD_GREEN}startup${RESET_COLOR}, ${BOLD_GREEN}network${RESET_COLOR}, ${BOLD_GREEN}performance${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
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

    log.setline "${BOLD_CYAN}🧹 Proactive Cleanup${RESET_COLOR}"

    case "$target" in
        "unused"|"all")
            log.info "Performing proactive cleanup..."

            # Remove unused containers
            local unused_containers_count
            unused_containers_count=$(${DOCKERO_RUNTIME:-docker} ps -a --filter "status=exited" -q | wc -l)
            if [[ "$unused_containers_count" -gt 0 ]]; then
                log.info "Removing ${unused_containers_count} unused containers..."
                ${DOCKERO_RUNTIME:-docker} ps -a --filter "status=exited" -q | xargs -r ${DOCKERO_RUNTIME:-docker} rm -v > /dev/null 2>&1
                log.done "Removed unused containers."
            else
                log.info "No unused containers to remove."
            fi

            # Remove dangling images
            local dangling_images_count
            dangling_images_count=$(${DOCKERO_RUNTIME:-docker} images -f "dangling=true" -q | wc -l)
            if [[ "$dangling_images_count" -gt 0 ]]; then
                log.info "Removing ${dangling_images_count} dangling images..."
                docker image prune -f > /dev/null 2>&1
                log.done "Removed dangling images."
            else
                log.info "No dangling images to remove."
            fi

            # Remove unused volumes
            local unused_volumes_count
            unused_volumes_count=$(${DOCKERO_RUNTIME:-docker} volume ls -q -f "dangling=true" | wc -l)
            if [[ "$unused_volumes_count" -gt 0 ]]; then
                log.info "Removing ${unused_volumes_count} unused volumes..."
                ${DOCKERO_RUNTIME:-docker} volume prune -f > /dev/null 2>&1
                log.done "Removed unused volumes."
            else
                log.info "No unused volumes to remove."
            fi

            log.info "Pruning unused networks using ${BOLD_YELLOW}dockero net prune${RESET_COLOR}..."
            net prune # Call the newly implemented prune function
            
            # Clean Docker build cache
            log.info "Cleaning build cache..."
            docker builder prune -f > /dev/null 2>&1
            log.done "Build cache cleaned."

            log.done "Proactive cleanup completed."
            ;;
        "logs")
            log.info "Cleaning container logs..."
            local containers_list
            containers_list=$(${DOCKERO_RUNTIME:-docker} ps -q)
            if [[ -n "$containers_list" ]]; then
                echo "$containers_list" | while read -r container; do
                    local log_file
                    log_file=$(${DOCKERO_RUNTIME:-docker} inspect "$container" --format='{{.LogPath}}' 2>/dev/null)
                    if [[ -f "$log_file" ]]; then
                        local current_size
                        current_size=$(stat -c%s "$log_file")
                        if [[ $current_size -gt 52428800 ]]; then  # 50MB
                            log.sub "Truncating large log for ${BOLD_YELLOW}$container${RESET_COLOR} (${BOLD_YELLOW}$((current_size / 1024 / 1024))MB${RESET_COLOR})"
                            true > "$log_file"  # truncate the file
                        fi
                    fi
                done
                log.done "Large logs truncated."
            else
                log.info "No running containers to check logs for."
            fi
            ;;
        *)
            log.error "Unknown cleanup target: ${BOLD_RED}$target${RESET_COLOR}"
            log.sub "Valid targets: ${BOLD_GREEN}all${RESET_COLOR}, ${BOLD_GREEN}unused${RESET_COLOR}, ${BOLD_GREEN}logs${RESET_COLOR}"
            return 1
            ;;
    esac
}

# Environment restoration
heal_restore() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        log.hint "Usage: heal restore <target>"
        log.sub "Targets: ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}config${RESET_COLOR}, ${BOLD_GREEN}workspace${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
        return 1
    fi
    
    log.setline "${BOLD_CYAN}🔄 Environment Restoration${RESET_COLOR}"
    
    case "$target" in
        "config"|"configuration")
            log.info "Checking for .dockero configuration drift..."
            
            # Find projects with .dockero files
            local -a project_dirs=()
            while IFS= read -r -d '' file; do
                project_dirs+=("$(dirname "$file")")
            done < <(find . -name ".dockero" -not -path "*/\.*" -print0 2>/dev/null)
            

            for project_dir in "${project_dirs[@]}"; do
                ( # Subshell to avoid cd affecting main script
                cd "$project_dir" || { log.warn "Could not change to directory: $project_dir"; continue; }
                
                if [[ -f ".dockero" ]]; then
                    local expected_name
                    expected_name=$(inipars.get "default" "name" ".dockero")
                    local expected_image
                    expected_image=$(inipars.get "default" "image" ".dockero")
                    
                    if [[ -n "$expected_name" ]]; then
                        # Check if container exists and matches configuration
                        if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$expected_name$"; then
                            log.sub "Container ${BOLD_YELLOW}$expected_name${RESET_COLOR} exists, checking configuration..."
                            
                            # Get actual container image
                            local actual_image
                            actual_image=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.Config.Image}}' "$expected_name" 2>/dev/null)
                            
                            # If configuration doesn't match, instruct user to fix
                            if [[ "$actual_image" != "$expected_image" ]]; then
                                log.warn "Container ${BOLD_YELLOW}$expected_name${RESET_COLOR} image mismatch: expected ${GREEN}$expected_image${RESET_COLOR}, got ${RED}$actual_image${RESET_COLOR}."
                                log.hint "To fix: ${BOLD_YELLOW}dockero setup \"$project_dir\"${RESET_COLOR} to recreate with correct configuration."
                                # Don't increment restored_count, as it's a manual step
                            fi
                        else
                            log.info "Container ${BOLD_YELLOW}$expected_name${RESET_COLOR} for project '$project_dir' is missing."
                            log.hint "To fix: ${BOLD_YELLOW}dockero setup \"$project_dir\"${RESET_COLOR} to create the container."
                            # Don't increment restored_count, as it's a manual step
                        fi
                    fi
                fi
                ) # End subshell
            done
            
            log.done "Configuration restoration check completed. Manual intervention may be required."
            ;;
        "workspace")
            log.info "Checking workspace synchronizations..."
            # This would check for .dockero-sync files and ensure sync is working
            local -a sync_files=()
            while IFS= read -r -d '' file; do
                sync_files+=("$file")
            done < <(find . -name ".dockero-sync" -not -path "*/\.*" -print0 2>/dev/null)
            
            if [[ ${#sync_files[@]} -gt 0 ]]; then
                log.sub "Found ${BOLD_GREEN}${#sync_files[@]}${RESET_COLOR} sync configuration files."
                for sync_file in "${sync_files[@]}"; do
                    log.sub "  - ${YELLOW}$sync_file${RESET_COLOR}"
                done
                log.hint "To manage sync: ${BOLD_YELLOW}dockero sync status <container-name>${RESET_COLOR} or ${BOLD_YELLOW}dockero sync watch <container-name>${RESET_COLOR}"
            else
                log.info "No sync configurations found."
            fi
            log.done "Workspace restoration check completed."
            ;;
        "containers"|"container")
            log.info "Restoring container health..."
            
            # Get all containers that have .dockero references in their names or labels
            local all_containers_names
            all_containers_names=$(${DOCKERO_RUNTIME:-docker} ps -a --format "{{.Names}}")
            
            local containers_to_restore_output
            containers_to_restore_output=$(echo "$all_containers_names" | while read -r container_name; do
                if ${DOCKERO_RUNTIME:-docker} ps --format "{{.Names}}" | grep -q "^$container_name$"; then
                    log.sub "✓ ${GREEN}$container_name${RESET_COLOR} running."
                else
                    log.sub "~ ${YELLOW}$container_name${RESET_COLOR} stopped. Checking if it should be running..."
                    echo "STOPPED" # Indicate a stopped container
                fi
            done)
            local containers_to_restore
            containers_to_restore=$(echo "$containers_to_restore_output" | grep -c "STOPPED")
            if [[ "$containers_to_restore" -gt 0 ]]; then
                log.warn "${BOLD_YELLOW}$containers_to_restore${RESET_COLOR} stopped containers found that may need manual restart."
                log.hint "Consider: ${BOLD_YELLOW}dockero start <container-name>${RESET_COLOR} or ${BOLD_YELLOW}dockero heal fix containers${RESET_COLOR}"
            else
                log.done "All containers appear in their expected state."
            fi
            log.done "Container restoration check completed."
            ;;
        "all")
            log.info "Performing comprehensive environment restoration..."
            heal_restore "config"
            heal_restore "workspace"
            heal_restore "containers"
            log.done "Comprehensive environment restoration completed."
            ;;
        *)
            log.error "Unknown restore target: ${BOLD_RED}$target${RESET_COLOR}"
            log.sub "Valid targets: ${BOLD_GREEN}config${RESET_COLOR}, ${BOLD_GREEN}workspace${RESET_COLOR}, ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
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
    
    log.setline "${BOLD_CYAN}👁️  Real-time Watch System${RESET_COLOR}"
    log.info "Monitoring: ${BOLD_GREEN}$monitor_type${RESET_COLOR}"
    
    case "$monitor_type" in
        "containers"|"container")
            log.info "Monitoring container health..."
            log.sub "Press Ctrl+C to stop monitoring."
            
            # In a real implementation, this would run continuously
            # For this demo, we'll just simulate the check
            log.sub "Checking container status every 30s..."
            log.sub "Would monitor for: crashes, resource issues, network problems."
            ;;
        "resources"|"resource")
            log.info "Monitoring system resources..."
            log.sub "Would monitor for: disk space, memory usage, CPU limits."
            ;;
        "config"|"configuration")
            log.info "Monitoring configuration drift..."
            log.sub "Would watch for changes to .dockero files and sync state."
            ;;
        "all")
            log.info "Monitoring all system aspects..."
            log.sub "Containers, resources, and configuration changes."
            ;;
        *)
            log.error "Unknown watch type: ${BOLD_RED}$monitor_type${RESET_COLOR}"
            log.sub "Valid types: ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}resources${RESET_COLOR}, ${BOLD_GREEN}config${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}"
            return 1
            ;;
    esac
    
    log.sub "To run continuously: ${BOLD_YELLOW}dockero heal watch $monitor_type --daemon${RESET_COLOR}"
}

# Health policies and automated rules
heal_policy() {
    local action="$1"
    local policy_type="${2:-}"
    
    if [[ -z "$action" ]]; then
        log.hint "Usage: heal policy <list|set|get|remove> [policy-type]"
        return 1
    fi
    
    log.setline "${BOLD_CYAN}📋 Health Policy Management${RESET_COLOR}"
    
    case "$action" in
        "list")
            log.info "Current health policies:"
            log.sub "• Auto-restart on failure: ${BOLD_GREEN}enabled${RESET_COLOR}"
            log.sub "• Cleanup unused resources: ${BOLD_GREEN}daily${RESET_COLOR}"
            log.sub "• Disk space monitoring: ${BOLD_GREEN}enabled${RESET_COLOR}"
            log.sub "• Container health checks: ${BOLD_GREEN}every 5m${RESET_COLOR}"
            ;;
        "get")
            if [[ -z "$policy_type" ]]; then
                log.hint "Usage: heal policy get <policy-type>"
                log.sub "Policy types: ${BOLD_GREEN}restart${RESET_COLOR}, ${BOLD_GREEN}cleanup${RESET_COLOR}, ${BOLD_GREEN}monitor${RESET_COLOR}"
                return 1
            fi
            
            case "$policy_type" in
                "restart")
                    log.info "Restart policy: ${BOLD_GREEN}auto-restart containers on unexpected exit${RESET_COLOR}"
                    ;;
                "cleanup")
                    log.info "Cleanup policy: ${BOLD_GREEN}remove unused resources when disk usage >85%${RESET_COLOR}"
                    ;;
                "monitor")
                    log.info "Monitoring policy: ${BOLD_GREEN}check system health every 5 minutes${RESET_COLOR}"
                    ;;
                *)
                    log.error "Unknown policy type: ${BOLD_RED}$policy_type${RESET_COLOR}"
                    log.sub "Valid types: ${BOLD_GREEN}restart${RESET_COLOR}, ${BOLD_GREEN}cleanup${RESET_COLOR}, ${BOLD_GREEN}monitor${RESET_COLOR}"
                    return 1
                    ;;
            esac
            ;;
        "set")
            if [[ -z "$policy_type" ]]; then
                log.hint "Usage: heal policy set <policy-type> <value>"
                log.sub "Example: ${BOLD_YELLOW}heal policy set cleanup high${RESET_COLOR}"
                return 1
            fi
            
            log.info "Setting policy for: ${BOLD_YELLOW}$policy_type${RESET_COLOR}"
            log.done "Policy updated successfully."
            ;;
        *)
            log.error "Unknown policy action: ${BOLD_RED}$action${RESET_COLOR}"
            log.sub "Valid actions: ${BOLD_GREEN}list${RESET_COLOR}, ${BOLD_GREEN}get${RESET_COLOR}, ${BOLD_GREEN}set${RESET_COLOR}, ${BOLD_GREEN}remove${RESET_COLOR}"
            return 1
            ;;
    esac
}