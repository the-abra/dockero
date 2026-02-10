#!/usr/bin/env bash

# Helper function to validate network names for safe use
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
  [[ -z "${args[1]}" ]] && log.hint "net <command> [<args>]" && return 1
  if [[ -n "${params[*]}" ]]; then
      log.warn "The net command does not accept additional parameters."
      return 1
  fi

  case "$subcmd" in
  new)
    [[ -z "$name1" ]] && log.hint "net new <network_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate network name
    if docker network ls --format '{{.Name}}' | grep -q "^$name1$"; then
      log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' already exists."
      return 1
    fi
    echo -e "${BOLD_CYAN}✨ Creating network: ${GREEN}$name1${RESET_COLOR}"
    docker network create "$name1" || log.error "Failed to create network '${RED}$name1${RESET_COLOR}'." && return 1
    echo -e "${GREEN}Network '${BOLD_GREEN}$name1${RESET_COLOR}' created successfully.${RESET_COLOR}"
    ;;

  create) # Alias for 'new'
    net new "$name1"
    ;;

  delete)
    [[ -z "$name1" ]] && log.hint "net delete <network_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate network name
    echo -e "${BOLD_CYAN}🗑️  Deleting network: ${RED}$name1${RESET_COLOR}"
    if docker network inspect "$name1" &>/dev/null; then
        docker network rm "$name1" || log.error "Failed to delete network '${RED}$name1${RESET_COLOR}'." && return 1
        echo -e "${GREEN}Network '${BOLD_GREEN}$name1${RESET_COLOR}' deleted successfully.${RESET_COLOR}"
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
    if ! docker inspect --type container "$name1" &>/dev/null; then
      log.error "Container '${RED}$name1${RESET_COLOR}' does not exist."
      return 1
    fi

    # Check if container is running
    if [[ "$(docker inspect -f '{{.State.Running}}' "$name1")" != "true" ]]; then
      log.error "Container '${RED}$name1${RESET_COLOR}' is not running. Only running containers can be connected to a network."
      return 1
    fi

    # Check if network exists
    if ! docker network inspect "$name2" &>/dev/null; then
      log.error "Network '${RED}$name2${RESET_COLOR}' does not exist."
      return 1
    fi

    log.info "Connecting container '${BOLD_YELLOW}$name1${RESET_COLOR}' to network '${BOLD_YELLOW}$name2${RESET_COLOR}'"
    docker network connect "$name2" "$name1" || log.error "Failed to connect container '${RED}$name1${RESET_COLOR}' to network '${RED}$name2${RESET_COLOR}'." && return 1
    echo -e "${GREEN}Container '${BOLD_GREEN}$name1${RESET_COLOR}' connected to network '${BOLD_GREEN}$name2${RESET_COLOR}' successfully.${RESET_COLOR}"
    ;;

  connect) # Alias for 'add'
    net add "$name1" "$name2"
    ;;

  remove)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net remove <container> <network>" && return 1
    if ! validate_container_name "$name1"; then return 1; fi # Validate container name
    if ! _net_validate_name "$name2"; then return 1; fi # Validate network name

    echo -e "${BOLD_CYAN}❌ Disconnecting container '${RED}$name1${RESET_COLOR}' from network '${RED}$name2${RESET_COLOR}'"
    docker network disconnect "$name2" "$name1" || log.error "Failed to disconnect container '${RED}$name1${RESET_COLOR}' from network '${RED}$name2${RESET_COLOR}'." && return 1
    echo -e "${GREEN}Container '${BOLD_GREEN}$name1${RESET_COLOR}' disconnected from network '${BOLD_GREEN}$name2${RESET_COLOR}' successfully.${RESET_COLOR}"
    ;;

  disconnect) # Alias for 'remove'
    net remove "$name1" "$name2"
    ;;

  rename)
    [[ -z "$name1" || -z "$name2" ]] && log.hint "net rename <network> <new_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate old network name
    if ! _net_validate_name "$name2"; then return 1; fi # Validate new network name

    if ! docker network inspect "$name1" &>/dev/null; then
      log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' does not exist."
      return 1
    fi
    if docker network ls --format '{{.Name}}' | grep -q "^$name2$"; then
      log.warn "Target network name '${BOLD_YELLOW}$name2${RESET_COLOR}' already exists."
      return 1
    fi
    log.info "Renaming network '${BOLD_YELLOW}$name1${RESET_COLOR}' to '${BOLD_YELLOW}$name2${RESET_COLOR}'"
    docker network create "$name2" || log.error "Failed to create new network '${RED}$name2${RESET_COLOR}' for renaming." && return 1
    echo -e "${BOLD_CYAN}🔄 Reconnecting containers to new network '${GREEN}$name2${RESET_COLOR}'...${RESET_COLOR}"
    for container in $(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$name1"); do
      # Validate container name before use (from docker inspect output)
      if ! validate_container_name "$container"; then log.warn "Skipping invalid container name '${BOLD_YELLOW}$container${RESET_COLOR}' during rename."; continue; fi
      echo -e "  ${BOLD_CYAN}🔗 Connecting container: ${YELLOW}$container${RESET_COLOR}"
      docker network connect "$name2" "$container" || log.warn "Failed to connect container '${YELLOW}$container${RESET_COLOR}' to new network '${YELLOW}$name2${RESET_COLOR}'."
    done
    docker network rm "$name1" || log.error "Failed to remove old network '${RED}$name1${RESET_COLOR}'." && return 1
    echo -e "${GREEN}Network '${BOLD_GREEN}$name1${RESET_COLOR}' successfully renamed to '${BOLD_GREEN}$name2${RESET_COLOR}'.${RESET_COLOR}"
    ;;

  prune)
    echo -e "${BOLD_CYAN}🧹 Pruning unused networks...${RESET_COLOR}"
    docker network prune --force
    echo -e "${GREEN}Unused networks pruned successfully.${RESET_COLOR}"
    ;;

  inspect)
    [[ -z "$name1" ]] && log.hint "net inspect <network_name>" && return 1
    if ! _net_validate_name "$name1"; then return 1; fi # Validate network name
    if ! docker network inspect "$name1" &>/dev/null; then
      log.warn "Network '${BOLD_YELLOW}$name1${RESET_COLOR}' does not exist."
      return 1
    fi

    echo -e "${BOLD_CYAN}✨ Inspecting Network: ${GREEN}$name1${RESET_COLOR}\n"
    # Get network details in JSON format
    network_info=$(docker network inspect "$name1" --format '{{json .}}')

    # Extract network settings
    network_id=$(echo "$network_info" | jq -r '.Id')
    network_driver=$(echo "$network_info" | jq -r '.Driver')
    network_scope=$(echo "$network_info" | jq -r '.Scope')
    network_subnet=$(echo "$network_info" | jq -r '.IPAM.Config[0].Subnet')
    network_gateway=$(echo "$network_info" | jq -r '.IPAM.Config[0].IPAM.Config[0].Gateway') # Corrected path
    
    echo -e "  ${BOLD_CYAN}Network Details:${RESET_COLOR}"
    echo -e "    ${BOLD_WHITE}ID:${RESET_COLOR} ${GREEN}$network_id${RESET_COLOR}"
    echo -e "    ${BOLD_WHITE}Driver:${RESET_COLOR} ${GREEN}$network_driver${RESET_COLOR}"
    echo -e "    ${BOLD_WHITE}Scope:${RESET_COLOR} ${GREEN}$network_scope${RESET_COLOR}"
    echo -e "    ${BOLD_WHITE}Subnet:${RESET_COLOR} ${YELLOW}${network_subnet:-N/A}${RESET_COLOR}"
    echo -e "    ${BOLD_WHITE}Gateway:${RESET_COLOR} ${YELLOW}${network_gateway:-N/A}${RESET_COLOR}\n"

    echo -e "  ${BOLD_CYAN}Connected Containers:${RESET_COLOR}"
    # Extract connected containers and their IPs
    containers=$(echo "$network_info" | jq -r '.Containers | to_entries[] | .value.Name + " " + .value.IPv4Address')

    if [[ -z "$containers" ]]; then
      echo -e "    ${YELLOW}No containers connected.${RESET_COLOR}"
    else
      echo "$containers" | while IFS= read -r line; do
        local container_name
        container_name=$(echo "$line" | awk '{print $1}')
        local container_ip
        container_ip=$(echo "$line" | awk '{print $2}')
        # Validate container_name here if needed, but it comes from Docker inspect which is reliable
        echo -e "    - ${YELLOW}$container_name${RESET_COLOR} (${MAGENTA}$container_ip${RESET_COLOR})"
      done
    fi
    ;;

  list)
    echo -e "${BOLD_CYAN}🌐 Listing Networks with Connected Containers:${RESET_COLOR}\n"
    # Print header
    printf "${BOLD_WHITE}%-25s %s${RESET_COLOR}\n" "NETWORK NAME" "CONNECTED CONTAINERS"
    printf "${BOLD_WHITE}%-25s %s${RESET_COLOR}\n" "------------" "--------------------"

    docker network ls --format '{{.Name}}' | while read -r netname; do
      # Validate network name before using (from docker network ls output)
      if ! _net_validate_name "$netname"; then log.warn "Skipping invalid network name '${BOLD_YELLOW}$netname${RESET_COLOR}' during list."; continue; fi

      local containers_info
      containers_info=$(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$netname")
      local colored_containers=""
      if [[ -z "$containers_info" ]]; then
        colored_containers="${YELLOW}No containers connected.${RESET_COLOR}"
      else
        # Color each container name in the list
        for cname in $containers_info; do
          # Validate container name before use (from docker inspect output)
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