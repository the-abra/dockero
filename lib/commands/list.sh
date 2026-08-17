#!/usr/bin/env bash

list_help() {
cat << EOF
${BOLD_CYAN}dockero list ${GREEN}[img]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} List all Docker containers or images.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}img${RESET_COLOR}: List images instead of containers.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker ps -a${RESET_COLOR} / ${YELLOW}docker images${RESET_COLOR}
EOF
}

list() {
  if [[ "${args[1]:-}" == "img" || "${args[1]:-}" == "images" || "${args[1]:-}" == "image" ]]; then
    ${DOCKERO_RUNTIME:-docker} images
  else
    log.setline "Container List"
    printf "%b\n" "${COLOR_SUB}${BOLD}NAME                 IMAGE                          STATUS                    PORTS           IP                  ${RESET_COLOR}"
    printf "%b\n" "${COLOR_SUB}-------------------- ------------------------------ ------------------------- --------------- --------------------${RESET_COLOR}"

    while IFS= read -r container_id; do
      local name
      local image
      local status
      local ports
      local ip_addresses
      name=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.Name}}' "$container_id" | cut -c2-)
      image=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.Config.Image}}' "$container_id")
      status=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{.State.Status}}' "$container_id")
      ports=$(${DOCKERO_RUNTIME:-docker} port "$container_id" 2>/dev/null | tr '\n' ' ' | sed 's/^[ \t]*//') # Trim leading spaces
      ip_addresses=$(${DOCKERO_RUNTIME:-docker} inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}},{{end}}' "$container_id" | sed 's/,$//') # Join all IPs with comma

      printf "${COLOR_DONE}%-20s${RESET_COLOR} ${COLOR_WARN}%-30s${RESET_COLOR} %-25s %-15s ${COLOR_HINT}%-20s${RESET_COLOR}\n" "$name" "$image" "$status" "$ports" "$ip_addresses"
    done < <(${DOCKERO_RUNTIME:-docker} ps -aq)
  fi
}