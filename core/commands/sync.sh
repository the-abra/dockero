#!/usr/bin/env bash

# Helper function to validate container paths for safe use inside containers

sync_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero sync ${GREEN}<push|pull|watch|status|init> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Synchronize files between host and container.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}push${RESET_COLOR}    Copy files from host to container.
     - ${GREEN}pull${RESET_COLOR}    Copy files from container to host.
     - ${GREEN}watch${RESET_COLOR}   Auto-sync on host file changes (requires inotify-tools).
     - ${GREEN}status${RESET_COLOR}  Show sync status for a container.
     - ${GREEN}init${RESET_COLOR}    Create a .dockero-sync config file.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker cp${RESET_COLOR} / ${YELLOW}docker exec${RESET_COLOR}
EOF
}


    local path="${1:-}"
    if [[ -z "$path" ]]; then
        log.error "Container path cannot be empty."
        return 1
    fi
    # Must start with / and not contain ../
    if [[ ! "$path" =~ ^/.* ]] || [[ "$path" =~ \.\. ]]; then
        log.error "Invalid container path: '${RED}$path${RESET_COLOR}'. Must be an absolute path (start with /) and cannot contain '..' sequences."
        return 1
    fi
    return 0
}

# Helper function to validate host paths for safe use
_sync_validate_host_path() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        log.error "Host path cannot be empty."
        return 1
    fi
    # Check for path traversal sequences
    if [[ "$path" =~ \.\. ]]; then
        log.error "Invalid host path: '${RED}$path${RESET_COLOR}'. Path traversal sequences (..) are not allowed."
        return 1
    fi
    # Ensure the path exists and is a directory
    if [[ ! -d "$path" ]]; then
        log.error "Host path does not exist or is not a directory: ${RED}$path${RESET_COLOR}."
        return 1
    fi
    return 0
}

sync() {
    local subcommand="${args[1]:-}"
    
    # Check for sync flags (none currently) - handled by parameter-indexing
    local verbose=0
    if [[ -n "${params[v]+set}" ]]; then # verbose flag
        verbose=1
    fi
    
    if [[ -z "$subcommand" ]]; then
        log.error "Subcommand required. Use: ${BOLD_YELLOW}dockero sync <push|pull|watch|status|init> [options]${RESET_COLOR}"
        log.hint "Run ${BOLD_YELLOW}dockero sync -h${RESET_COLOR} for more information."
        return 1
    fi
    
    case "$subcommand" in
        "push")
            sync_push "${args[@]:2}" "$verbose"
            ;;
        "pull")
            sync_pull "${args[@]:2}" "$verbose"
            ;;
        "watch")
            sync_watch "${args[@]:2}" "$verbose"
            ;;
        "status")
            sync_status "${args[@]:2}"
            ;;
        "init")
            sync_init "${args[@]:2}"
            ;;
        *)
            log.error "Unknown sync subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
            log.hint "Use: ${BOLD_YELLOW}dockero sync <push|pull|watch|status|init> [options]${RESET_COLOR}"
            return 1
            ;;
    esac
}

sync_push() {
    local container_name="$1"
    local path_arg="${2:-}" # User-supplied path
    local verbose="$3" # Passed from sync()
    
    if [[ -z "$container_name" ]]; then
        log.error "Container name required."
        log.hint "Usage: ${BOLD_YELLOW}dockero sync push <container-name> [path]${RESET_COLOR}"
        return 1
    fi
    # --- Input Validation ---
    if ! validate_container_name "$container_name"; then return 1; fi
    
    local container_path="${path_arg:-/workspace}" # Default to /workspace if no path specified
    if ! _sync_validate_container_path "$container_path"; then return 1; fi

    local host_path="$PWD" # Current working directory on host
    if ! _sync_validate_host_path "$host_path"; then return 1; fi # Validate PWD

    log.setline "${BOLD_CYAN}⬆️ Sync Push${RESET_COLOR}"
    log.info "Syncing from host: ${BOLD_YELLOW}$host_path${RESET_COLOR} to container: ${BOLD_YELLOW}$container_name:$container_path${RESET_COLOR}"
    
    # Check if container is running, start if not (for sync)
    local was_running=true
    if ! ${DOCKERO_RUNTIME:-docker} ps --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name is validated
        was_running=false
        log.info "Starting container '${BOLD_YELLOW}$container_name${RESET_COLOR}' temporarily for sync..."
        ${DOCKERO_RUNTIME:-docker} start "$container_name" > /dev/null || { # $container_name is validated
            log.error "Failed to start container '${RED}$container_name${RESET_COLOR}' for sync."
            return 1
        }
    fi
    
    # Create a temporary tar of the host directory and copy to container
    log.sub "Transferring files..."
    # Ensure tar is robustly handling paths. -C "$host_path" is safe.
    # ${DOCKERO_RUNTIME:-docker} exec needs validated container_name and container_path.
    if tar -cf - -C "$host_path" . | ${DOCKERO_RUNTIME:-docker} exec -i "$container_name" tar -xf - -C "$container_path"; then # Paths validated
        log.done "Files synced successfully."
    else
        log.error "Sync push operation failed."
        if [[ "$was_running" == "false" ]]; then
            ${DOCKERO_RUNTIME:-docker} stop "$container_name" > /dev/null
        fi
        return 1
    fi
    
    # Stop container if we started it just for sync
    if [[ "$was_running" == "false" ]]; then
        log.info "Stopping container '${BOLD_YELLOW}$container_name${RESET_COLOR}' after sync..."
        ${DOCKERO_RUNTIME:-docker} stop "$container_name" > /dev/null
        log.sub "Container '${BOLD_GREEN}$container_name${RESET_COLOR}' stopped."
    fi
    
    log.done "Sync completed: ${BOLD_GREEN}$host_path${RESET_COLOR} -> ${BOLD_GREEN}$container_name:$container_path${RESET_COLOR}"
}

sync_pull() {
    local container_name="$1"
    local path_arg="${2:-}" # User-supplied path
    local verbose="$3" # Passed from sync()
    
    if [[ -z "$container_name" ]]; then
        log.error "Container name required."
        log.hint "Usage: ${BOLD_YELLOW}dockero sync pull <container-name> [path]${RESET_COLOR}"
        return 1
    fi
    # --- Input Validation ---
    if ! validate_container_name "$container_name"; then return 1; fi
    
    local container_path="${path_arg:-/workspace}" # Default to /workspace
    if ! _sync_validate_container_path "$container_path"; then return 1; fi

    local host_path="$PWD"
    if ! _sync_validate_host_path "$host_path"; then return 1; fi # Validate PWD
    
    log.setline "${BOLD_CYAN}⬇️ Sync Pull${RESET_COLOR}"
    log.info "Syncing from container: ${BOLD_YELLOW}$container_name:$container_path${RESET_COLOR} to host: ${BOLD_YELLOW}$host_path${RESET_COLOR}"
    
    # Check if container is running, start if not (for sync)
    local was_running=true
    if ! ${DOCKERO_RUNTIME:-docker} ps --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name is validated
        was_running=false
        log.info "Starting container '${BOLD_YELLOW}$container_name${RESET_COLOR}' temporarily for sync..."
        ${DOCKERO_RUNTIME:-docker} start "$container_name" > /dev/null || { # $container_name is validated
            log.error "Failed to start container '${RED}$container_name${RESET_COLOR}' for sync."
            return 1
        }
    fi
    
    # Create a temporary tar from container directory and extract to host
    log.sub "Transferring files..."
    # ${DOCKERO_RUNTIME:-docker} exec needs validated container_name and container_path. -C "$host_path" is safe.
    if ${DOCKERO_RUNTIME:-docker} exec -i "$container_name" tar -cf - -C "$container_path" . | tar -xf - -C "$host_path"; then # Paths validated
        log.done "Files synced successfully."
    else
        log.error "Sync pull operation failed."
        if [[ "$was_running" == "false" ]]; then
            ${DOCKERO_RUNTIME:-docker} stop "$container_name" > /dev/null
        fi
        return 1
    fi
    
    # Stop container if we started it just for sync
    if [[ "$was_running" == "false" ]]; then
        log.info "Stopping container '${BOLD_YELLOW}$container_name${RESET_COLOR}' after sync..."
        ${DOCKERO_RUNTIME:-docker} stop "$container_name" > /dev/null
        log.sub "Container '${BOLD_GREEN}$container_name${RESET_COLOR}' stopped."
    fi
    
    log.done "Sync completed: ${BOLD_GREEN}$container_name:$container_path${RESET_COLOR} -> ${BOLD_GREEN}$host_path${RESET_COLOR}"
}

sync_watch() {
    local container_name="$1"
    local path_arg="${2:-}" # User-supplied path
    local verbose="$3" # Passed from sync()
    
    if [[ -z "$container_name" ]]; then
        log.error "Container name required."
        log.hint "Usage: ${BOLD_YELLOW}dockero sync watch <container-name> [path]${RESET_COLOR}"
        return 1
    fi
    # --- Input Validation ---
    if ! validate_container_name "$container_name"; then return 1; fi
    
    local container_path="${path_arg:-/workspace}" # Default to /workspace
    if ! _sync_validate_container_path "$container_path"; then return 1; fi

    local host_path="$PWD"
    if ! _sync_validate_host_path "$host_path"; then return 1; fi # Validate PWD
    
    # Check if inotifywait is available (for file watching)
    if ! command -v inotifywait &> /dev/null; then
        log.error "inotifywait is required for watch functionality. Please install inotify-tools."
        log.sub "On Ubuntu/Debian: ${BOLD_YELLOW}sudo apt-get install inotify-tools${RESET_COLOR}"
        log.sub "On CentOS/RHEL: ${BOLD_YELLOW}sudo yum install inotify-tools${RESET_COLOR}"
        return 1
    fi
    
    # Check if container exists
    if ! ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name is validated
        log.error "Container '${RED}$container_name${RESET_COLOR}' does not exist."
        return 1
    fi
    
    log.setline "${BOLD_CYAN}👁️ Sync Watch${RESET_COLOR}"
    log.info "Watching ${BOLD_YELLOW}$host_path${RESET_COLOR} for changes and syncing to ${BOLD_YELLOW}$container_name:$container_path${RESET_COLOR}"
    log.info "Press ${BOLD_RED}Ctrl+C${RESET_COLOR} to stop watching..."
    
    # This is a simple implementation - in a real system we'd want more robust change detection
    # The `tar -cf - -C "$host_path" "$(basename "$file")"` will be vulnerable if "$file" contains malicious characters.
    # However, $file comes from inotifywait which returns actual filenames.
    while true; do
        # Wait for file changes in the current directory
        # Using a subshell to avoid breaking the main script's IFS
        if ! (inotifywait -r -e modify,create,delete,move --format '%w%f %e' "$host_path" 2>/dev/null | while IFS= read -r line; do
            # Split the line into file and event
            local file_path_and_name
            file_path_and_name=$(echo "$line" | cut -d' ' -f1)
            local event
            event=$(echo "$line" | cut -d' ' -f2-)
            
            # Extract just the filename from the path for safe tar usage
            local file_name
            file_name=$(basename "$file_path_and_name")

            log.info "File event: ${BOLD_YELLOW}$event${RESET_COLOR} on ${BOLD_YELLOW}$file_path_and_name${RESET_COLOR}"

            # Perform a quick sync
            # Using basename "$file_path_and_name" to ensure only the file name is passed to tar
            # and -C "$host_path" to ensure it operates within the designated directory.
            if tar -cf - -C "$host_path" "$file_name" 2>/dev/null | \
               ${DOCKERO_RUNTIME:-docker} exec -i "$container_name" tar -xf - -C "$container_path" 2>/dev/null; then # Paths validated
                log.sub "Synced: ${GREEN}$file_path_and_name${RESET_COLOR}"
            else
                log.warn "Failed to sync: ${RED}$file_path_and_name${RESET_COLOR}."
            fi
        done); then
            # Break the loop if inotifywait fails (e.g. directory no longer exists)
            log.error "inotifywait failed. Stopping watch."
            break
        fi
    done
    
    log.info "Watch stopped."
}

sync_status() {
    local container_name="$1"
    
    if [[ -z "$container_name" ]]; then
        log.error "Container name required."
        log.hint "Usage: ${BOLD_YELLOW}dockero sync status <container-name>${RESET_COLOR}"
        return 1
    fi
    # --- Input Validation ---
    if ! validate_container_name "$container_name"; then return 1; fi
    
    log.setline "${BOLD_CYAN}📈 Sync Status for ${BOLD_GREEN}$container_name${RESET_COLOR}"
    
    # Get container details
    local status
    status=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "missing") # $container_name validated
    local started
    started=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.State.StartedAt}}' "$container_name" 2>/dev/null || echo "N/A") # $container_name validated
    
    log.sub "🔹 Container Status: $status"
    log.sub "🔹 Started At: $started"
    
    # Get all bind mounts
    local -a volume_info=()
    while IFS= read -r mount; do
        if [[ -n "$mount" ]]; then
            volume_info+=("$mount")
        fi
    done < <(${DOCKERO_RUNTIME:-docker} inspect -f '{{range .Mounts}}{{if eq .Type "bind"}}{{.Source}}:{{.Destination}}{{printf "\n"}}{{end}}{{end}}' "$container_name" 2>/dev/null) # $container_name validated

    if [[ ${#volume_info[@]} -gt 0 ]]; then
        log.sub "🔹 Volumes:"
        for vol in "${volume_info[@]}"; do
            log.sub "  - $vol"
        done
    else
        log.sub "🔹 Volumes: (none found or not bind-mounted)"
    fi
    
    # Check if container is running to do deeper analysis
    if ${DOCKERO_RUNTIME:-docker} ps --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name validated
        # Try to get file count from container workspace
        local file_count
        file_count=$(${DOCKERO_RUNTIME:-docker} exec "$container_name" find /workspace -type f 2>/dev/null | wc -l | tr -d ' ') # $container_name validated
        log.sub "🔹 Files in /workspace: ${file_count:-0}"
    else
        log.sub "🔹 Files in /workspace: (container not running)"
    fi
}

sync_init() {
    local project_path_arg="$1" # User-supplied project path
    
    if [[ -z "$project_path_arg" ]]; then
        log.error "Project path required."
        log.hint "Usage: ${BOLD_YELLOW}dockero sync init <project-path>${RESET_COLOR}"
        return 1
    fi

    # --- Input Validation for project_path_arg ---
    if ! _sync_validate_host_path "$project_path_arg"; then return 1; fi

    # Handle relative vs absolute paths and normalize
    local project_path
    if [[ "$project_path_arg" != /* ]]; then
        project_path="$PWD/$project_path_arg"
    else
        project_path="$project_path_arg"
    fi
    project_path=$(cd "$project_path" && pwd) # Normalize path

    local CONF_FILE="$project_path/.dockero-sync"

    if [[ ! -d "$project_path" ]]; then # Redundant due to _sync_validate_host_path, but harmless
        log.error "Project path does not exist: ${RED}$project_path${RESET_COLOR}."
        return 1
    fi

    if [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero-sync file already exists at: ${BOLD_YELLOW}$CONF_FILE${RESET_COLOR}."
        return 1
    fi

    log.setline "${BOLD_CYAN}⚙️ Sync Configuration Wizard${RESET_COLOR}"
    log.info "Creating sync configuration for: ${BOLD_GREEN}$project_path${RESET_COLOR}."

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

    log.done "Sync configuration saved to: ${BOLD_GREEN}$CONF_FILE${RESET_COLOR}."
    log.info "Edit ${YELLOW}$CONF_FILE${RESET_COLOR} to define your sync rules."
}

# Helper function to get sync configuration
# Not currently leveraged by other sync_* subcommands, but available for future use.
get_sync_config() {
    local container_name="${1:-}"
    local config_path="${2:-}"
    
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