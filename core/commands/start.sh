start() {

  [[ "${full_arr[1]}" =~ ^"-" ]] && log.warn "You cannot set paramter before container!" && return 1
  [[ -z "${args[1]}" ]] && log.hint "start <container> [-c <command>]" && return 1

  local container_name=${args[1]}
  log.setline "$container_name"

  # Executing custom command
  if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
    docker start "$container_name"
    if [[ -n ${args[2]} && -n "${params[c]+set}" ]]; then
        docker exec -it "$container_name" "${full_arr[@]:3}"
    fi
    return 0
  else
    log.error "Container $container_name not found!"
    return 1
  fi
}
