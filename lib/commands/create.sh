#!/usr/bin/env bash

create_help() {
cat << EOF
${BOLD_CYAN}dockero create / dockero run ${GREEN}<name> [<image>] [-d] [-p <port>] [-v <vol>] [-e <VAR=val>] [--env-file <file>] [--net <net>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Create and start a new container.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<name>${RESET_COLOR}: Container name.
     - ${GREEN}[<image>]${RESET_COLOR}: Docker image (defaults to <name>).
     - ${GREEN}-d, --detach${RESET_COLOR}: Run in background (detached).
     - ${GREEN}-p, --port <port>${RESET_COLOR}: Port mapping (e.g. 8080:80 or 3000).
     - ${GREEN}-v, --volume <host:container>${RESET_COLOR}: Volume mount (default: /opt/<name>:/workspace).
     - ${GREEN}--no-volume${RESET_COLOR}: Disable default volume mounting.
     - ${GREEN}-e, --env <VAR=val>${RESET_COLOR}: Set an environment variable.
     - ${GREEN}--env-file <file>${RESET_COLOR}: Read in a file of environment variables.
     - ${GREEN}--net, --network <net>${RESET_COLOR}: Network mode (bridge, host, or custom network).
     - ${GREEN}--restart <policy>${RESET_COLOR}: Restart policy (no, always, on-failure, unless-stopped).
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker run -it -v /opt/<name>:/workspace --name <name> <image>${RESET_COLOR}
EOF
}

run_help() {
  create_help
}

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
  elif [[ -n "${params[v]+set}" && "${params[v]}" != "true" ]]; then
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
  local network_mode="${params[net]:-${params[network]:-}}"
  local env_var="${params[e]:-${params[env]:-}}"
  local env_file="${params[env-file]:-}"

  if [[ -z "$container_name" ]]; then
    log.error "Container name is required."
    log.hint "Usage: dockero create <name> [<image>] [<command>] [-d] [-p <port>] [-v <vol>] [-e <VAR=val>]"
    return 1
  fi

  if ! validate_container_name "$container_name"; then return 1; fi
  if [[ ${args[2]+_} ]]; then
    if ! validate_image_name "$image_name"; then return 1; fi
  fi

  local search_image_name="$image_name"
  [[ "$image_name" != *:* ]] && search_image_name="$image_name:latest"

  log.setline "Dockero Create: $container_name"

  # If container already exists, warn and exit
  if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    log.warn "Container '${BOLD}$container_name${RESET_COLOR}' already exists."
    log.hint "Use '${BOLD_YELLOW}dockero start $container_name${RESET_COLOR}' to start it."
    log.endline "Dockero Create: $container_name"
    return 1
  fi

  # Pull image if not available locally
  if ! ${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${search_image_name}$"; then
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

  if ! docker_run "$container_name" "$image_name" "$detach_mode" "$command_args_str" "$volume_mount" "$port_mapping" "$restart_policy" "" "" "$network_mode" "$env_var" "$env_file"; then
    log.error "Failed to create container: ${BOLD}$container_name${RESET_COLOR}."
    log.endline "Dockero Create: $container_name"
    return 1
  fi

  log.done "Container '${BOLD}$container_name${RESET_COLOR}' created successfully."
  log.endline "Dockero Create: $container_name"
  return 0
}

run() {
  if [[ -z "${args[1]:-}" && -f "./.dockero" ]]; then
    setup_run "."
  else
    create "$@"
  fi
}
