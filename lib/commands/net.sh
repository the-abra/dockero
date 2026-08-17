#!/usr/bin/env bash

# Helper function to validate network names for safe use

net_help() {
cat << EOF
${BOLD_CYAN}dockero net ${GREEN}<command> [args]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage Docker networks.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}new/create <name>${RESET_COLOR}                    Create a network.
     - ${GREEN}delete <name>${RESET_COLOR}                        Remove a network.
     - ${GREEN}add/connect <container> <network>${RESET_COLOR}    Connect container to network.
     - ${GREEN}remove/disconnect <container> <network>${RESET_COLOR} Disconnect container.
     - ${GREEN}rename <old> <new>${RESET_COLOR}                   Rename a network.
     - ${GREEN}prune${RESET_COLOR}                                Remove unused networks.
     - ${GREEN}list${RESET_COLOR}                                 List all networks.
     - ${GREEN}inspect <name>${RESET_COLOR}                       Show network details.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker network create/rm/connect/disconnect/prune/ls/inspect${RESET_COLOR}
EOF
}

_net_validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log.error "Invalid network name: '${RED}$name${RESET_COLOR}'. Network names can only contain alphanumeric characters, underscores, and hyphens."
        return 1
    fi
    return 0
}

net() {
  local subcmd="${args[1]:-}" # Safely get subcmd
  local name1="${args[2]:-}" # Safely get name1
  local name2="${args[3]:-}" # Safely get name2

  # Ensure no unexpected params
  [[ -z "${args[1]:-}" ]] && log.hint "net <command> [<args>]" && return 1
  if [[ -n "${params[*]}" ]]; then
      log.warn "The net command does not accept additional parameters."
      return 1
  fi

  case "$subcmd" in
  new)
    [[ -z "$name1" ]] && log.hint "net new <network_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate network name
    if ${DOCKERO_RUNTIME:-docker} network ls --format '{{.Name}}' | grep -q "^$name1$"; then
      log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' already exists."
      return 1
    fi
    log.info "✨ Creating network: ${BOLD}$name1${RESET_COLOR}"
    ${DOCKERO_RUNTIME:-docker} network create "$name1" || { log.error "Failed to create network '${RED}$name1${RESET_COLOR}'."; return 1; }
    log.done "Network '${BOLD}$name1${RESET_COLOR}' created successfully."
    ;;

  create) # Alias for 'new'
    net new "$name1"
    ;;

  delete)
    [[ -z "$name1" ]] && log.hint "net delete <network_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate network name
    log.info "Deleting network: ${BOLD}$name1${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} network inspect "$name1" &>/dev/null; then
        ${DOCKERO_RUNTIME:-docker} network rm "$name1" || { log.error "Failed to delete network '${RED}$name1${RESET_COLOR}'."; return 1; }
        log.done "Network '${BOLD}$name1${RESET_COLOR}' deleted successfully."
    else
        log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' does not exist. Nothing to delete."
        return 1
    fi
    ;;

  add)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net add <container> <network>" && return 1
    if ! validate_container_name "$name1"; then return 1; fi # Validate container name
    if ! _net_validate_name "$name2"; then return 1; fi # Validate network name

    # Check if container exists
    if ! ${DOCKERO_RUNTIME:-docker} inspect --type container "$name1" &>/dev/null; then
      log.error "Container '${RED}$name1${RESET_COLOR}' does not exist."
      return 1
    fi

    # Check if container is running
    if [[ "$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.State.Running}}' "$name1")" != "true" ]]; then
      log.error "Container '${RED}$name1${RESET_COLOR}' is not running. Only running containers can be connected to a network."
      return 1
    fi

    # Check if network exists
    if ! ${DOCKERO_RUNTIME:-docker} network inspect "$name2" &>/dev/null; then
      log.error "Network '${RED}$name2${RESET_COLOR}' does not exist."
      return 1
    fi

    # host network requires the container to be created with --network host; it cannot be connected post-creation
    if [[ "$name2" == "host" ]]; then
      log.error "Cannot connect a running container to the 'host' network. Use ${BOLD_YELLOW}dockero create --net host${RESET_COLOR} when creating the container."
      return 1
    fi

    log.info "Connecting container '${BOLD_YELLOW}$name1${RESET_COLOR}' to network '${BOLD_YELLOW}$name2${RESET_COLOR}'"
    if ! ${DOCKERO_RUNTIME:-docker} network connect "$name2" "$name1"; then
      log.error "Failed to connect container '${RED}$name1${RESET_COLOR}' to network '${RED}$name2${RESET_COLOR}'."
      return 1
    fi
    log.done "Container '${BOLD}$name1${RESET_COLOR}' connected to network '${BOLD}$name2${RESET_COLOR}' successfully."
    ;;

  connect) # Alias for 'add'
    net add "$name1" "$name2"
    ;;

  remove)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net remove <container> <network>" && return 1
    if ! validate_container_name "$name1"; then return 1; fi # Validate container name
    if ! _net_validate_name "$name2"; then return 1; fi # Validate network name

    log.info "❌ Disconnecting container '${BOLD}$name1${RESET_COLOR}' from network '${BOLD}$name2${RESET_COLOR}'"
    ${DOCKERO_RUNTIME:-docker} network disconnect "$name2" "$name1" || { log.error "Failed to disconnect container '${RED}$name1${RESET_COLOR}' from network '${RED}$name2${RESET_COLOR}'."; return 1; }
    log.done "Container '${BOLD}$name1${RESET_COLOR}' disconnected from network '${BOLD}$name2${RESET_COLOR}' successfully."
    ;;

  disconnect) # Alias for 'remove'
    net remove "$name1" "$name2"
    ;;

  rename)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net rename <network> <new_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate old network name
    if ! _net_validate_name "$name2"; then return 1; fi # Validate new network name

    if ! ${DOCKERO_RUNTIME:-docker} network inspect "$name1" &>/dev/null; then
      log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' does not exist."
      return 1
    fi
    if ${DOCKERO_RUNTIME:-docker} network ls --format '{{.Name}}' | grep -q "^$name2$"; then
      log.warn "Target network name '${BOLD_YELLOW}$name2${RESET_COLOR}' already exists."
      return 1
    fi
    log.info "Renaming network '${BOLD_YELLOW}$name1${RESET_COLOR}' to '${BOLD_YELLOW}$name2${RESET_COLOR}'"
    ${DOCKERO_RUNTIME:-docker} network create "$name2" || { log.error "Failed to create new network '${RED}$name2${RESET_COLOR}' for renaming."; return 1; }
    log.info "🔄 Reconnecting containers to new network '${BOLD}$name2${RESET_COLOR}'..."
    for container in $(${DOCKERO_RUNTIME:-docker} network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$name1"); do
      # Validate container name before use (from ${DOCKERO_RUNTIME:-docker} inspect output)
      if ! validate_container_name "$container"; then log.warn "Skipping invalid container name '${BOLD_YELLOW}$container${RESET_COLOR}' during rename."; continue; fi
      log.sub "🔗 Connecting container: ${BOLD}$container${RESET_COLOR}"
      ${DOCKERO_RUNTIME:-docker} network connect "$name2" "$container" || log.warn "Failed to connect container '${YELLOW}$container${RESET_COLOR}' to new network '${YELLOW}$name2${RESET_COLOR}'."
    done
    ${DOCKERO_RUNTIME:-docker} network rm "$name1" || { log.error "Failed to remove old network '${RED}$name1${RESET_COLOR}'."; return 1; }
    log.done "Network '${BOLD}$name1${RESET_COLOR}' successfully renamed to '${BOLD}$name2${RESET_COLOR}'."
    ;;

  prune)
    log.info "🧹 Pruning unused networks..."
    ${DOCKERO_RUNTIME:-docker} network prune --force
    log.done "Unused networks pruned successfully."
    ;;

  inspect)
    [[ -z "$name1" ]] && log.hint "net inspect <network_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate network name
    if ! ${DOCKERO_RUNTIME:-docker} network inspect "$name1" &>/dev/null; then
      log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' does not exist."
      return 1
    fi

    log.info "✨ Inspecting Network: ${BOLD}$name1${RESET_COLOR}"
    # Get network details in JSON format
    network_info=$(${DOCKERO_RUNTIME:-docker} network inspect "$name1" --format '{{json .}}')

    # Extract network settings
    network_id=$(echo "$network_info" | jq -r '.Id')
    network_driver=$(echo "$network_info" | jq -r '.Driver')
    network_scope=$(echo "$network_info" | jq -r '.Scope')
    network_subnet=$(echo "$network_info" | jq -r '.IPAM.Config[0].Subnet // empty')
    network_gateway=$(echo "$network_info" | jq -r '.IPAM.Config[0].Gateway // empty')
    
    log.info "Network Details:"
    log.sub "ID:      ${BOLD}$network_id${RESET_COLOR}"
    log.sub "Driver:  ${BOLD}$network_driver${RESET_COLOR}"
    log.sub "Scope:   ${BOLD}$network_scope${RESET_COLOR}"
    log.sub "Subnet:  ${network_subnet:-N/A}"
    log.sub "Gateway: ${network_gateway:-N/A}"

    log.info "Connected Containers:"
    # Extract connected containers and their IPs
    containers=$(echo "$network_info" | jq -r '.Containers | to_entries[] | .value.Name + " " + .value.IPv4Address')

    if [[ -z "$containers" ]]; then
      log.sub "No containers connected."
    else
      echo "$containers" | while IFS= read -r line; do
        local container_name
        container_name=$(echo "$line" | awk '{print $1}')
        local container_ip
        container_ip=$(echo "$line" | awk '{print $2}')
        # Validate container_name here if needed, but it comes from Docker inspect which is reliable
        log.sub "- ${BOLD}$container_name${RESET_COLOR} ($container_ip)"
      done
    fi
    ;;

  list)
    log.info "Listing Networks with Connected Containers:"
    # Print header
    printf "${BOLD_WHITE}%-25s %s${RESET_COLOR}\n" "NETWORK NAME" "CONNECTED CONTAINERS"
    printf "${BOLD_WHITE}%-25s %s${RESET_COLOR}\n" "------------" "--------------------"

    ${DOCKERO_RUNTIME:-docker} network ls --format '{{.Name}}' | while read -r netname; do
      # Validate network name before using (from ${DOCKERO_RUNTIME:-docker} network ls output)
      if ! _net_validate_name "$netname"; then log.warn "Skipping invalid network name '${BOLD_YELLOW}$netname${RESET_COLOR}' during list."; continue; fi

      local containers_info
      containers_info=$(${DOCKERO_RUNTIME:-docker} network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$netname")
      local colored_containers=""
      if [[ -z "$containers_info" ]]; then
        colored_containers="${YELLOW}No containers connected.${RESET_COLOR}"
      else
        # Color each container name in the list
        for cname in $containers_info; do
          # Validate container name before use (from ${DOCKERO_RUNTIME:-docker} inspect output)
          if ! validate_container_name "$cname"; then log.warn "Skipping invalid container name '${BOLD_YELLOW}$cname${RESET_COLOR}' for network '${BOLD_YELLOW}$netname${RESET_COLOR}'."; continue; fi
          colored_containers+=" ${YELLOW}$cname${RESET_COLOR}"
        done
        # Trim leading space
        colored_containers="${colored_containers#"${colored_containers%%[![:space:]]*}"}"
      fi
      printf "${GREEN}%-25s${RESET_COLOR} %s\n" "$netname" "$colored_containers"
    done
    ;;

  *)
    log.error "Unknown net subcommand: ${BOLD_RED}$subcmd${RESET_COLOR}"
    log.hint "Usage: ${BOLD_YELLOW}net <new|delete|add|remove|rename|list> ...${RESET_COLOR}"
    return 1
    ;;
  esac
}