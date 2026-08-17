#!/usr/bin/env bash

# Helper functions for Docker operations that are reusable across commands

# Function to pull a Docker image
image_pulling() { # Renamed from image_clonning for clarity
  local image_name="$1"
  log.info "Pulling image: ${BOLD_YELLOW}$image_name${RESET_COLOR}"
  
  # Use mktemp for secure temporary log file
  local tmp_log_file
  tmp_log_file=$(mktemp "/tmp/dockero_pull_XXXXXX.log")
  
  if ${DOCKERO_RUNTIME:-docker} pull "$image_name" >"$tmp_log_file" 2>&1; then
    log.done "Image '${BOLD_GREEN}$image_name${RESET_COLOR}' pulled successfully."
    rm "$tmp_log_file" # Clean up on success
    return 0
  else
    log.error "Failed to pull image: ${RED}$image_name${RESET_COLOR}."
    log.sub "Check log: ${YELLOW}$tmp_log_file${RESET_COLOR}"
    return 1
  fi
}

# Function to run a Docker container with various options
# Arguments: container_name, image_name, detach_mode, cmd_args_str, volume_mount, port_mapping, restart_policy, user_name, user_gid, network_mode, env_var, env_file
docker_run() {
  local container_name="$1"
  local image_name="$2"
  local detach_mode="$3"
  local cmd_args_str="$4"
  local volume_mount="$5"
  local port_mapping="$6"
  local restart_policy="$7"
  local user_name="$8"
  local user_gid="$9"
  local network_mode="${10:-}"
  local env_var="${11:-}"
  local env_file="${12:-}"

  local -a cmd_args=()
  if [[ -n "$cmd_args_str" ]]; then
      IFS=' ' read -r -a cmd_args <<< "$cmd_args_str"
  fi

  # --- Input Validation ---
  if [[ -n "$port_mapping" ]]; then
      # Trim whitespace first
      port_mapping="${port_mapping#"${port_mapping%%[![:space:]]*}"}"
      port_mapping="${port_mapping%"${port_mapping##*[![:space:]]}"}"
      if [[ ! "$port_mapping" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
          log.error "Invalid port mapping format: ${RED}$port_mapping${RESET_COLOR}. Expected format: host_port:container_port or container_port."
          return 1
      fi
  fi

  if [[ -n "$volume_mount" ]]; then
      # Trim whitespace first
      volume_mount="${volume_mount#"${volume_mount%%[![:space:]]*}"}"
      volume_mount="${volume_mount%"${volume_mount##*[![:space:]]}"}"
      if [[ ! "$volume_mount" =~ ^[^:]+:[^:]+$ ]]; then # Basic check for host:container format
          log.error "Invalid volume mount format: ${RED}$volume_mount${RESET_COLOR}. Expected format: host_path:container_path."
          return 1
      fi
  fi

  if [[ -n "$restart_policy" ]]; then
      if [[ ! "$restart_policy" =~ ^(no|always|on-failure|unless-stopped)$ ]]; then
          log.error "Invalid restart policy: ${RED}$restart_policy${RESET_COLOR}. Valid: no, always, on-failure, unless-stopped."
          return 1
      fi
  fi

  if [[ -n "$user_name" ]]; then
      if [[ ! "$user_name" =~ ^[a-zA-Z0-9_]+$ ]]; then
          log.error "Invalid username format: ${RED}$user_name${RESET_COLOR}. Only alphanumeric and underscore allowed."
          return 1
      fi
      if [[ -n "$user_gid" ]]; then
          if [[ ! "$user_gid" =~ ^[0-9]+$ ]]; then
              log.error "Invalid user GID format: ${RED}$user_gid${RESET_COLOR}. Only numbers allowed."
              return 1
          fi
      fi
  fi

  # Build docker arguments array
  local -a docker_args=()

  # Detached mode
  if [[ "$detach_mode" == "true" ]]; then
      docker_args+=(-d)
  else
      docker_args+=(-it) # Interactive and TTY by default if not detached
  fi

  # Port mapping
  if [[ -n "$port_mapping" ]]; then
      if [[ "$port_mapping" =~ ^[0-9]+$ ]]; then
        docker_args+=(-p "${port_mapping}:${port_mapping}")
      else
        docker_args+=(-p "${port_mapping}")
      fi
  fi

  # Volume mapping
  if [[ -n "$volume_mount" ]]; then
      docker_args+=(-v "$volume_mount")
  fi

  # Environment variables & files
  if [[ -n "$env_var" ]]; then
      docker_args+=(-e "$env_var")
  fi
  if [[ -n "$env_file" && -f "$env_file" ]]; then
      docker_args+=(--env-file "$env_file")
  fi

  # Always add container name
  docker_args+=(--name "$container_name")

  # Conditionally add sound device
  if [ -e /dev/snd ]; then
    docker_args+=(--device /dev/snd)
  fi

  # Conditionally add X11 display
  if [ -n "$DISPLAY" ]; then
    docker_args+=(-e "DISPLAY=$DISPLAY" -v "/tmp/.X11-unix:/tmp/.X11-unix")
  fi

  # Conditionally add Wayland display
  if [ -n "$WAYLAND_DISPLAY" ]; then
    docker_args+=(-e "WAYLAND_DISPLAY=$WAYLAND_DISPLAY" -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/tmp/xdg/$WAYLAND_DISPLAY" -e "XDG_RUNTIME_DIR=/tmp/xdg")
  fi

  # Conditionally add pulse audio
  if [ -d "/run/user/$(id -u)/pulse" ]; then
    docker_args+=(-v "/run/user/$(id -u)/pulse:/run/user/$(id -u)/pulse" -e "PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native")
  fi

  # Conditionally add NVIDIA GPU (only if enabled in config and nvidia-smi is available)
  if [[ "$DOCKERO_AUTO_GPU_ENABLED" == "true" ]] && command -v nvidia-smi >/dev/null 2>&1; then
    docker_args+=(--gpus all)
  fi

  # Always add bus access
  docker_args+=(-v "/run/user/$(id -u)/bus:/run/user/$(id -u)/bus")

  # Network mode
  if [[ -n "$network_mode" ]]; then
      docker_args+=(--network "$network_mode")
  fi

  # Add restart policy
  if [[ -n "$restart_policy" ]]; then
      docker_args+=(--restart "$restart_policy")
  fi

  # Conditionally add user
  if [[ -n "$user_name" ]]; then
      docker_args+=(--user "$user_name:$user_gid")
  fi

  log.sub "Executing: ${BOLD_GREEN}${DOCKERO_RUNTIME:-docker} run${RESET_COLOR} ${docker_args[*]} ${BOLD_YELLOW}$image_name${RESET_COLOR} ${cmd_args[*]}"

  # Execute ${DOCKERO_RUNTIME:-docker} run command
  ${DOCKERO_RUNTIME:-docker} run "${docker_args[@]}" "$image_name" "${cmd_args[@]}"
  
  # For interactive containers, check if container was actually created
  if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    return 0
  fi
  return 1
}