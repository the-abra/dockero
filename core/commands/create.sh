#!/usr/bin/env bash

create() {
  local container_name="${args[1]:-}"
  local image_name
  if [[ ${args[2]+_} ]]; then
    image_name="${args[2]}"
  else
    image_name="$container_name"
  fi
  local command_args_str="${args[*]:3}"

  local detach_mode=false
  if [[ -n "${params[d]+set}" || -n "${params[detach]+set}" ]]; then
    detach_mode=true
  fi

  # Volume: --volume or -v flag, or default /opt/<name>:/workspace
  local volume_mount=""
  if [[ -n "${params[volume]+set}" ]]; then
    volume_mount="${params[volume]}"
  elif [[ -n "${params[v]+set}" && "${params[v]}" == *:* ]]; then
    volume_mount="${params[v]}"
  else
    volume_mount="/opt/${container_name}:/workspace"
  fi

  # --no-volume flag disables default volume
  if [[ -n "${params[no-volume]+set}" ]]; then
    volume_mount=""
  fi

  local port_mapping="${params[p]:-${params[port]:-}}"
  local restart_policy="${params[restart]:-}"

  if [[ -z "$container_name" ]]; then
    log.error "Container name is required."
    log.hint "Usage: dockero create <name> [<image>] [<command>] [-d] [--volume <host:container>] [--no-volume] [-p <port>]"
    return 1
  fi

  if ! validate_container_name "$container_name"; then return 1; fi
  if [[ ${args[2]+_} ]]; then
    if ! validate_image_name "$image_name"; then return 1; fi
  fi

  local search_image_name="$image_name"
  [[ "$image_name" != *:* ]] && search_image_name="$image_name:latest"

  log.setline "🚀 Dockero Create: $container_name"

  # If container already exists, warn and exit
  if docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    log.warn "Container '${BOLD}$container_name${RESET_COLOR}' already exists."
    log.hint "Use '${BOLD_YELLOW}dockero start $container_name${RESET_COLOR}' to start it."
    log.endline "Dockero Create: $container_name"
    return 1
  fi

  # Pull image if not available locally
  if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${search_image_name}$"; then
    log.warn "Image '${BOLD}$image_name${RESET_COLOR}' not found locally. Pulling..."
    if ! image_pulling "$image_name"; then
      log.error "Failed to pull image: ${BOLD}$image_name${RESET_COLOR}."
      log.endline "Dockero Create: $container_name"
      return 1
    fi
  else
    log.info "Using local image: ${BOLD}$image_name${RESET_COLOR}."
  fi

  # Create host volume directory if using default volume
  if [[ -n "$volume_mount" ]]; then
    local host_path="${volume_mount%%:*}"
    if [[ ! -d "$host_path" ]]; then
      log.info "Creating host volume directory: ${BOLD}$host_path${RESET_COLOR}"
      mkdir -p "$host_path" 2>/dev/null || sudo mkdir -p "$host_path" 2>/dev/null || true
    fi
    log.info "Volume: ${BOLD}$volume_mount${RESET_COLOR}"
  fi

  if ! docker_run "$container_name" "$image_name" "$detach_mode" "$command_args_str" "$volume_mount" "$port_mapping" "$restart_policy" "" ""; then
    log.error "Failed to create container: ${BOLD}$container_name${RESET_COLOR}."
    log.endline "Dockero Create: $container_name"
    return 1
  fi

  log.done "Container '${BOLD}$container_name${RESET_COLOR}' created successfully."
  log.endline "Dockero Create: $container_name"
  return 0
}
