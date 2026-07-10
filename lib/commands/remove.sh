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
    log.hint "Usage: ${BOLD_YELLOW}remove <container|image>[:tag]${RESET_COLOR}"
    return 1
  fi

  # Parse target and tag
  local name
  local tag
  name="${input%%:*}"
  tag="${input#*:}"
  [[ "$input" == "$tag" ]] && tag="latest"

  local target_image="${name}:${tag}" # Corrected variable name for image target

  # --- Input Validation ---
  # Validate potential container name
  if ! validate_container_name "$name"; then
      log.error "Invalid container name format: ${RED}$name${RESET_COLOR}."
      return 1
  fi
  # Validate potential image name
  if ! validate_image_name "$target_image"; then
      log.error "Invalid image name format: ${RED}$target_image${RESET_COLOR}."
      return 1
  fi

  # Check for container first
  if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$name$" && ! [[ "$input" =~ ':' ]]; then
    log.setline "${BOLD_CYAN}Removing Container${RESET_COLOR}"
    log.info "Attempting to remove container: ${BOLD_YELLOW}$name${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} rm -f "$name" > /dev/null 2>&1; then # $name is now validated
      log.done "Removed container ${BOLD_GREEN}$name${RESET_COLOR}."
    else
      log.error "Failed to remove container ${RED}$name${RESET_COLOR}."
      return 1 # Indicate failure
    fi
    return
  # Check for image next
  elif ${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$target_image$"; then # Use target_image here
    log.setline "${BOLD_CYAN}Removing Image${RESET_COLOR}"
    log.info "Attempting to remove image: ${BOLD_YELLOW}$target_image${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} rmi -f "$target_image" > /dev/null 2>&1; then # $target_image is now validated
      log.done "Removed image ${BOLD_GREEN}$target_image${RESET_COLOR}."
    else
      log.error "Failed to remove image ${RED}$target_image${RESET_COLOR}."
      return 1 # Indicate failure
    fi
    return
  fi

  log.error "Target not found: ${RED}$input${RESET_COLOR}. Neither container nor image matches."
  return 1 # Indicate failure
}