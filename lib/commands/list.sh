#!/usr/bin/env bash

list_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero list ${GREEN}[-img]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} List all Docker containers or images.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}-img${RESET_COLOR}: List images instead of containers.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker ps -a${RESET_COLOR} / ${YELLOW}docker images${RESET_COLOR}
EOF
}

list() {
  if [[ -n "${params[img]+set}" ]]; then
    ${DOCKERO_RUNTIME:-docker} images
  else
    log.setline "Container List"
    # Use color variables from log.sh for header, ensure alignment
    printf "${COLOR_SUB}${BOLD}%-20s %-30s %-25s %-15s %-20s${RESET_COLOR}\n" "NAME" "IMAGE" "STATUS" "PORTS" "IP"
    # shellcheck disable=SC2059
    printf "${COLOR_SUB}-------------------- ------------------------------ ------------------------- --------------- --------------------${RESET_COLOR}\n" # Separator

    while IFS= read -r container_id; do
      local name
      local image
      local status
      local ports
      local ip_addresses
      name=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.Name}}' "$container_id" | cut -c2-)
      image=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.Config.Image}}' "$container_id")
      status=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.State.Status}}' "$container_id")
      ports=$(docker port "$container_id" 2>/dev/null | tr '\n' ' ' | sed 's/^[ \t]*//') # Trim leading spaces
      ip_addresses=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}},{{end}}' "$container_id" | sed 's/,$//') # Join all IPs with comma

      printf "${COLOR_DONE}%-20s${RESET_COLOR} ${COLOR_WARN}%-30s${RESET_COLOR} %-25s %-15s ${COLOR_HINT}%-20s${RESET_COLOR}\n" "$name" "$image" "$status" "$ports" "$ip_addresses"
    done < <(${DOCKERO_RUNTIME:-docker} ps -aq)
  fi
}