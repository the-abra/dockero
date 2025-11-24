#!/usr/bin/env bash

run() {

  [[ -z "${args[1]}" ]] && log.hint "run <name> [<image>]" && return 1
  [[ -n ${params[*]} ]] && log.warn "run command cannot accept parameters!" && return 1

  container_name=${args[1]}
  image_name=${args[2]:-"${args[1]}"}

  if [[ "$image_name" != *:* ]]; then
    search_name="$image_name:latest"
  else
    search_name="$image_name"
  fi

  # Check if container exists
  log.setline "$container_name"

  if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
    docker start -ai "$container_name"
    log.endline "$container_name"
    return 0
  elif docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$search_name$"; then
    log.sub "Creating new container from image: $image_name"
  else
    log.warn "Image and Container not found. Pulling: $image_name"
    image_clonning || exit 1
  fi
  docker_run
  log.endline "$container_name"
}

docker_run() {
  docker run -it \
    -v /opt/${container_name}:/workspace \
    -p 80 \
    --name "${container_name}" \
    $([ -e /dev/snd ] && echo "--device /dev/snd") \
    $([ -n "$DISPLAY" ] && echo "-e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix") \
    $([ -n "$WAYLAND_DISPLAY" ] && echo "-e WAYLAND_DISPLAY=$WAYLAND_DISPLAY -v $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/xdg/$WAYLAND_DISPLAY -e XDG_RUNTIME_DIR=/tmp/xdg") \
    $([ -d /run/user/$(id -u)/pulse ] && echo "-v /run/user/$(id -u)/pulse:/run/user/$(id -u)/pulse -e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native") \
    $(command -v nvidia-smi >/dev/null 2>&1 && echo "--gpus all") \
    -v /run/user/$(id -u)/bus:/run/user/$(id -u)/bus \
    "$image_name"
}

image_clonning() {
  if docker pull "$image_name" >"/tmp/$image_name.pull.log"; then
    log.done "$image_name installed."
    return 0
  else
    log.error "Pulling $image_name"
    log.sub "Log: /tmp/$image_name.pull.log"
    return 1
  fi
}
