#!/usr/bin/env bash

export_help() {
cat << EOF
${BOLD_CYAN}dockero export ${GREEN}<container-name> [--tag <image-tag>] [-o|--output <path.tar>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Export a container's state as a .tar archive.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<container-name>${RESET_COLOR}: Name of the container to export.
     - ${GREEN}--tag <image-tag>${RESET_COLOR}: Tag to assign to the committed image (default: latest).
     - ${GREEN}-o, --output <path>${RESET_COLOR}: Destination tar archive path (default: ./<container>.tar).
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker commit <name> <tag> && docker save -o <path>.tar <tag>${RESET_COLOR}
EOF
}

export() {
  if [[ -z "${args[1]:-}" ]]; then
    log.hint "Usage: ${BOLD_YELLOW}dockero export <container-name> [--tag <image-tag>] [-o <output-path>]${RESET_COLOR}"
    return 1
  fi

  local container_name="${args[1]:-}"
  local image_tag="${params[tag]:-latest}"
  local export_path="${params[o]:-${params[output]:-${PWD}/${container_name}.tar}}"

  if ! validate_container_name "$container_name"; then
    return 1
  fi

  if ! ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
    log.error "Container '${container_name}' does not exist. Aborting."
    return 1
  fi

  local commit_log
  commit_log=$(mktemp "/tmp/dockero_export_${container_name}_XXXXXX.log")
  trap 'rm -f "$commit_log"' EXIT

  log.setline "${BOLD_CYAN}📦 Exporting Container: ${GREEN}$container_name${RESET_COLOR}"

  local commit_image="${container_name}:${image_tag}"
  log.sub "Resolved image: $commit_image"
  log.sub "Export path: $export_path"

  # Commit the container
  log.info "Committing container state..."
  if ! ${DOCKERO_RUNTIME:-docker} commit "$container_name" "$commit_image" > "$commit_log" 2>&1; then
      log.error "Failed to commit container: $container_name"
      log.sub "Details: $(cat "$commit_log")"
      return 1
  fi

  # Export the image to tarball
  log.info "Saving image archive..."
  if ! ${DOCKERO_RUNTIME:-docker} save -o "$export_path" "$commit_image" >> "$commit_log" 2>&1; then
      log.error "Docker image export failed: $commit_image"
      log.sub "Details: $(cat "$commit_log")"
      return 1
  fi

  if [[ -f "$export_path" ]]; then
      local file_size
      file_size=$(du -h "$export_path" 2>/dev/null | awk '{print $1}')
      log.done "Image export successful: ${BOLD_GREEN}$export_path${RESET_COLOR} (${BOLD_YELLOW}${file_size:-0}${RESET_COLOR})"
  else
      log.error "Export verification failed. File not found: ${RED}$export_path${RESET_COLOR}"
      return 1
  fi

  return 0
}