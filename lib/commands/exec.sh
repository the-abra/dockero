#!/usr/bin/env bash

exec_help() {
cat << EOF
${BOLD_CYAN}dockero exec ${GREEN}<command> [args...] <container>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Execute a command in a running container.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<command>${RESET_COLOR}: Command to execute inside the container.
     - ${GREEN}[args...]${RESET_COLOR}: Optional arguments for the command.
     - ${GREEN}<container>${RESET_COLOR}: Name of the running container.
   ${BOLD_WHITE}• Examples:${RESET_COLOR}
     ${YELLOW}dockero exec sh mycontainer${RESET_COLOR}
     ${YELLOW}dockero exec ls -la /tmp mycontainer${RESET_COLOR}
     ${YELLOW}dockero exec echo hello world mycontainer${RESET_COLOR}
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker exec -it <container> <command> [args...]${RESET_COLOR}
EOF
}

exec() {
  if [[ $# -lt 2 ]]; then
    log.hint "Usage: ${BOLD_YELLOW}dockero exec <command> [args...] <container>${RESET_COLOR}"
    return 1
  fi

  local container_name="${!#}"
  local -a command_args=("${@:1:$#-1}")

  if ! validate_container_name "$container_name"; then
    return 1
  fi

  if ! ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
    log.error "Container ${RED}$container_name${RESET_COLOR} does not exist!" || true
    log.hint "Create it with: ${BOLD_YELLOW}dockero create $container_name <image>${RESET_COLOR}"
    return 1
  fi

  if ! ${DOCKERO_RUNTIME:-docker} ps --format '{{.Names}}' | grep -q "^$container_name$"; then
    log.error "Container ${RED}$container_name${RESET_COLOR} is not running!" || true
    log.hint "Start it with: ${BOLD_YELLOW}dockero start $container_name${RESET_COLOR}"
    return 1
  fi

  log.info "Executing ${BOLD_GREEN}${command_args[*]}${RESET_COLOR} in ${BOLD_YELLOW}$container_name${RESET_COLOR}"
  
  local exit_code=0
  if [[ -t 0 ]]; then
    ${DOCKERO_RUNTIME:-docker} exec -it "$container_name" "${command_args[@]}" || exit_code=$?
  else
    ${DOCKERO_RUNTIME:-docker} exec "$container_name" "${command_args[@]}" || exit_code=$?
  fi
  
  if [[ $exit_code -eq 0 ]]; then
    log.done "Command executed successfully."
  else
    log.error "Failed to execute command in ${RED}$container_name${RESET_COLOR}." || true
    log.hint "Verify the command exists: ${BOLD_YELLOW}dockero start $container_name -c ${command_args[*]}${RESET_COLOR}"
    return 1
  fi
}
