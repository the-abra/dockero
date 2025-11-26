#!/usr/bin/env bash

system() {
    local subcommand="${args[1]}"

    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "service" && "$subcommand" != "config" && "$subcommand" != "info" && "$subcommand" != "cleanup" && "$subcommand" != "install" ]]; then
        log.hint "system <service|config|info|cleanup|install> [options]"
        return 1
    fi

    case "$subcommand" in
        "service")
            system_service "${args[2]}" "${args[3]}" "${args[4]}"
            ;;
        "config")
            system_config "${args[2]}" "${args[3]}" "${args[4]}"
            ;;
        "info")
            system_info
            ;;
        "cleanup")
            system_cleanup "${args[2]}"
            ;;
        "install")
            system_install "${args[2]}"
            ;;
        *)
            log.error "Unknown system subcommand: $subcommand"
            return 1
            ;;
    esac
}

system_service() {
    local operation="$1"
    local container_name="$2"
    local service_name="$3"
    
    # Default service name to container name if not provided
    service_name="${service_name:-$container_name}"
    
    if [[ -z "$operation" ]] || [[ -z "$container_name" ]]; then
        log.hint "system service <create|start|stop|enable|disable|status> <container-name> [service-name]"
        return 1
    fi
    
    # Check if systemd is available
    if ! command -v systemctl &> /dev/null; then
        log.error "systemctl not found. systemd is not available on this system."
        return 1
    fi
    
    local service_file="/etc/systemd/system/$service_name.service"
    # If user doesn't have permissions for /etc/systemd, use user directory
    if [[ ! -w "/etc/systemd/system" ]]; then
        service_file="$HOME/.config/systemd/user/$service_name.service"
        mkdir -p "$HOME/.config/systemd/user"
    fi
    
    case "$operation" in
        "create")
            system_create_service_file "$container_name" "$service_name" "$service_file"
            ;;
        "start")
            systemctl --user daemon-reload 2>/dev/null || systemctl daemon-reload
            systemctl --user start "$service_name" 2>/dev/null || systemctl start "$service_name"
            ;;
        "stop")
            systemctl --user stop "$service_name" 2>/dev/null || systemctl stop "$service_name"
            ;;
        "enable")
            systemctl --user daemon-reload 2>/dev/null || systemctl daemon-reload
            systemctl --user enable "$service_name" 2>/dev/null || systemctl enable "$service_name"
            ;;
        "disable")
            systemctl --user disable "$service_name" 2>/dev/null || systemctl disable "$service_name"
            ;;
        "status")
            systemctl --user status "$service_name" 2>/dev/null || systemctl status "$service_name"
            ;;
        *)
            log.error "Unknown service operation: $operation"
            log.sub "Supported operations: create, start, stop, enable, disable, status"
            return 1
            ;;
    esac
}

system_create_service_file() {
    local container_name="$1"
    local service_name="$2"
    local service_file="$3"
    
    log.info "Creating systemd service for container: $container_name"
    
    # Create the systemd service file
    cat > "$service_file" << EOF
[Unit]
Description=Dockero Container - $container_name
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker stop %i
ExecStartPre=-/usr/bin/docker rm %i
ExecStart=/usr/bin/docker start -a %i
ExecStop=/usr/bin/docker stop %i
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd to recognize the new service
    if [[ -w "/etc/systemd/system" ]]; then
        systemctl daemon-reload
    else
        systemctl --user daemon-reload
    fi
    
    log.done "Systemd service created: $service_file"
    log.info "You can now manage the service with:"
    log.sub "systemctl ( --user ) start $service_name"
    log.sub "systemctl ( --user ) enable $service_name"
    log.sub "journalctl ( --user ) -u $service_name -f"
}

system_config() {
    local operation="$1"
    local key="$2"
    local value="$3"
    
    local config_dir="$HOME/.dockero"
    mkdir -p "$config_dir"
    local config_file="$config_dir/config"
    
    case "$operation" in
        "get")
            if [[ -n "$key" ]]; then
                local result
                result=$(grep "^${key}=" "$config_file" 2>/dev/null | cut -d'=' -f2-)
                echo "${result:-}"
            else
                if [[ -f "$config_file" ]]; then
                    cat "$config_file"
                else
                    log.info "No configuration file found at $config_file"
                fi
            fi
            ;;
        "set")
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                log.hint "system config set <key> <value>"
                return 1
            fi
            
            # Remove existing key if it exists
            if [[ -f "$config_file" ]]; then
                grep -v "^${key}=" "$config_file" > "$config_file.tmp" 2>/dev/null
                mv "$config_file.tmp" "$config_file" 2>/dev/null
            fi
            
            # Add the new key-value pair
            echo "$key=$value" >> "$config_file"
            log.done "Configuration updated: $key=$value"
            ;;
        "list")
            if [[ -f "$config_file" ]]; then
                log.info "Current configuration values:"
                while IFS= read -r line; do
                    [[ -n "$line" && "$line" != \#* ]] && echo "  $line"
                done < "$config_file"
            else
                log.info "No configuration file found at $config_file"
            fi
            ;;
        "reset")
            if [[ -f "$config_file" ]]; then
                rm "$config_file"
                log.done "Configuration file removed: $config_file"
            else
                log.warn "Configuration file not found: $config_file"
            fi
            ;;
        *)
            log.hint "system config <get|set|list|reset> [key] [value]"
            return 1
            ;;
    esac
}

system_info() {
    log.setline "System Information"
    
    # Check Docker installation
    if command -v docker &> /dev/null; then
        log.info "Docker: $(docker --version)"
        log.sub "Docker daemon: $(docker info --format '{{.ServerVersion}}' 2>/dev/null || echo 'not running')"
    else
        log.warn "Docker: Not installed"
        # Check for Podman as alternative
        if command -v podman &> /dev/null; then
            log.info "Podman: $(podman --version)"
        fi
    fi
    
    # Check systemd availability
    if command -v systemctl &> /dev/null; then
        log.info "Systemd: Available"
    else
        log.warn "Systemd: Not available"
    fi
    
    # Check file system type for Docker
    local docker_root_dir
    docker_root_dir=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
    if [[ -d "$docker_root_dir" ]]; then
        local fs_type
        fs_type=$(df -T "$docker_root_dir" | tail -1 | awk '{print $2}')
        log.info "Docker storage filesystem: $fs_type"
    fi
    
    # Check available disk space
    if command -v df &> /dev/null; then
        local docker_space
        docker_space=$(df -h "$docker_root_dir" 2>/dev/null | tail -1 | awk '{print $4}')
        log.info "Available Docker space: ${docker_space:-Unknown}"
    fi
    
    # Check for additional utilities
    local utilities=("inotifywait" "rsync" "systemctl" "tput" "lsof" "netstat")
    log.info "System utilities:"
    for util in "${utilities[@]}"; do
        if command -v "$util" &> /dev/null; then
            log.sub "✓ $util"
        else
            log.sub "✗ $util"
        fi
    done
}

system_cleanup() {
    local target="${1:-}"
    
    log.setline "System Cleanup"
    
    case "$target" in
        "containers")
            log.info "Removing stopped containers..."
            docker container prune -f
            ;;
        "images")
            log.info "Removing unused images..."
            docker image prune -f
            ;;
        "volumes")
            log.info "Removing unused volumes..."
            docker volume prune -f
            ;;
        "networks")
            log.info "Removing unused networks..."
            docker network prune -f
            ;;
        "all")
            log.info "Removing all unused resources..."
            docker system prune -f --volumes
            ;;
        "temp")
            log.info "Cleaning up temporary files..."
            # Remove any leftover temporary files from previous operations
            rm -f /tmp/*.dockero.*.log
            ;;
        "")
            log.info "Running basic cleanup..."
            docker container prune -f 2>/dev/null || true
            docker image prune -f 2>/dev/null || true
            ;;
        *)
            log.error "Unknown cleanup target: $target"
            log.sub "Valid targets: containers, images, volumes, networks, all, temp"
            return 1
            ;;
    esac
    
    log.done "Cleanup completed"
}

system_install() {
    local location="${1:-/usr/local/bin}"
    
    log.setline "System Installation"
    log.info "Installing Dockero to: $location"
    
    # Check if we have write permissions
    if [[ ! -w "$location" ]]; then
        log.error "No write permission to: $location"
        log.sub "Try using sudo or specify a user directory"
        return 1
    fi
    
    local target="$location/dockero"
    local source="${BASH_SOURCE[0]%/*}/../dockero.sh"
    
    # Copy the main script
    if cp "$source" "$target"; then
        chmod +x "$target"
        log.done "Dockero installed to: $target"
        log.info "You can now run 'dockero' from anywhere"
    else
        log.error "Failed to install dockero to: $target"
        return 1
    fi
    
    # Suggest adding to PATH if not already there
    if ! command -v dockero &> /dev/null; then
        log.sub "Add $location to your PATH in ~/.bashrc or ~/.profile:"
        log.sub "export PATH=\$PATH:$location"
    fi
}