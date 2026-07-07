#!/usr/bin/env bash

start_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero start ${GREEN}<container-name> [-c <command>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Start an existing stopped container.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}-c <command>${RESET_COLOR}: Execute a command inside the container after starting.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker start <name>${RESET_COLOR} / ${YELLOW}docker exec -it <name> <cmd>${RESET_COLOR}
EOF
}


start() {
  local container_name="${args[1]:-}"
  # shellcheck disable=SC2154
  local custom_command_flag="${params[c]+set}" # Check if -c flag is present
  local custom_command_args=("${args[@]:2}") # The command and its arguments
  # If no positional args after container name, use the -c flag value directly
  if [[ -n "$custom_command_flag" && ${#custom_command_args[@]} -eq 0 && -n "${params[c]:-}" ]]; then
    read -ra custom_command_args <<< "${params[c]}"
  fi

  # shellcheck disable=SC2154
  if [[ "${full_arr[1]}" =~ ^"-" ]]; then
    log.warn "You cannot set parameter flags before the container name."
    log.hint "Usage: ${BOLD_YELLOW}dockero start <container> [-c <command>]${RESET_COLOR}"
    return 1
  fi
  if [[ -z "$container_name" ]]; then
    log.hint "Usage: ${BOLD_YELLOW}dockero start <container> [-c <command>]${RESET_COLOR}"
    return 1
  fi

  # --- Input Validation ---
  if ! validate_container_name "$container_name"; then
    return 1
  fi

  log.setline "${BOLD_CYAN}🚀 Starting Container: ${GREEN}$container_name${RESET_COLOR}"

  # Check if container exists
  if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name is validated
    log.info "Attempting to start container: ${BOLD_YELLOW}$container_name${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} ps --format '{{.Names}}' | grep -q "^$container_name$"; then # $container_name is validated
        log.warn "Container '${BOLD_YELLOW}$container_name${RESET_COLOR}' is already running."
    else
        if ${DOCKERO_RUNTIME:-docker} start "$container_name" > /dev/null; then # $container_name is validated
            log.done "Container '${BOLD_GREEN}$container_name${RESET_COLOR}' started."
            # Give the container a moment to initialize if a command is to be executed
            if [[ -n "$custom_command_flag" ]]; then
                log.sub "Waiting for container to initialize..."
                sleep 2
            fi
        else
            log.error "Failed to start container: ${RED}$container_name${RESET_COLOR}."
            return 1
        fi
    fi

    # Execute custom command if -c flag is present and command arguments exist
    if [[ -n "$custom_command_flag" && ${#custom_command_args[@]} -gt 0 ]]; then
        log.info "Executing command in ${BOLD_YELLOW}$container_name${RESET_COLOR}: ${BOLD_GREEN}${custom_command_args[*]}${RESET_COLOR}"
        if ${DOCKERO_RUNTIME:-docker} exec -it "$container_name" "${custom_command_args[@]}"; then # $container_name is validated
            log.done "Command executed successfully in '${BOLD_GREEN}$container_name${RESET_COLOR}'."
        else
            log.error "Failed to execute command in '${RED}$container_name${RESET_COLOR}'."
            return 1
        fi
    fi
    return 0
  else
    log.error "Container ${RED}$container_name${RESET_COLOR} not found!"
    return 1
  fi
}