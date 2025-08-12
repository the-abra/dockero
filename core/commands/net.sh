#!/usr/bin/env bash

net() {
  local subcmd="${args[1]}"
  local name1="${args[2]}"
  local name2="${args[3]}"

  # Ensure no unexpected params
  [[ -z "${args[1]}" ]] && log.hint "net <command> [<args>]" && return 1
  [[ -n ${params[*]} ]] && log.warn "net command cannot accept additional parameters!" && return 1

  case "$subcmd" in
  new)
    [[ -z "$name1" ]] && log.hint "net new <network_name>" && return 1
    if docker network ls --format '{{.Name}}' | grep -q "^$name1$"; then
      log.warn "Network '$name1' already exists."
      return 1
    fi
    log.info "Creating network: $name1"
    docker network create "$name1" || return 1
    log.endline "$name1"
    ;;

  delete)
    [[ -z "$name1" ]] && log.hint "net delete <network_name>" && return 1
    log.info "Deleting network: $name1"
    docker network rm "$name1" || return 1
    log.endline "$name1"
    ;;

  add)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net add <container> <network>" && return 1
    log.info "Connecting container '$name1' to network '$name2'"
    docker network connect "$name2" "$name1" || return 1
    log.endline "$name1"
    ;;

  remove)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net remove <container> <network>" && return 1
    log.info "Disconnecting container '$name1' from network '$name2'"
    docker network disconnect "$name2" "$name1" || return 1
    log.endline "$name1"
    ;;

  rename)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net rename <network> <new_name>" && return 1
    if ! docker network inspect "$name1" &>/dev/null; then
      log.warn "Network '$name1' does not exist."
      return 1
    fi
    if docker network ls --format '{{.Name}}' | grep -q "^$name2$"; then
      log.warn "Target network name '$name2' already exists."
      return 1
    fi
    log.info "Renaming network '$name1' to '$name2'"
    docker network create "$name2" || return 1
    for container in $(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$name1"); do
      docker network connect "$name2" "$container"
    done
    docker network rm "$name1"
    log.endline "$name2"
    ;;

  list)
    log.info "Listing networks with connected containers"
    docker network ls --format '{{.Name}}' | while read -r netname; do
      containers=$(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$netname")
      printf "%-20s %s\n" "$netname" "$containers"
    done
    log.endline "networks"
    ;;

  *)
    log.hint "Usage: net <new|delete|add|remove|rename|list> ..."
    return 1
    ;;
  esac
}
