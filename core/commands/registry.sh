#!/usr/bin/env bash

# Helper function to validate registry URLs for safe use
_registry_validate_url() {
    local url="$1"
    # Basic validation: alphanumeric, dots, hyphens, and optional port. No slashes or spaces.
    if [[ ! "$url" =~ ^[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
        log.error "Invalid registry URL: '${RED}$url${RESET_COLOR}'. Registry URLs should be hostname[:port]."
        return 1
    fi
    return 0
}

# Helper function to validate usernames for safe use
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
    list|ls) # 'ls' is an alias for 'list'
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
  local registry_url_arg="" # Argument for registry URL
  local username_arg=""     # Argument for username flag
  
  # Manually parse args for registry_url and username flag (u/username)
  local current_arg
  local i=0
  local current_cmd_args=("${args[@]}") # All original arguments passed to registry_login
  for current_arg in "${current_cmd_args[@]}"; do
    case "$current_arg" in
        -u|--username)
            # Next argument is the username
            if [[ -n "${current_cmd_args[$((i+1))]}" && ! "${current_cmd_args[$((i+1))]}" =~ ^- ]]; then
                username_arg="${current_cmd_args[$((i+1))]}"
                i=$((i+1)) # Consume the next argument
            else
                log.error "Missing value for ${BOLD_RED}$current_arg${RESET_COLOR}."
                log.hint "Usage: ${BOLD_YELLOW}dockero registry login [-u <username>] [<registry-url>]${RESET_COLOR}"
                return 1
            fi
            ;;
        -*) # Ignore other flags
            ;;
        *) # Positional argument (assumed to be registry URL)
            if [[ -z "$registry_url_arg" ]]; then # Only take the first positional arg as URL
                registry_url_arg="$current_arg"
            fi
            ;;
    esac
    i=$((i+1))
  done

  # Validate registry_url_arg if provided
  if [[ -n "$registry_url_arg" ]] && ! _registry_validate_url "$registry_url_arg"; then return 1; fi
  # Validate username_arg if provided
  if [[ -n "$username_arg" ]] && ! _registry_validate_username "$username_arg"; then return 1; fi

  # Prompt for username if not provided via flag
  if [[ -z "$username_arg" ]]; then
    read -rp "${BOLD_WHITE}Enter username for registry: ${RESET_COLOR}" username_arg
    if [[ -z "$username_arg" ]]; then
      log.error "Username cannot be empty."
      return 1
    fi
    if ! _registry_validate_username "$username_arg"; then return 1; fi # Validate prompted username
  fi
  
  log.setline "${BOLD_CYAN}🔑 Registry Login${RESET_COLOR}"

  if [[ -z "$registry_url_arg" ]]; then
    log.info "Attempting to login to default registry as ${BOLD_YELLOW}$username_arg${RESET_COLOR}..."
    if docker login -u "$username_arg"; then
      log.done "Successfully logged in to default registry."
    else
      log.error "Failed to login to default registry."
      return 1
    fi
  else
    log.info "Attempting to login to ${BOLD_YELLOW}$registry_url_arg${RESET_COLOR} as ${BOLD_YELLOW}$username_arg${RESET_COLOR}..."
    if docker login "$registry_url_arg" -u "$username_arg"; then
      log.done "Successfully logged in to ${BOLD_GREEN}$registry_url_arg${RESET_COLOR}."
    else
      log.error "Failed to login to ${RED}$registry_url_arg${RESET_COLOR}."
      return 1
    fi
  fi
}

registry_push() {
  local image_name="$1"
  
  if [[ -z "$image_name" ]]; then
    log.error "Image name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero registry push <image-name[:tag]>${RESET_COLOR}"
    return 1
  fi
  if ! validate_image_name "$image_name"; then return 1; fi # Validate image name
  
  log.setline "${BOLD_CYAN}⬆️ Pushing Image${RESET_COLOR}"
  log.info "Pushing image: ${BOLD_YELLOW}$image_name${RESET_COLOR}"
  if docker push "$image_name"; then
    log.done "Successfully pushed image: ${BOLD_GREEN}$image_name${RESET_COLOR}."
  else
    log.error "Failed to push image: ${RED}$image_name${RESET_COLOR}."
    return 1
  fi
}

registry_pull() {
  local image_name="$1"
  
  if [[ -z "$image_name" ]]; then
    log.error "Image name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero registry pull <image-name[:tag]>${RESET_COLOR}"
    return 1
  fi
  if ! validate_image_name "$image_name"; then return 1; fi # Validate image name
  
  log.setline "${BOLD_CYAN}⬇️ Pulling Image${RESET_COLOR}"
  log.info "Pulling image: ${BOLD_YELLOW}$image_name${RESET_COLOR}"
  if docker pull "$image_name"; then
    log.done "Successfully pulled image: ${BOLD_GREEN}$image_name${RESET_COLOR}."
  else
    log.error "Failed to pull image: ${RED}$image_name${RESET_COLOR}."
    return 1
  fi
}

registry_list() {
  local registry_url="$1" # Currently unused, as Docker doesn't support
  
  log.setline "${BOLD_CYAN}📦 Registry List${RESET_COLOR}"
  log.info "Listing images in registry${registry_url:+ at ${BOLD_YELLOW}$registry_url${RESET_COLOR}}."
  log.warn "Docker doesn't support listing remote registry images directly."
  log.sub "Consider using '${BOLD_YELLOW}docker search${RESET_COLOR}' for public registries."
}

registry_search() {
  local term="$1"
  
  if [[ -z "$term" ]]; then
    log.error "Search term required."
    log.hint "Usage: ${BOLD_YELLOW}dockero registry search <term>${RESET_COLOR}"
    return 1
  fi
  
  log.setline "${BOLD_CYAN}🔎 Searching Registry${RESET_COLOR}"
  log.info "Searching for: ${BOLD_YELLOW}$term${RESET_COLOR}..."
  docker search "$term"
}

registry_logout() {
  local registry_url="$1"
  
  log.setline "${BOLD_CYAN}🚪 Registry Logout${RESET_COLOR}"

  if [[ -z "$registry_url" ]]; then
    log.info "Attempting to logout from default registry..."
    if docker logout; then
      log.done "Successfully logged out from default registry."
    else
      log.error "Failed to logout from default registry."
      return 1
    fi
  else
    if ! _registry_validate_url "$registry_url"; then return 1; fi # Validate URL
    log.info "Attempting to logout from ${BOLD_YELLOW}$registry_url${RESET_COLOR}..."
    if docker logout "$registry_url"; then
      log.done "Successfully logged out from ${BOLD_GREEN}$registry_url${RESET_COLOR}."
    else
      log.error "Failed to logout from ${RED}$registry_url${RESET_COLOR}."
      return 1
    fi
  fi
}