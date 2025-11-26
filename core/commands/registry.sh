#!/usr/bin/env bash

registry() {
  local subcommand="${args[1]}"
  
  case "$subcommand" in
    login|push|pull|list|ls|search|logout)
      shift 2  # Remove 'registry' and subcommand from args
      "registry_$subcommand" "$@"
      ;;
    "")
      log.error "Subcommand required. Use: dockero registry [login|push|pull|list|search|logout]"
      return 1
      ;;
    *)
      log.error "Unknown registry subcommand: $subcommand"
      log.hint "Use: dockero registry [login|push|pull|list|search|logout]"
      return 1
      ;;
  esac
}

registry_login() {
  local registry_url="${args[1]:-""}"
  local username="${params[user]:-""}"

  if [[ -z "$username" ]]; then
    read -rp "Username: " username
  fi

  if [[ -z "$registry_url" ]]; then
    if docker login; then
      log.done "Successfully logged in to registry"
    else
      log.error "Failed to login to registry"
      return 1
    fi
  else
    if docker login "$registry_url" -u "$username"; then
      log.done "Successfully logged in to registry"
    else
      log.error "Failed to login to registry"
      return 1
    fi
  fi
}

registry_push() {
  local image_name="${args[1]}"
  
  if [[ -z "$image_name" ]]; then
    log.error "Image name required"
    log.hint "Usage: dockero registry push <image-name[:tag]>"
    return 1
  fi
  
  log.info "Pushing image: $image_name"
  if docker push "$image_name"; then
    log.done "Successfully pushed image: $image_name"
  else
    log.error "Failed to push image: $image_name"
    return 1
  fi
}

registry_pull() {
  local image_name="${args[1]}"
  
  if [[ -z "$image_name" ]]; then
    log.error "Image name required"
    log.hint "Usage: dockero registry pull <image-name[:tag]>"
    return 1
  fi
  
  log.info "Pulling image: $image_name"
  if docker pull "$image_name"; then
    log.done "Successfully pulled image: $image_name"
  else
    log.error "Failed to pull image: $image_name"
    return 1
  fi
}

registry_list() {
  registry_ls "$@"
}

registry_ls() {
  local registry_url="${args[1]:-""}"
  
  log.info "Listing images in registry${registry_url:+ at $registry_url}"
  log.warn "Docker doesn't support listing remote registry images directly"
  log.sub "Consider using 'docker search' for public registries"
}

registry_search() {
  local term="${args[1]}"
  
  if [[ -z "$term" ]]; then
    log.error "Search term required"
    log.hint "Usage: dockero registry search <term>"
    return 1
  fi
  
  log.info "Searching for: $term"
  docker search "$term"
}

registry_logout() {
  local registry_url="${args[1]:-""}"
  
  if [[ -z "$registry_url" ]]; then
    if docker logout; then
      log.done "Successfully logged out"
    else
      log.error "Failed to logout"
      return 1
    fi
  else
    if docker logout "$registry_url"; then
      log.done "Successfully logged out"
    else
      log.error "Failed to logout"
      return 1
    fi
  fi
}