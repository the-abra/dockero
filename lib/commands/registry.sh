#!/usr/bin/env bash

registry_help() {
cat << EOF
${BOLD_CYAN}dockero registry ${GREEN}<login|push|pull|list|search|logout> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage Docker container registries.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}login [url] [-u <username>]${RESET_COLOR}  Authenticate to a registry.
     - ${GREEN}logout [url]${RESET_COLOR}                 Remove local credentials.
     - ${GREEN}push <image>${RESET_COLOR}                 Upload an image.
     - ${GREEN}pull <image>${RESET_COLOR}                 Download an image.
     - ${GREEN}search <term>${RESET_COLOR}                Search Docker Hub.
     - ${GREEN}list${RESET_COLOR}                         List images in registry.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker login/logout/push/pull/search${RESET_COLOR}
EOF
}

_registry_validate_url() {
    local url="$1"
    if [[ ! "$url" =~ ^[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
        log.error "Invalid registry URL: '${RED}$url${RESET_COLOR}'. Registry URLs should be hostname[:port]."
        return 1
    fi
    return 0
}

_registry_validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        log.error "Invalid username: '${RED}$username${RESET_COLOR}'. Usernames can only contain alphanumeric characters, underscores, hyphens, and dots."
        return 1
    fi
    return 0
}

registry() {
  local subcommand="${args[1]:-}"
  
  if [[ -z "$subcommand" ]]; then
    log.error "Subcommand required. Use: ${BOLD_YELLOW}dockero registry [login|push|pull|list|search|logout]${RESET_COLOR}"
    log.hint "Run ${BOLD_YELLOW}dockero registry -h${RESET_COLOR} for more information."
    return 1
  fi

  case "$subcommand" in
    login)
      registry_login "${args[@]:2}"
      ;;
    push)
      registry_push "${args[@]:2}"
      ;;
    pull)
      registry_pull "${args[@]:2}"
      ;;
    list|ls)
      registry_list "${args[@]:2}"
      ;;
    search)
      registry_search "${args[@]:2}"
      ;;
    logout)
      registry_logout "${args[@]:2}"
      ;;
    *)
      log.error "Unknown registry subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
      log.hint "Use: ${BOLD_YELLOW}dockero registry [login|push|pull|list|search|logout]${RESET_COLOR}"
      return 1
      ;;
  esac
}

registry_login() {
  local registry_url_arg="${1:-}"
  local username_arg="${params[u]:-${params[username]:-}}"

  # If positional argument starts with flag, ignore it as url
  [[ "$registry_url_arg" == -* ]] && registry_url_arg=""

  if [[ -n "$registry_url_arg" ]] && ! _registry_validate_url "$registry_url_arg"; then return 1; fi
  if [[ -n "$username_arg" ]] && ! _registry_validate_username "$username_arg"; then return 1; fi

  if [[ -z "$username_arg" ]]; then
    read -rp "${BOLD_WHITE}Enter username for registry: ${RESET_COLOR}" username_arg
    if [[ -z "$username_arg" ]]; then
      log.error "Username cannot be empty."
      return 1
    fi
    if ! _registry_validate_username "$username_arg"; then return 1; fi
  fi
  
  log.setline "${BOLD_CYAN}Registry Login${RESET_COLOR}"

  if [[ -z "$registry_url_arg" ]]; then
    log.info "Attempting to login to default registry as ${BOLD_YELLOW}$username_arg${RESET_COLOR}..."
    if ${DOCKERO_RUNTIME:-docker} login -u "$username_arg"; then
      log.done "Successfully logged in to default registry."
    else
      log.error "Failed to login to default registry."
      return 1
    fi
  else
    log.info "Attempting to login to ${BOLD_YELLOW}$registry_url_arg${RESET_COLOR} as ${BOLD_YELLOW}$username_arg${RESET_COLOR}..."
    if ${DOCKERO_RUNTIME:-docker} login "$registry_url_arg" -u "$username_arg"; then
      log.done "Successfully logged in to ${BOLD_GREEN}$registry_url_arg${RESET_COLOR}."
    else
      log.error "Failed to login to ${RED}$registry_url_arg${RESET_COLOR}."
      return 1
    fi
  fi
}

registry_push() {
  local image_name="${1:-}"
  
  if [[ -z "$image_name" ]]; then
    log.error "Image name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero registry push <image-name[:tag]>${RESET_COLOR}"
    return 1
  fi
  if ! validate_image_name "$image_name"; then return 1; fi
  
  log.setline "${BOLD_CYAN}⬆️ Pushing Image${RESET_COLOR}"
  log.info "Pushing image: ${BOLD_YELLOW}$image_name${RESET_COLOR}"
  if ${DOCKERO_RUNTIME:-docker} push "$image_name"; then
    log.done "Successfully pushed image: ${BOLD_GREEN}$image_name${RESET_COLOR}."
  else
    log.error "Failed to push image: ${RED}$image_name${RESET_COLOR}."
    return 1
  fi
}

registry_pull() {
  local image_name="${1:-}"
  
  if [[ -z "$image_name" ]]; then
    log.error "Image name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero registry pull <image-name[:tag]>${RESET_COLOR}"
    return 1
  fi
  if ! validate_image_name "$image_name"; then return 1; fi
  
  log.setline "${BOLD_CYAN}⬇️ Pulling Image${RESET_COLOR}"
  log.info "Pulling image: ${BOLD_YELLOW}$image_name${RESET_COLOR}"
  if ${DOCKERO_RUNTIME:-docker} pull "$image_name"; then
    log.done "Successfully pulled image: ${BOLD_GREEN}$image_name${RESET_COLOR}."
  else
    log.error "Failed to pull image: ${RED}$image_name${RESET_COLOR}."
    return 1
  fi
}

registry_list() {
  local registry_url="${1:-}"
  
  log.setline "${BOLD_CYAN}Registry List${RESET_COLOR}"
  log.info "Listing images in registry${registry_url:+ at ${BOLD_YELLOW}$registry_url${RESET_COLOR}}."
  log.warn "Docker doesn't support listing remote registry images directly."
  log.sub "Consider using '${BOLD_YELLOW}${DOCKERO_RUNTIME:-docker} search${RESET_COLOR}' for public registries."
}

registry_search() {
  local term="${1:-}"
  
  if [[ -z "$term" ]]; then
    log.error "Search term required."
    log.hint "Usage: ${BOLD_YELLOW}dockero registry search <term>${RESET_COLOR}"
    return 1
  fi
  
  log.setline "${BOLD_CYAN}🔎 Searching Registry${RESET_COLOR}"
  log.info "Searching for: ${BOLD_YELLOW}$term${RESET_COLOR}..."
  ${DOCKERO_RUNTIME:-docker} search "$term"
}

registry_logout() {
  local registry_url="${1:-}"
  
  log.setline "${BOLD_CYAN}🚪 Registry Logout${RESET_COLOR}"

  if [[ -z "$registry_url" ]]; then
    log.info "Attempting to logout from default registry..."
    if ${DOCKERO_RUNTIME:-docker} logout; then
      log.done "Successfully logged out from default registry."
    else
      log.error "Failed to logout from default registry."
      return 1
    fi
  else
    if ! _registry_validate_url "$registry_url"; then return 1; fi
    log.info "Attempting to logout from ${BOLD_YELLOW}$registry_url${RESET_COLOR}..."
    if ${DOCKERO_RUNTIME:-docker} logout "$registry_url"; then
      log.done "Successfully logged out from ${BOLD_GREEN}$registry_url${RESET_COLOR}."
    else
      log.error "Failed to logout from ${RED}$registry_url${RESET_COLOR}."
      return 1
    fi
  fi
}