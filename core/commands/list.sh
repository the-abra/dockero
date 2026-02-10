#!/usr/bin/env bash
list() {
  if [[ -n "${params[img]+set}" ]]; then
    docker images
  else
    printf "${BOLD_WHITE}%-20s %-30s %-25s %-15s %-20s${RESET_COLOR}\n" "NAME" "IMAGE" "STATUS" "PORTS" "IP"

    while IFS= read -r container_id; do
      local name
      local image
      local status
      local ports
      local ip_addresses
      name=$(docker inspect -f '{{.Name}}' "$container_id") # Removed cut -c2-
      image=$(docker inspect -f '{{.Config.Image}}' "$container_id")
      status=$(docker inspect -f '{{.State.Status}}' "$container_id")
      ports=$(docker port "$container_id" 2>/dev/null | tr '\n' ' ' | sed 's/^[ \t]*//') # Trim leading spaces
      ip_addresses=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}},{{end}}' "$container_id" | sed 's/,$//') # Join all IPs with comma

      printf "${GREEN}%-20s${RESET_COLOR} ${YELLOW}%-30s${RESET_COLOR} %-25s %-15s ${MAGENTA}%-20s${RESET_COLOR}\n" "$name" "$image" "$status" "$ports" "$ip_addresses"
    done < <(docker ps -aq)
  fi
}