#!/usr/bin/env bash

remove_help() {
cat << EOF
${BOLD_CYAN}dockero remove ${GREEN}<container|image[:tag]>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Remove a container or image.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker rm -f <name>${RESET_COLOR} / ${YELLOW}docker rmi -f <image>:<tag>${RESET_COLOR}
EOF
}

remove() {
  local input="${args[1]:-}"

  if [[ -z "$input" ]]; then
    log.hint "Usage: ${BOLD_YELLOW}dockero remove <container|image>[:tag]${RESET_COLOR}"
    return 1
  fi

  # Parse target and tag
  local name
  local tag
  name="${input%%:*}"
  tag="${input#*:}"
  [[ "$input" == "$tag" ]] && tag="latest"

  local target_image="${name}:${tag}"

  # 1. Check for container first (if no colon or slash in input)
  if ! [[ "$input" =~ [:|/] ]] && ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$input$"; then
    if ! validate_container_name "$input"; then
      log.error "Invalid container name format: ${RED}$input${RESET_COLOR}."
      return 1
    fi
    log.setline "${BOLD_CYAN}Removing Container${RESET_COLOR}"
    log.info "Attempting to remove container: ${BOLD_YELLOW}$input${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} rm -f "$input" > /dev/null 2>&1; then
      log.done "Removed container ${BOLD_GREEN}$input${RESET_COLOR}."
      return 0
    else
      log.error "Failed to remove container ${RED}$input${RESET_COLOR}."
      return 1
    fi
  # 2. Check for image
  elif ${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$target_image$" || ${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}' | grep -q "^$input$"; then
    if ! validate_image_name "$target_image"; then
      log.error "Invalid image name format: ${RED}$target_image${RESET_COLOR}."
      return 1
    fi
    log.setline "${BOLD_CYAN}Removing Image${RESET_COLOR}"
    log.info "Attempting to remove image: ${BOLD_YELLOW}$target_image${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} rmi -f "$target_image" > /dev/null 2>&1; then
      log.done "Removed image ${BOLD_GREEN}$target_image${RESET_COLOR}."
      return 0
    else
      log.error "Failed to remove image ${RED}$target_image${RESET_COLOR}."
      return 1
    fi
  fi

  log.error "Target not found: ${RED}$input${RESET_COLOR}. Neither container nor image matches."
  return 1
}