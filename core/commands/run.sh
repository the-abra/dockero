#!/usr/bin/env bash

run() {
  local container_name="${args[1]:-}"
  local image_name # Declare image_name here
  if [[ ${args[2]+_} ]]; then # Check if args[2] is set
    image_name="${args[2]}"
  else
    image_name="$container_name" # Use container name as image name if not provided
  fi
  local command_args_array=("${args[@]:3}") # Command and its arguments to run inside the container, as an array
  local command_args_str="${command_args_array[*]}" # Convert to string for docker_run helper

  # Check for detach flag
  local detach_mode=false
  if [[ -n "${params[d]+set}" || -n "${params[detach]+set}" ]]; then
      detach_mode=true
  fi

  # Validate argument count
  if [[ -z "$container_name" ]]; then
    log.error "Container name is required."
    log.hint "Usage: dockero run <name> [<image>] [<command>] [options]"
    log.hint "  -d, --detach: Run container in detached mode."
    return 1
  fi

  # Validate inputs
  if ! validate_container_name "$container_name"; then
    return 1
  fi

  # Validate image name only if explicitly provided
  if [[ ${args[2]+_} ]]; then
    if ! validate_image_name "$image_name"; then
      return 1
    fi
  fi

  local search_image_name="$image_name"
  if [[ "$image_name" != *:* ]]; then
    search_image_name="$image_name:latest"
  fi

  log.setline "🚀 Dockero Run: $container_name"

  # Check if container exists
  if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
    log.info "Container '${BOLD}$container_name${RESET_COLOR}' already exists."
    if docker ps -a --format '{{.Status}}' --filter "name=^$container_name$" | grep -q "Exited"; then
      log.info "Starting existing container: ${BOLD}$container_name${RESET_COLOR}"
      if [[ "$detach_mode" == "true" ]]; then
          docker start "$container_name" > /dev/null
          log.done "Container '${BOLD}$container_name${RESET_COLOR}' started in detached mode."
      else
          log.sub "Attaching to existing container: ${BOLD}$container_name${RESET_COLOR} (Press Ctrl+C to detach)"
          docker start -a "$container_name"
          log.done "Container '${BOLD}$container_name${RESET_COLOR}' stopped or detached."
      fi
    else
        log.info "Container '${BOLD}$container_name${RESET_COLOR}' is already running."
        if [[ "$detach_mode" != "true" ]]; then
            log.sub "Attaching to running container: ${BOLD}$container_name${RESET_COLOR} (Press Ctrl+C to detach)"
            docker attach "$container_name"
            log.done "Container '${BOLD}$container_name${RESET_COLOR}' detached."
        fi
    fi
    log.endline "Dockero Run: $container_name"
    return 0
  fi

  # Pull image if not available locally
  if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$search_image_name$"; then
    log.warn "Image '${BOLD}$image_name${RESET_COLOR}' not found locally. Pulling..."
    if ! image_pulling "$image_name"; then
      log.error "Failed to pull image: ${BOLD}$image_name${RESET_COLOR}."
      log.endline "Dockero Run: $container_name"
      return 1
    fi
  else
    log.info "Using local image: ${BOLD}$image_name${RESET_COLOR}."
  fi

  # Call the global docker_run helper function
  if ! docker_run "$container_name" "$image_name" "$detach_mode" "$command_args_str" "" "" "" "" ""; then # Pass empty strings for volume, port, restart, user
    log.error "Failed to run container: ${BOLD}$container_name${RESET_COLOR}."
    log.endline "Dockero Run: $container_name"
    return 1
  fi

  log.done "Container '${BOLD}$container_name${RESET_COLOR}' started successfully."
  log.endline "Dockero Run: $container_name"
  return 0
}