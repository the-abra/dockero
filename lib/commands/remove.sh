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
    log.hint "Usage: ${BOLD_YELLOW}dockero remove <container|image[:tag]|image_id>${RESET_COLOR}"
    return 1
  fi

  # 1. Check for container first
  if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$input$"; then
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
  fi

  # 2. Check for exact Image with tag (e.g. "node:22", "pgvector/pgvector:pg16", "redis:7-alpine")
  if ${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$input$"; then
    log.setline "${BOLD_CYAN}Removing Image${RESET_COLOR}"
    log.info "Attempting to remove image: ${BOLD_YELLOW}$input${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} rmi -f "$input" > /dev/null 2>&1; then
      log.done "Removed image ${BOLD_GREEN}$input${RESET_COLOR}."
      return 0
    else
      log.error "Failed to remove image ${RED}$input${RESET_COLOR}."
      return 1
    fi
  fi

  # 3. Check for Image by ID
  if ${DOCKERO_RUNTIME:-docker} images -q --no-trunc | grep -q "^${input}" || ${DOCKERO_RUNTIME:-docker} images -q | grep -q "^${input}$"; then
    log.setline "${BOLD_CYAN}Removing Image by ID${RESET_COLOR}"
    log.info "Attempting to remove image ID: ${BOLD_YELLOW}$input${RESET_COLOR}"
    if ${DOCKERO_RUNTIME:-docker} rmi -f "$input" > /dev/null 2>&1; then
      log.done "Removed image ${BOLD_GREEN}$input${RESET_COLOR}."
      return 0
    else
      log.error "Failed to remove image ${RED}$input${RESET_COLOR}."
      return 1
    fi
  fi

  # 4. Check for repository name without tag
  local matching_tags
  matching_tags=$(${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}:{{.Tag}}' | grep "^${input}:" || true)

  if [[ -n "$matching_tags" ]]; then
    # If latest tag exists, remove :latest
    if echo "$matching_tags" | grep -q "^${input}:latest$"; then
      local target_img="${input}:latest"
      log.setline "${BOLD_CYAN}Removing Image${RESET_COLOR}"
      log.info "Attempting to remove image: ${BOLD_YELLOW}$target_img${RESET_COLOR}"
      if ${DOCKERO_RUNTIME:-docker} rmi -f "$target_img" > /dev/null 2>&1; then
        log.done "Removed image ${BOLD_GREEN}$target_img${RESET_COLOR}."
        return 0
      fi
    fi

    # If only one tag exists (e.g. pgvector/pgvector:pg16), remove it directly
    local tag_count
    tag_count=$(echo "$matching_tags" | wc -l)
    if [[ "$tag_count" -eq 1 ]]; then
      local single_tag
      single_tag=$(echo "$matching_tags" | head -n 1)
      log.setline "${BOLD_CYAN}Removing Image${RESET_COLOR}"
      log.info "Attempting to remove image: ${BOLD_YELLOW}$single_tag${RESET_COLOR}"
      if ${DOCKERO_RUNTIME:-docker} rmi -f "$single_tag" > /dev/null 2>&1; then
        log.done "Removed image ${BOLD_GREEN}$single_tag${RESET_COLOR}."
        return 0
      fi
    else
      # Multiple tags found for repository, remove all of them
      log.setline "${BOLD_CYAN}Removing Image Repository${RESET_COLOR}"
      log.info "Removing all tags for image: ${BOLD_YELLOW}$input${RESET_COLOR}"
      local failed=0
      while IFS= read -r img; do
        [[ -z "$img" ]] && continue
        log.sub "Removing tag: ${BOLD_YELLOW}$img${RESET_COLOR}"
        if ! ${DOCKERO_RUNTIME:-docker} rmi -f "$img" > /dev/null 2>&1; then
          failed=1
        fi
      done <<< "$matching_tags"

      if [[ "$failed" -eq 0 ]]; then
        log.done "Removed all tags for ${BOLD_GREEN}$input${RESET_COLOR}."
        return 0
      else
        log.error "Some tags failed to remove for ${RED}$input${RESET_COLOR}."
        return 1
      fi
    fi
  fi

  log.error "Target not found: ${RED}$input${RESET_COLOR}. Neither container nor image matches."
  return 1
}