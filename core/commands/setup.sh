setup() {
    # Access the global params and args arrays set by parameter-indexing.sh

    # Check if any parameter flags were passed (e.g., --dry-run or -n)
    local has_dry_run=0
    if [[ -n "${params[n]+set}" ]]; then  # Using -n flag for dry-run (like docker)
        has_dry_run=1
    fi

    local subcommand="${args[1]}"

    # If no subcommand is provided or if it's a path, use 'run' as default
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "init" && "$subcommand" != "run" && "$subcommand" != "create" && "$subcommand" != "build" && "$subcommand" != "update" && "$subcommand" != "teardown" && "$subcommand" != "delete" ]]; then
        if [[ $has_dry_run -eq 1 ]]; then
            # If --dry-run was specified but no explicit subcommand, assume 'run'
            setup_run_with_dryrun "${args[1]}"
        else
            setup_run "${args[1]}"
        fi
    else
        case "$subcommand" in
            "init"|"create")
                setup_init "${args[2]:-./}"
                ;;
            "run"|"build")
                if [[ $has_dry_run -eq 1 ]]; then
                    setup_run_with_dryrun "${args[2]}"
                else
                    setup_run "${args[2]}"
                fi
                ;;
            "update")
                setup_update "${args[2]}"
                ;;
            "teardown"|"delete")
                setup_teardown "${args[2]}"
                ;;
            *)
                log.error "Unknown setup subcommand: $subcommand"
                log.hint "Usage: dockero setup [init|run|update|teardown] [path]"
                return 1
                ;;
        esac
    fi
}

setup_run() {
    local project_path="$1"
    local dry_run=0

    # Check for --dry-run flag in additional parameters if available
    if [[ -n "${args[2]}" && "${args[2]}" == "--dry-run" ]]; then
        dry_run=1
    fi

    [[ -z "$project_path" ]] && log.hint "setup run <project-path> [--dry-run]" && return 1

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    CONF_FILE="$project_path/.dockero"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project not found: ${project_path}"
        return 1
    elif ! [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file not found in project path."
        log.hint "Use 'dockero setup init <project-path>' to create a new configuration"
        return 1
    fi

    # Parse .dockero configuration
    name=$(inipars.get "default" "name")
    image=$(inipars.get "default" "image")
    command=$(inipars.get "default" "command")
    env=$(inipars.get "volumes" "env")
    port=$(inipars.get "volumes" "port")
    restart_policy=$(inipars.get "default" "restart_policy")

    # Read user info (if present)
    user_name=$(inipars.get "user" "name")
    user_gid=$(inipars.get "user" "gid")

    if [[ "$image" != *:* ]]; then
        search_image="$image:latest"
    else
        search_image="$image"
    fi

    # Validate required fields
    if [[ -z "$name" || -z "$image" ]]; then
        log.error "Missing required fields in $CONF_FILE: 'name' or 'image'"
        return 1
    fi

    # Check if container name is available
    if [[ $dry_run -eq 0 ]]; then
        if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
            log.error "The container name "$name" is already in use"
            return 1
        fi
    fi

    log.setline "$name"

    if [[ $dry_run -eq 1 ]]; then
        log.info "DRY RUN MODE - Would launch container: $name"
        log.sub "Image: $image"
        log.sub "Command: $command"
        log.sub "Volume Mount: ${env:-$project_path:/workspace}"
        log.sub "Port Mapping: ${port:-80}"
        log.sub "Restart Policy: $restart_policy"
        log.sub "User: $user_name:$user_gid"
        log.info "DRY RUN MODE - No changes made"
        return 0
    fi

    # Pull image if not available locally
    if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$search_image$"; then
        if docker pull "$image" > "/tmp/$image.pull.log" 2>&1; then
            log.done "$image pulled successfully."
        else
            log.error "Failed to pull image: $image"
            log.sub "Check log: /tmp/$image.pull.log"
            return 1
        fi
    fi

    # Set defaults and run container
    volume_mount="${env:-$project_path:/workspace}"
    port_mapping="${port:-80}"

    log.info "Launching container: $name"
    docker_run "$user_name" "$user_gid"
}

setup_init() {
    local project_path="$1"
    [[ -z "$project_path" ]] && log.hint "setup init <project-path>" && return 1

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    CONF_FILE="$project_path/.dockero"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project path does not exist: ${project_path}"
        return 1
    fi

    if [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file already exists at: $CONF_FILE"
        log.info "Use 'dockero setup update <project-path>' to modify existing configuration"
        return 1
    fi

    log.setline "Setup Configuration Wizard"
    log.info "Creating new .dockero configuration for: $project_path"

    # Interactive setup
    echo -e "${YELLOW}Container Name${RESET_COLOR} [default: ${project_path##*/}]: \c"
    read -r container_name
    container_name=${container_name:-${project_path##*/}}

    echo -e "${YELLOW}Docker Image${RESET_COLOR} [default: ubuntu:latest]: \c"
    read -r docker_image
    docker_image=${docker_image:-ubuntu:latest}

    echo -e "${YELLOW}Port Mapping${RESET_COLOR} [format: host:container, default: 8080:80]: \c"
    read -r port_mapping
    port_mapping=${port_mapping:-8080:80}

    echo -e "${YELLOW}Volume Mount${RESET_COLOR} [format: host:container, default: $project_path:/workspace]: \c"
    read -r volume_mount
    volume_mount=${volume_mount:-$project_path:/workspace}

    echo -e "${YELLOW}Custom Command${RESET_COLOR} [optional, default: bash]: \c"
    read -r custom_command
    custom_command=${custom_command:-bash}

    echo -e "${YELLOW}Restart Policy${RESET_COLOR} [no,always,on-failure,unless-stopped, default: no]: \c"
    read -r restart_policy
    restart_policy=${restart_policy:-no}

    # Create the .dockero file
    cat > "$CONF_FILE" << EOF
[default]
name = $container_name
image = $docker_image
command = $custom_command
restart_policy = $restart_policy

[volumes]
env = $volume_mount
port = $port_mapping

[user]
name = root
EOF

    log.done "Configuration saved to: $CONF_FILE"
    log.info "Use 'dockero setup run $project_path' to start your container"
}

setup_update() {
    local project_path="$1"
    [[ -z "$project_path" ]] && log.hint "setup update <project-path>" && return 1

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    CONF_FILE="$project_path/.dockero"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project not found: ${project_path}"
        return 1
    elif ! [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file not found in project path."
        log.hint "Use 'dockero setup init <project-path>' to create a new configuration"
        return 1
    fi

    log.setline "Update Configuration"
    log.info "Updating .dockero configuration for: $project_path"

    # Read current values
    current_name=$(inipars.get "default" "name")
    current_image=$(inipars.get "default" "image")
    current_port=$(inipars.get "volumes" "port")
    current_env=$(inipars.get "volumes" "env")
    current_command=$(inipars.get "default" "command")
    current_restart=$(inipars.get "default" "restart_policy")

    # Interactive update
    echo -e "${YELLOW}Container Name${RESET_COLOR} [current: $current_name]: \c"
    read -r container_name
    container_name=${container_name:-$current_name}

    echo -e "${YELLOW}Docker Image${RESET_COLOR} [current: $current_image]: \c"
    read -r docker_image
    docker_image=${docker_image:-$current_image}

    echo -e "${YELLOW}Port Mapping${RESET_COLOR} [current: $current_port]: \c"
    read -r port_mapping
    port_mapping=${port_mapping:-$current_port}

    echo -e "${YELLOW}Volume Mount${RESET_COLOR} [current: $current_env]: \c"
    read -r volume_mount
    volume_mount=${volume_mount:-$current_env}

    echo -e "${YELLOW}Custom Command${RESET_COLOR} [current: $current_command]: \c"
    read -r custom_command
    custom_command=${custom_command:-$current_command}

    echo -e "${YELLOW}Restart Policy${RESET_COLOR} [current: $current_restart]: \c"
    read -r restart_policy
    restart_policy=${restart_policy:-$current_restart}

    # Update the .dockero file (need to pass the CONF_FILE explicitly)
    inipars.set "default" "name" "$container_name" "$CONF_FILE"
    inipars.set "default" "image" "$docker_image" "$CONF_FILE"
    inipars.set "volumes" "port" "$port_mapping" "$CONF_FILE"
    inipars.set "volumes" "env" "$volume_mount" "$CONF_FILE"
    inipars.set "default" "command" "$custom_command" "$CONF_FILE"
    inipars.set "default" "restart_policy" "$restart_policy" "$CONF_FILE"

    log.done "Configuration updated in: $CONF_FILE"
    log.hint "Use 'dockero setup run $project_path' to apply changes"
}

setup_teardown() {
    local project_path="$1"
    [[ -z "$project_path" ]] && log.hint "setup teardown <project-path>" && return 1

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    CONF_FILE="$project_path/.dockero"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project not found: ${project_path}"
        return 1
    elif ! [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file not found in project path."
        return 1
    fi

    # Parse .dockero configuration to get container name
    name=$(inipars.get "default" "name")

    if [[ -z "$name" ]]; then
        log.error "Container name not found in $CONF_FILE"
        return 1
    fi

    log.setline "Teardown"
    log.info "Stopping and removing container: $name"

    # Stop container if running
    if docker ps --format '{{.Names}}' | grep -q "^$name$"; then
        log.info "Stopping container: $name"
        if docker stop "$name" > /dev/null 2>&1; then
            log.done "Container stopped"
        else
            log.error "Failed to stop container: $name"
        fi
    else
        log.warn "Container $name was not running"
    fi

    # Remove container
    if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
        log.info "Removing container: $name"
        if docker rm "$name" > /dev/null 2>&1; then
            log.done "Container removed"
        else
            log.error "Failed to remove container: $name"
            return 1
        fi
    else
        log.warn "Container $name does not exist"
    fi

    log.info "Teardown completed for container: $name"
}

setup_run_with_dryrun() {
    local project_path="$1"

    [[ -z "$project_path" ]] && log.hint "setup run <project-path> --dry-run" && return 1

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    CONF_FILE="$project_path/.dockero"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project not found: ${project_path}"
        return 1
    elif ! [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file not found in project path."
        log.hint "Use 'dockero setup init <project-path>' to create a new configuration"
        return 1
    fi

    # Parse .dockero configuration
    name=$(inipars.get "default" "name")
    image=$(inipars.get "default" "image")
    command=$(inipars.get "default" "command")
    env=$(inipars.get "volumes" "env")
    port=$(inipars.get "volumes" "port")
    restart_policy=$(inipars.get "default" "restart_policy")

    # Read user info (if present)
    user_name=$(inipars.get "user" "name")
    user_gid=$(inipars.get "user" "gid")

    # Validate required fields
    if [[ -z "$name" || -z "$image" ]]; then
        log.error "Missing required fields in $CONF_FILE: 'name' or 'image'"
        return 1
    fi

    log.setline "$name"

    log.info "DRY RUN MODE - Would launch container: $name"
    log.sub "Image: $image"
    log.sub "Command: $command"
    log.sub "Volume Mount: ${env:-$project_path:/workspace}"
    log.sub "Port Mapping: ${port:-80}"
    log.sub "Restart Policy: $restart_policy"
    log.sub "User: $user_name:$user_gid"
    log.info "DRY RUN MODE - No changes made"
    return 0
}

docker_run() {
    local user_name="$1"
    local user_gid="$2"

    docker run -it \
    $( [ -e /dev/snd ] && echo "--device /dev/snd" ) \
    $( [ -n "$DISPLAY" ] && echo "-e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix" ) \
    $( [ -n "$WAYLAND_DISPLAY" ] && echo "-e WAYLAND_DISPLAY=$WAYLAND_DISPLAY -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/xdg/$WAYLAND_DISPLAY -e XDG_RUNTIME_DIR=/tmp/xdg" ) \
    $( [ -d /run/user/$(id -u)/pulse ] && echo "-v /run/user/$(id -u)/pulse:/run/user/$(id -u)/pulse -e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native" ) \
    $( command -v nvidia-smi >/dev/null 2>&1 && echo "--gpus all" ) \
    -v /run/user/$(id -u)/bus:/run/user/$(id -u)/bus \
    -v "$volume_mount" \
    -p "$port_mapping" \
    --name "${name}" \
    $( [[ -n "$restart_policy" ]] && echo "--restart $restart_policy" ) \
    $( [[ -n "$user_name" ]] && echo "--user $user_name:$user_gid" ) \
    "$image" ${command:+sh -c "$command"}
}