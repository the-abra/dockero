setup() {
    [[ -z "${args[1]}" ]] && log.hint "setup <project-path>" && return 1

    local project_path="${args[1]}"
    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    CONF_FILE="$project_path/.dockero"

    if ! [[ -d "$project_path" ]]; then
        log.warn "Project not found: ${project_path}"
        return 1
    elif ! [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file not found in project path."
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
    if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
        log.error "The container name "$name" is already in use"
        return 1
    fi

    log.setline "$name"

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