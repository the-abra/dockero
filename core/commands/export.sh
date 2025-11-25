#!/usr/bin/env bash

export() {
# === INPUT VALIDATION ===
if [[ ! -n "${args[1]}" ]]; then
  log.hint "Usage: dockero export <container-name>"
  return 1
fi


# === PARAMETERS ===
local container_name
container_name="${args[1]}"

# Validate container name
if ! validate_container_name "$container_name"; then
  return 1
fi

# === PRE-CHECKS ===
if ! docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
  log.warn "Container '${container_name}' does not exists. Aborting."
  return 1
fi

#image_name="$(docker inspect --format='{{.Config.Image}}' $(docker ps -aqf "name=${container_name}") 2>/dev/null)"
local host_path
local build_name
host_path="/opt/${container_name}/"
build_name="${container_name}.tar"

# === LOGGING ===
echo "🔧 Container       : ${container_name}"
echo "📦 Image Name      : ${container_name}"
echo "📁 Virtual Path    : ${host_path}:/workspace"
echo "🏗️  Build Name      : ${build_name}"

# === BUILD EXECUTION ===

log.info "Initiating container export with major versioning scheme..."

local base_image
local commit_log
base_image="${container_name}"
commit_log="/tmp/export.${container_name}.log"


local commit_image
local export_path
commit_image="${base_image}:latest"
export_path="${HOME}/${container_name}.tar"

log.sub "Resolved image version: latest"

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
    log.done "Image export successful: $export_path"
else
    log.error "Export verification failed. File not found: $export_path"
    log.sub "Details logged at: $commit_log"
    return 1
fi

return 0
}