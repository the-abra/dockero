#!/usr/bin/env bash

run() {
  # Validate argument count
  if [[ -z "${args[1]}" ]]; then
    log.error "Container name is required"
    log.hint "Usage: dockero run <name> [<image>]"
    return 1
  fi

  if [[ -n ${params[*]} ]]; then
    log.warn "run command may not accept all parameters. Check command documentation."
  fi

  container_name=${args[1]}
  image_name=${args[2]:-"${args[1]}"}

  # Validate inputs
  if ! validate_container_name "$container_name"; then
    return 1
  fi

  if ! validate_image_name "$image_name"; then
    return 1
  fi

  if [[ "$image_name" != *:* ]]; then
    search_name="$image_name:latest"
  else
    search_name="$image_name"
  fi

  # Check if container exists
  log.setline "$container_name"

  if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
    log.info "Starting existing container: $container_name"
    docker start -ai "$container_name"
    log.endline "$container_name"
    return 0
  elif docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$search_name$"; then
    log.info "Creating new container from existing image: $image_name"
  else
    log.warn "Image not found. Pulling: $image_name"
    if ! image_clonning; then
      log.error "Failed to pull image: $image_name"
      log.endline "$container_name"
      return 1
    fi
  fi

  if ! docker_run; then
    log.error "Failed to run container: $container_name"
    log.endline "$container_name"
    return 1
  fi

  log.endline "$container_name"
  return 0
}

docker_run() {
  # Use configuration for default port if available
  local port_mapping="${DOCKERO_DEFAULT_PORT:-80}"

  # Ensure proper port mapping format (host_port:container_port)
  if [[ "$port_mapping" =~ ^[0-9]+$ ]]; then
    # If it's just a number, map it to the same port in the container
    local port_arg="-p ${port_mapping}:${port_mapping}"
  else
    # If it's already in format like "8080:80", use as is
    local port_arg="-p ${port_mapping}"
  fi

  docker run -it \
    "${port_arg}" \
    -v /opt/"${container_name}":/workspace \
    --name "${container_name}" \
    $( [ -e /dev/snd ] && echo "--device /dev/snd" || true) \
    $( [ -n "$DISPLAY" ] && echo "-e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix" || true) \
    $( [ -n "$WAYLAND_DISPLAY" ] && echo "-e WAYLAND_DISPLAY=$WAYLAND_DISPLAY -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/xdg/$WAYLAND_DISPLAY -e XDG_RUNTIME_DIR=/tmp/xdg" || true) \
    $( [ -d /run/user/$(id -u)/pulse ] && echo "-v /run/user/$(id -u)/pulse:/run/user/$(id -u)/pulse -e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native" || true) \
    $(command -v nvidia-smi >/dev/null 2>&1 && echo "--gpus all" || true) \
    -v /run/user/"$(id -u)"/bus:/run/user/"$(id -u)"/bus \
    "$image_name"
}

image_clonning() {
  if docker pull "$image_name" >"/tmp/$image_name.pull.log" 2>&1; then
    log.done "$image_name installed."
    return 0
  else
    log.error "Failed to pull image: $image_name"
    log.sub "Check log: /tmp/$image_name.pull.log"
    return 1
  fi
}
