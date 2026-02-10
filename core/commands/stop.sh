#!/usr/bin/env bash

stop() {
  local container_name="${args[1]:-}"
  local timeout="${params[timeout]:-1}" # Default timeout to 1 second
  
  if [[ "${full_arr[1]}" =~ ^"-" ]]; then
    log.warn "You cannot set parameter flags before the container name."
    log.hint "Usage: ${BOLD_YELLOW}dockero stop <container> [--timeout <seconds>]${RESET_COLOR}"
    return 1
  fi
  if [[ -z "$container_name" ]]; then
    log.hint "Usage: ${BOLD_YELLOW}dockero stop <container> [--timeout <seconds>]${RESET_COLOR}"
    return 1
  fi

  # --- Input Validation ---
  if ! validate_container_name "$container_name"; then
    return 1
  fi

  # Validate timeout is a positive integer
  if [[ ! "$timeout" =~ ^[0-9]+$ || "$timeout" -le 0 ]]; then
    log.error "Invalid timeout value: '${RED}$timeout${RESET_COLOR}'. Must be a positive integer."
    return 1
  fi

  log.setline "${BOLD_CYAN}🛑 Stopping Container: ${RED}$container_name${RESET_COLOR}"

  # Improve container existence check for running containers
  if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
    log.info "Attempting to stop container '${BOLD_YELLOW}$container_name${RESET_COLOR}' with timeout: ${BOLD_YELLOW}$timeout${RESET_COLOR} seconds."
    
    # Use mktemp for secure temporary log file and add trap for cleanup
    local stop_log
    stop_log=$(mktemp "/tmp/dockero_stop_${container_name}_XXXXXX.log")
    trap "rm -f \"$stop_log\"" EXIT

    if docker stop --time="$timeout" "$container_name" > "$stop_log" 2>&1; then # $container_name is validated
        log.done "Container '${BOLD_GREEN}$container_name${RESET_COLOR}' stopped successfully."
    else
        log.error "Failed to stop container '${RED}$container_name${RESET_COLOR}'."
        log.sub "Details logged at: ${YELLOW}$stop_log${RESET_COLOR}"
        return 1
    fi
  else
    log.warn "Container '${BOLD_YELLOW}$container_name${RESET_COLOR}' is not running. Nothing to stop."
    # Check if it exists at all (stopped, exited) using validated name
    if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        log.sub "Container '${BOLD_YELLOW}$container_name${RESET_COLOR}' is in a non-running state."
    else
        log.error "Container '${RED}$container_name${RESET_COLOR}' not found."
        return 1
    fi
  fi
  log.endline "${BOLD_CYAN}🛑 Stopping Container: ${RED}$container_name${RESET_COLOR}"
  return 0
}