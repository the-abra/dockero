stop() {
  [[ "${full_arr[1]}" =~ ^"-" ]] && log.warn "You cannot set paramter before container!" && return 1
  [[ -z "${args[1]}" ]] && log.hint "stop <container> [--timeout <second>]" && return 1

  if docker ps --filter "name=${args[1]}" --filter "status=running" --format '{{.Names}}' | grep -wq "${args[1]}"; then
    log.info "Shutdown after ${params[timeout]:-1} seconds."
    if docker stop --time=${params[timeout]:-1} ${args[1]} > /tmp/${args[1]}.stop.log; then
        log.done "Stopped: ${args[1]}"
    else
        log.error "${args[1]} stop process faild."
        log.sub "Log: /tmp/${args[1]}.stop.log"
    fi
  else
    log.error "Container ${args[1]} not running!"
    return 1
  fi
}