#!/usr/bin/env bash

export() {
# === INPUT VALIDATION ===
if [[ -z "${args[1]:-}" ]]; then
  log.hint "Usage: dockero export <container-name> [--tag <image-tag>]"
  return 1
fi

# === PARAMETERS ===
local container_name
container_name="${args[1]:-}"
local image_tag="${params[tag]:-latest}" # Allow specifying tag, default to latest

# Validate container name
if ! validate_container_name "$container_name"; then
  return 1
fi

# === PRE-CHECKS ===
if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
  log.error "Container '${container_name}' does not exist. Aborting."
  return 1
fi

local commit_log="/tmp/export.${container_name}.log"
# Clean up log file on exit
trap 'rm -f "$commit_log"' EXIT

log.info "Initiating container export."

local commit_image="${container_name}:${image_tag}"
local export_path="${HOME}/${container_name}.tar"

log.sub "Resolved image: $commit_image"
log.sub "Export path: $export_path"

# Commit the container
if ! docker commit "$container_name" "$commit_image" 2> "$commit_log"; then
    log.error "Failed to commit container: $container_name"
    log.sub "Details logged at: $commit_log"
    return 1
fi

log.info "Container committed successfully as: $commit_image"

# Export the image
if ! docker save -o "$export_path" "$commit_image" 2>> "$commit_log"; then
    log.error "Docker image export failed: $commit_image"
    log.sub "Details logged at: $commit_log"
    return 1
fi

# Validate the tarball
if [[ -f "$export_path" ]]; then
    log.done "Image export successful: ${BOLD_GREEN}$export_path${RESET_COLOR}"
else
    log.error "Export verification failed. File not found: ${RED}$export_path${RESET_COLOR}"
    log.sub "Details logged at: $commit_log"
    return 1
fi

return 0
}