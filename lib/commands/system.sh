#!/usr/bin/env bash

# Helper function to validate service names for safe use

system_help() {
cat << EOF
${BOLD_CYAN}dockero system ${GREEN}<service|config|info|cleanup|install|dev> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} System integration and management.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}service${RESET_COLOR}   Manage containers as systemd services.
     - ${GREEN}config${RESET_COLOR}    Manage Dockero configuration (get/set/list/reset).
     - ${GREEN}info${RESET_COLOR}      Display system and Dockero environment info.
     - ${GREEN}cleanup${RESET_COLOR}   Clean up Docker resources.
     - ${GREEN}install${RESET_COLOR}   Install Dockero to a system location.
     - ${GREEN}dev${RESET_COLOR}       Convert installation to development symlinked setup.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker system prune / docker info${RESET_COLOR}
EOF
}


_system_validate_service_name() {
    local name="$1"
    # systemd service names generally allow alphanumeric, hyphens, and dots.
    if [[ ! "$name" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        log.error "Invalid service name: '${RED}$name${RESET_COLOR}'. Service names can only contain alphanumeric characters, hyphens, and dots."
        return 1
    fi
    return 0
}

# Helper function to validate installation path
_system_validate_install_path() {
    local path="$1"
    # Basic path validation: no '..' for directory traversal
    if [[ "$path" =~ \.\. ]]; then
        log.error "Invalid installation path: '${RED}$path${RESET_COLOR}'. Path traversal sequences (..) are not allowed."
        return 1
    fi
    return 0
}


system() {
    local subcommand="${args[1]:-}"

    if [[ -z "$subcommand" ]]; then
        log.error "Subcommand required. Use: ${BOLD_YELLOW}dockero system <service|config|info|cleanup|install|dev> [options]${RESET_COLOR}"
        log.hint "Run ${BOLD_YELLOW}dockero system -h${RESET_COLOR} for more information."
        return 1
    fi

    case "$subcommand" in
        "service")
            system_service "${args[@]:2}"
            ;;
        "config")
            system_config "${args[@]:2}"
            ;;
        "info")
            system_info
            ;;
        "cleanup")
            system_cleanup "${args[@]:2}"
            ;;
        "install")
            system_install "${args[@]:2}"
            ;;
        "dev")
            system_dev
            ;;
        *)
            log.error "Unknown system subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
            log.hint "Use: ${BOLD_YELLOW}dockero system <service|config|info|cleanup|install|dev> [options]${RESET_COLOR}"
            return 1
            ;;
    esac
}

system_service() {
    local operation="$1"
    local container_name_arg="$2" # User-supplied container name
    local service_name_arg="$3" # User-supplied service name
    
    # Validate user inputs early
    if [[ -n "$container_name_arg" ]] && ! validate_container_name "$container_name_arg"; then return 1; fi
    if [[ -n "$service_name_arg" ]] && ! _system_validate_service_name "$service_name_arg"; then return 1; fi

    # Default service name to container name if not provided
    local container_name="${container_name_arg}"
    local service_name="${service_name_arg:-$container_name}"
    
    if [[ -z "$operation" ]] || [[ -z "$container_name" ]]; then
        log.error "Operation and container name required."
        log.hint "Usage: ${BOLD_YELLOW}dockero system service <create|start|stop|enable|disable|status> <container-name> [service-name]${RESET_COLOR}"
        return 1
    fi
    
    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        log.error "systemctl not found. ${RED}systemd is not available on this system.${RESET_COLOR}"
        return 1
    fi
    
    local service_file_base="$service_name.service"
    local service_file=""

    # If user doesn't have permissions for /etc/systemd, use user directory
    if [[ ! -w "/etc/systemd/system" ]]; then
        mkdir -p "$HOME/.config/systemd/user" 2>/dev/null
        service_file="$HOME/.config/systemd/user/$service_file_base"
        log.warn "No write permission to /etc/systemd/system. Using user service directory: ${BOLD_YELLOW}$service_file${RESET_COLOR}"
    else
        service_file="/etc/systemd/system/$service_file_base"
    fi
    
    log.setline "${BOLD_CYAN}System Service Management: ${GREEN}$service_name${RESET_COLOR}"

    case "$operation" in
        "create")
            system_create_service_file "$container_name" "$service_name" "$service_file"
            ;;
        "start")
            log.info "Starting systemd service: ${BOLD_YELLOW}$service_name${RESET_COLOR}."
            systemctl --user daemon-reload &>/dev/null || sudo systemctl daemon-reload &>/dev/null
            if systemctl --user start "$service_name" &>/dev/null || sudo systemctl start "$service_name" &>/dev/null; then # $service_name is validated
                log.done "Service '${BOLD_GREEN}$service_name${RESET_COLOR}' started."
            else
                log.error "Failed to start service '${RED}$service_name${RESET_COLOR}'."
                return 1
            fi
            ;;
        "stop")
            log.info "Stopping systemd service: ${BOLD_YELLOW}$service_name${RESET_COLOR}."
            if systemctl --user stop "$service_name" &>/dev/null || sudo systemctl stop "$service_name" &>/dev/null; then # $service_name is validated
                log.done "Service '${BOLD_GREEN}$service_name${RESET_COLOR}' stopped."
            else
                log.error "Failed to stop service '${RED}$service_name${RESET_COLOR}'."
                return 1
            fi
            ;;
        "enable")
            log.info "Enabling systemd service: ${BOLD_YELLOW}$service_name${RESET_COLOR}."
            systemctl --user daemon-reload &>/dev/null || sudo systemctl daemon-reload &>/dev/null
            if systemctl --user enable "$service_name" &>/dev/null || sudo systemctl enable "$service_name" &>/dev/null; then # $service_name is validated
                log.done "Service '${BOLD_GREEN}$service_name${RESET_COLOR}' enabled."
            else
                log.error "Failed to enable service '${RED}$service_name${RESET_COLOR}'."
                return 1
            fi
            ;;
        "disable")
            log.info "Disabling systemd service: ${BOLD_YELLOW}$service_name${RESET_COLOR}."
            if systemctl --user disable "$service_name" &>/dev/null || sudo systemctl disable "$service_name" &>/dev/null; then # $service_name is validated
                log.done "Service '${BOLD_GREEN}$service_name${RESET_COLOR}' disabled."
            else
                log.error "Failed to disable service '${RED}$service_name${RESET_COLOR}'."
                return 1
            fi
            ;;
        "status")
            log.info "Checking status of systemd service: ${BOLD_YELLOW}$service_name${RESET_COLOR}."
            systemctl --user status "$service_name" || systemctl status "$service_name" # $service_name is validated
            ;;
        *)
            log.error "Unknown service operation: ${BOLD_RED}$operation${RESET_COLOR}"
            log.sub "Supported operations: ${BOLD_GREEN}create${RESET_COLOR}, ${BOLD_GREEN}start${RESET_COLOR}, ${BOLD_GREEN}stop${RESET_COLOR}, ${BOLD_GREEN}enable${RESET_COLOR}, ${BOLD_GREEN}disable${RESET_COLOR}, ${BOLD_GREEN}status${RESET_COLOR}"
            return 1
            ;;
    esac
}

system_create_service_file() {
    local container_name="$1"
    local service_name="$2"
    local service_file="$3"
    
    log.info "Creating systemd service file for container: ${BOLD_YELLOW}$container_name${RESET_COLOR} at ${BOLD_YELLOW}$service_file${RESET_COLOR}."
    
    # Check if the container exists
    if ! ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name is validated
        log.error "Container '${RED}$container_name${RESET_COLOR}' does not exist. Cannot create service file."
        return 1
    fi

    # Create the systemd service file (container_name and service_name are validated)
    cat > "$service_file" << EOF
[Unit]
Description=Dockero Container - $container_name
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/${DOCKERO_RUNTIME:-docker} stop $container_name
ExecStartPre=-/usr/bin/${DOCKERO_RUNTIME:-docker} rm $container_name
ExecStart=/usr/bin/${DOCKERO_RUNTIME:-docker} start -a $container_name
ExecStop=/usr/bin/${DOCKERO_RUNTIME:-docker} stop $container_name
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd to recognize the new service
    log.info "Reloading systemd daemon..."
    if [[ -w "/etc/systemd/system" ]]; then
        sudo systemctl daemon-reload
    else
        systemctl --user daemon-reload
    fi
    
    log.done "Systemd service '${BOLD_GREEN}$service_name${RESET_COLOR}' created: ${BOLD_GREEN}$service_file${RESET_COLOR}."
    log.info "You can now manage the service with:"
    log.sub "${BOLD_YELLOW}systemctl (--user) start $service_name${RESET_COLOR}"
    log.sub "${BOLD_YELLOW}systemctl (--user) enable $service_name${RESET_COLOR}"
    log.sub "${BOLD_YELLOW}journalctl (--user) -u $service_name -f${RESET_COLOR}"
}

system_config() {
    local operation="$1"
    local key="$2"
    local value="$3"
    
    local config_dir="$HOME/.dockero"
    mkdir -p "$config_dir"
    local config_file="$config_dir/config"
    
    log.setline "${BOLD_CYAN}Dockero Configuration Management${RESET_COLOR}"

    case "$operation" in
        "get")
            if [[ -n "$key" ]]; then
                # inipars.get already handles key escaping for regex, no further validation needed for key here
                local result
                result=$(inipars.get "default" "$key" "$config_file") # Using inipars.get
                if [[ -n "$result" ]]; then
                    log.sub "$key=$result"
                else
                    log.warn "Configuration key '${BOLD_YELLOW}$key${RESET_COLOR}' not found in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                    return 1
                fi
            else
                if [[ -f "$config_file" ]]; then
                    log.info "Current configuration in ${BOLD_YELLOW}$config_file${RESET_COLOR}:"
                    cat "$config_file" # Display raw content for now
                else
                    log.info "No configuration file found at ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                fi
            fi
            ;;
        "set")
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                log.error "Key and value required."
                log.hint "Usage: ${BOLD_YELLOW}dockero system config set <key> <value>${RESET_COLOR}"
                return 1
            fi
            # inipars.set already handles key escaping for regex, no further validation needed for key/value here
            inipars.set "default" "$key" "$value" "$config_file" # Using inipars.set
            log.done "Configuration updated: ${BOLD_GREEN}$key=${value}${RESET_COLOR} in ${BOLD_GREEN}$config_file${RESET_COLOR}."
            ;;
        "list")
            if [[ -f "$config_file" ]]; then
                log.info "Current configuration values in ${BOLD_YELLOW}$config_file${RESET_COLOR}:"
                # Using inipars.section to get formatted output for the [default] section
                local config_entries
                config_entries=$(inipars.section "default" "$config_file")
                if [[ -n "$config_entries" ]]; then
                    echo "$config_entries" | while IFS= read -r line; do
                        local entry_key="${line%%=*}"
                        local entry_value="${line#*=}"
                        log.sub "  $entry_key=$entry_value"
                    done
                else
                    log.info "No entries in [default] section of ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                fi
            else
                log.info "No configuration file found at ${BOLD_YELLOW}$config_file${RESET_COLOR}."
            fi
            ;;
        "reset")
            if [[ -f "$config_file" ]]; then
                rm "$config_file"
                log.done "Configuration file '${BOLD_GREEN}$config_file${RESET_COLOR}' removed."
            else
                log.warn "Configuration file '${BOLD_YELLOW}$config_file${RESET_COLOR}' not found. Nothing to reset."
            fi
            ;;
        *)
            log.error "Unknown config operation: ${BOLD_RED}$operation${RESET_COLOR}"
            log.hint "Usage: ${BOLD_YELLOW}dockero system config <get|set|list|reset> [key] [value]${RESET_COLOR}"
            return 1
            ;;
    esac
}

system_info() {
    log.setline "${BOLD_CYAN}ℹ️ System Information${RESET_COLOR}"
    
    # Check Docker installation
    if command -v docker &> /dev/null; then
        log.info "Docker: ${BOLD_GREEN}$(docker --version | head -n 1)${RESET_COLOR}"
        local docker_daemon_status
        if ${DOCKERO_RUNTIME:-docker} ps -q &> /dev/null; then # Faster check
            docker_daemon_status="${BOLD_GREEN}Running${RESET_COLOR}"
        else
            docker_daemon_status="${RED}Not running${RESET_COLOR}"
        fi
        log.sub "Docker daemon: $docker_daemon_status (Version: $(${DOCKERO_RUNTIME:-docker} info --format '{{.ServerVersion}}' 2>/dev/null || echo 'N/A'))"
    else
        log.warn "Docker: ${RED}Not installed${RESET_COLOR}"
        # Check for Podman as alternative
        if command -v podman &> /dev/null; then
            log.info "Podman: ${BOLD_GREEN}$(podman --version | head -n 1)${RESET_COLOR}"
        fi
    fi
    
    # Check systemd availability
    if command -v systemctl &> /dev/null; then
        log.info "Systemd: ${BOLD_GREEN}Available${RESET_COLOR}"
    else
        log.warn "Systemd: ${BOLD_RED}Not available${RESET_COLOR}"
    fi
    
    # Check file system type for Docker
    local docker_root_dir
    docker_root_dir=$(${DOCKERO_RUNTIME:-docker} info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
    if [[ -d "$docker_root_dir" ]]; then
        local fs_type
        fs_type=$(df -T "$docker_root_dir" | tail -1 | awk '{print $2}')
        log.info "Docker storage filesystem: ${BOLD_YELLOW}$fs_type${RESET_COLOR}"
    else
        log.warn "Docker root directory not found: ${BOLD_YELLOW}$docker_root_dir${RESET_COLOR}"
    fi
    
    # Check available disk space
    if command -v df &> /dev/null; then
        local docker_space
        docker_space=$(df -h "$docker_root_dir" 2>/dev/null | tail -1 | awk '{print $4}')
        log.info "Available Docker space: ${BOLD_GREEN}${docker_space:-Unknown}${RESET_COLOR}"
    fi
    
    # Check for additional utilities
    local -a utilities=("inotifywait" "rsync" "systemctl" "tput" "lsof" "netstat" "jq")
    log.info "System utilities status:"
    for util in "${utilities[@]}"; do
        if command -v "$util" &> /dev/null; then
            log.sub "✓ ${GREEN}$util${RESET_COLOR}"
        else
            log.sub "✗ ${RED}$util${RESET_COLOR}"
        fi
    done
}

system_cleanup() {
    local target="$1" # "${args[@]:2}" for subcommand args, but cleanup only takes 1 (target)
    
    if [[ -z "$target" ]]; then
        target="all"
    fi

    log.setline "${BOLD_CYAN}🧹 System Cleanup${RESET_COLOR}"
    log.info "Performing cleanup for target: ${BOLD_YELLOW}$target${RESET_COLOR}."

    case "$target" in
        "containers")
            log.info "Removing stopped containers..."
            if ${DOCKERO_RUNTIME:-docker} container prune -f > /dev/null; then
                log.done "Stopped containers removed."
            else
                log.error "Failed to remove stopped containers."
            fi
            ;;
        "images")
            log.info "Removing unused images..."
            if ${DOCKERO_RUNTIME:-docker} image prune -f > /dev/null; then
                log.done "Unused images removed."
            else
                log.error "Failed to remove unused images."
            fi
            ;;
        "volumes")
            log.info "Removing unused volumes..."
            if ${DOCKERO_RUNTIME:-docker} volume prune -f > /dev/null; then
                log.done "Unused volumes removed."
            else
                log.error "Failed to remove unused volumes."
            fi
            ;;
        "networks")
            log.info "Removing unused networks using ${BOLD_YELLOW}dockero net prune${RESET_COLOR}..."
            if net prune; then
                log.done "Unused networks removed."
            else
                log.error "Failed to remove unused networks."
            fi
            ;;
        "all")
            log.info "Removing all unused resources (containers, images, volumes, networks)..."
            if ${DOCKERO_RUNTIME:-docker} system prune -f --volumes > /dev/null; then
                log.done "All unused resources removed."
            else
                log.error "Failed to remove all unused resources."
            fi
            ;;
        "temp")
            log.info "Cleaning up temporary files..."
            local removed_count=0
            while IFS= read -r -d $'\0' file; do
                if rm -f "$file"; then
                    ((removed_count++)) || true
                fi
            done < <(find /tmp -maxdepth 1 -name "dockero_*" -print0 2>/dev/null)
            
            if [[ "$removed_count" -gt 0 ]]; then
                log.done "Removed ${BOLD_GREEN}$removed_count${RESET_COLOR} temporary files from /tmp."
            else
                log.info "No dockero temporary files found in /tmp."
            fi
            ;;
        *)
            log.error "Unknown cleanup target: ${BOLD_RED}$target${RESET_COLOR}"
            log.sub "Valid targets: ${BOLD_GREEN}containers${RESET_COLOR}, ${BOLD_GREEN}images${RESET_COLOR}, ${BOLD_GREEN}volumes${RESET_COLOR}, ${BOLD_GREEN}networks${RESET_COLOR}, ${BOLD_GREEN}all${RESET_COLOR}, ${BOLD_GREEN}temp${RESET_COLOR}"
            return 1
            ;;
    esac
    
    log.done "Cleanup completed."
    return 0
}

system_install() {
    local location="${1:-/usr/local/bin}"
    
    log.setline "${BOLD_CYAN}Dockero System Installation${RESET_COLOR}"
    log.info "Installing Dockero to: ${BOLD_YELLOW}$location${RESET_COLOR}."
    
    # --- Input Validation for location ---
    if ! _system_validate_install_path "$location"; then return 1; fi

    # Check if we have write permissions
    if [[ ! -w "$location" ]]; then
        log.error "No write permission to: ${RED}$location${RESET_COLOR}."
        log.sub "Try using '${BOLD_YELLOW}sudo dockero system install${RESET_COLOR}' or specify a user-writable directory."
        return 1
    fi
    
    local target_path="$location/dockero"
    local source_script="${BASH_SOURCE[0]%/*}/../dockero" # Path to main dockero script
    
    # Copy the main script
    log.info "Copying main script from ${YELLOW}$source_script${RESET_COLOR} to ${YELLOW}$target_path${RESET_COLOR}."
    if cp "$source_script" "$target_path"; then
        chmod +x "$target_path"
        log.done "Dockero installed to: ${BOLD_GREEN}$target_path${RESET_COLOR}."
    else
        log.error "Failed to install dockero to: ${RED}$target_path${RESET_COLOR}."
        return 1
    fi
    
    # Suggest adding to PATH if not already there
    if ! command -v dockero &> /dev/null; then
        log.warn "Dockero is not yet in your PATH."
        log.sub "Add '${BOLD_YELLOW}$location${RESET_COLOR}' to your PATH in ${BOLD_YELLOW}~/.bashrc${RESET_COLOR} or ${BOLD_YELLOW}~/.profile${RESET_COLOR}:"
        log.sub "${GREEN}export PATH=\"\$PATH:$location\"${RESET_COLOR}"
    fi
    log.done "Installation completed."
    return 0
}

system_dev() {
    log.setline "Convert to Development Setup"
    
    local repo_dir
    repo_dir=$(pwd)
    
    # Verify that we are indeed in a dockero repository
    if [[ ! -f "$repo_dir/dist/dockero" ]]; then
        if [[ -f "$repo_dir/Makefile" ]]; then
            log.info "dist/dockero not found. Running 'make build' first..."
            make build
        else
            log.error "Please run this command from the root of your dockero repository."
            return 1
        fi
    fi
    
    local exec_dest="/usr/local/bin/dockero"
    local bash_completion_dest="/etc/bash_completion.d/dockero"
    local zsh_completion_dest="/usr/local/share/zsh/site-functions/_dockero"

    log.info "Checking for existing copied binaries/files to clean up..."

    # Remove executable if it exists
    if [[ -f "$exec_dest" || -L "$exec_dest" ]]; then
        log.info "Removing existing executable at $exec_dest..."
        if ! rm -f "$exec_dest" 2>/dev/null; then
            log.error "Permission denied. Please run as root (sudo dockero system dev)."
            return 1
        fi
    fi

    # Remove Bash completions
    if [[ -f "$bash_completion_dest" || -L "$bash_completion_dest" ]]; then
        log.info "Removing existing Bash completions at $bash_completion_dest..."
        rm -f "$bash_completion_dest" 2>/dev/null
    fi

    # Remove Zsh completions
    if [[ -f "$zsh_completion_dest" || -L "$zsh_completion_dest" ]]; then
        log.info "Removing existing Zsh completions at $zsh_completion_dest..."
        rm -f "$zsh_completion_dest" 2>/dev/null
    fi

    log.info "Creating development symbolic links from $repo_dir..."

    # Link executable
    if ln -sf "$repo_dir/dist/dockero" "$exec_dest" 2>/dev/null; then
        chmod +x "$repo_dir/dist/dockero"
        log.done "Linked executable: $exec_dest -> $repo_dir/dist/dockero"
    else
        log.error "Failed to create link: $exec_dest. Try running with sudo."
        return 1
    fi

    # Link Bash completions
    if ln -sf "$repo_dir/completions/bash/dockero" "$bash_completion_dest" 2>/dev/null; then
        log.done "Linked Bash completions: $bash_completion_dest -> $repo_dir/completions/bash/dockero"
    else
        log.warn "Could not link Bash completions to $bash_completion_dest."
    fi

    # Link Zsh completions
    if mkdir -p "$(dirname "$zsh_completion_dest")" 2>/dev/null && ln -sf "$repo_dir/completions/zsh/_dockero" "$zsh_completion_dest" 2>/dev/null; then
        log.done "Linked Zsh completions: $zsh_completion_dest -> $repo_dir/completions/zsh/_dockero"
    else
        log.warn "Could not link Zsh completions to $zsh_completion_dest."
    fi

    log.done "Development setup conversion completed successfully!"
    return 0
}