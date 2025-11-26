#!/usr/bin/env bash

sync() {
    local subcommand="${args[1]}"
    
    # Check for sync flags (none currently)
    local verbose=0
    if [[ -n "${params[v]+set}" ]]; then
        verbose=1
    fi
    
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "push" && "$subcommand" != "pull" && "$subcommand" != "watch" && "$subcommand" != "status" && "$subcommand" != "init" ]]; then
        log.hint "sync <push|pull|watch|status|init> [options]"
        return 1
    fi
    
    case "$subcommand" in
        "push")
            sync_push "${args[2]}" "${args[3]}"
            ;;
        "pull")
            sync_pull "${args[2]}" "${args[3]}"
            ;;
        "watch")
            sync_watch "${args[2]}" "${args[3]}"
            ;;
        "status")
            sync_status "${args[2]}"
            ;;
        "init")
            sync_init "${args[2]:-./}"
            ;;
        *)
            log.error "Unknown sync subcommand: $subcommand"
            return 1
            ;;
    esac
}

sync_push() {
    local container_name="$1"
    local path="$2"
    
    if [[ -z "$container_name" ]]; then
        log.hint "sync push <container-name> [path]"
        return 1
    fi
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        log.error "Container '$container_name' does not exist"
        return 1
    fi
    
    # Default to /workspace if no path specified
    local container_path="${path:-/workspace}"
    local host_path="$PWD"
    
    log.setline "Sync Push"
    log.info "Syncing from host: $host_path to container: $container_name:$container_path"
    
    # Check if container is running, start if not (for sync)
    local was_running=1
    if ! docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        was_running=0
        log.info "Starting container temporarily for sync..."
        docker start "$container_name" > /dev/null || {
            log.error "Failed to start container for sync"
            return 1
        }
    fi
    
    # Create a temporary tar of the host directory and copy to container
    if tar -cf - . | docker exec -i "$container_name" tar -xf - -C "$container_path"; then
        if [[ $verbose -eq 1 ]]; then
            log.done "Files synced successfully"
        fi
    else
        log.error "Sync operation failed"
        if [[ $was_running -eq 0 ]]; then
            docker stop "$container_name" > /dev/null
        fi
        return 1
    fi
    
    # Stop container if we started it just for sync
    if [[ $was_running -eq 0 ]]; then
        log.info "Stopping container after sync..."
        docker stop "$container_name" > /dev/null
    fi
    
    log.done "Sync completed: $host_path -> $container_name:$container_path"
}

sync_pull() {
    local container_name="$1"
    local path="$2"
    
    if [[ -z "$container_name" ]]; then
        log.hint "sync pull <container-name> [path]"
        return 1
    fi
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        log.error "Container '$container_name' does not exist"
        return 1
    fi
    
    local container_path="${path:-/workspace}"
    local host_path="$PWD"
    
    log.setline "Sync Pull"
    log.info "Syncing from container: $container_name:$container_path to host: $host_path"
    
    # Check if container is running, start if not (for sync)
    local was_running=1
    if ! docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        was_running=0
        log.info "Starting container temporarily for sync..."
        docker start "$container_name" > /dev/null || {
            log.error "Failed to start container for sync"
            return 1
        }
    fi
    
    # Create a temporary tar from container directory and extract to host
    if docker exec -i "$container_name" tar -cf - -C "$container_path" . | tar -xf - -C "$host_path"; then
        if [[ $verbose -eq 1 ]]; then
            log.done "Files synced successfully"
        fi
    else
        log.error "Sync operation failed"
        if [[ $was_running -eq 0 ]]; then
            docker stop "$container_name" > /dev/null
        fi
        return 1
    fi
    
    # Stop container if we started it just for sync
    if [[ $was_running -eq 0 ]]; then
        log.info "Stopping container after sync..."
        docker stop "$container_name" > /dev/null
    fi
    
    log.done "Sync completed: $container_name:$container_path -> $host_path"
}

sync_watch() {
    local container_name="$1"
    local path="$2"
    
    if [[ -z "$container_name" ]]; then
        log.hint "sync watch <container-name> [path]"
        return 1
    fi
    
    # Check if inotifywait is available (for file watching)
    if ! command -v inotifywait &> /dev/null; then
        log.error "inotifywait is required for watch functionality. Please install inotify-tools."
        log.sub "On Ubuntu/Debian: sudo apt-get install inotify-tools"
        log.sub "On CentOS/RHEL: sudo yum install inotify-tools"
        return 1
    fi
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        log.error "Container '$container_name' does not exist"
        return 1
    fi
    
    local container_path="${path:-/workspace}"
    local host_path="$PWD"
    
    log.setline "Sync Watch"
    log.info "Watching $host_path for changes and syncing to $container_name:$container_path"
    log.info "Press Ctrl+C to stop watching..."
    
    # This is a simple implementation - in a real system we'd want more robust change detection
    while true; do
        # Wait for file changes in the current directory
        if ! inotifywait -r -e modify,create,delete,move --format '%w%f %e' "$host_path" 2>/dev/null | while IFS= read -r line; do
            # Split the line into file and event
            local file
            file=$(echo "$line" | cut -d' ' -f1)
            local event
            event=$(echo "$line" | cut -d' ' -f2-)

            log.info "File $event: $file"

            # Perform a quick sync
            if tar -cf - -C "$host_path" "$(basename "$file")" 2>/dev/null | \
               docker exec -i "$container_name" tar -xf - -C "$container_path" 2>/dev/null; then
                log.sub "Synced: $file"
            else
                log.warn "Failed to sync: $file"
            fi
        done; then
            # Break the loop if inotifywait fails
            break
        fi
    done
    
    log.info "Watch stopped."
}

sync_status() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        log.hint "sync status <container-name>"
        return 1
    fi
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        log.error "Container '$container_name' does not exist"
        return 1
    fi
    
    log.setline "Sync Status"
    log.info "Sync status for container: $container_name"
    
    # Get container details
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "missing")
    local started
    started=$(docker inspect -f '{{.State.StartedAt}}' "$container_name" 2>/dev/null || echo "N/A")
    local volume_info
    volume_info=$(docker inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}:{{.Destination}} {{end}}{{end}}' "$container_name" 2>/dev/null | tr ' ' '\n' | grep -v '^$' | head -1)
    
    echo "  🔹 Container Status: $status"
    echo "  🔹 Started At: $started"
    
    if [[ -n "$volume_info" ]]; then
        echo "  🔹 Volumes: $volume_info"
    else
        echo "  🔹 Volumes: (none found or not bind-mounted)"
    fi
    
    # Check if container is running to do deeper analysis
    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
        # Try to get file count from container workspace
        local file_count
        file_count=$(docker exec "$container_name" find /workspace -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "  🔹 Files in /workspace: ${file_count:-0}"
    else
        echo "  🔹 Files in /workspace: (container not running)"
    fi
}

sync_init() {
    local project_path="$1"
    [[ -z "$project_path" ]] && log.hint "sync init <project-path>" && return 1

    # Handle relative vs absolute paths
    if [[ "$project_path" != /* ]]; then
        project_path="$PWD/$project_path"
    fi

    # Normalize path (remove trailing /./)
    project_path=$(cd "$project_path" && pwd)
    CONF_FILE="$project_path/.dockero-sync"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project path does not exist: ${project_path}"
        return 1
    fi

    if [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero-sync file already exists at: $CONF_FILE"
        return 1
    fi

    log.setline "Sync Configuration"
    log.info "Creating sync configuration for: $project_path"

    # Create a basic sync configuration
    cat > "$CONF_FILE" << EOF
# Dockero Sync Configuration
# Defines sync rules for the project

[default]
# Default container to sync with
container =

# Sync rules
# Format: local_path:container_path:sync_direction
# sync_direction can be: push, pull, bidirectional, ignore
[sync_rules]
# Example: ./src:/app/src:bidirectional
# Example: ./docs:/app/docs:push
# Example: ./node_modules:/app/node_modules:ignore

EOF

    log.done "Sync configuration saved to: $CONF_FILE"
    log.info "Edit $CONF_FILE to define your sync rules"
}

# Helper function to get sync configuration
get_sync_config() {
    local container_name="$1"
    local config_path="$2"
    
    # Look for dockero sync config in current directory or project root
    local sync_conf="./.dockero-sync"
    if [[ -n "$config_path" && -f "$config_path/.dockero-sync" ]]; then
        sync_conf="$config_path/.dockero-sync"
    elif [[ -f "./.dockero-sync" ]]; then
        sync_conf="./.dockero-sync"
    elif [[ -f ".dockero" ]]; then
        # If we have a .dockero file, try to get container name from it
        if [[ -z "$container_name" ]]; then
            container_name=$(inipars.get "default" "name" ".dockero")
        fi
        sync_conf="./.dockero-sync"
    fi
    
    echo "$sync_conf"
}