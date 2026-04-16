#!/usr/bin/env bash

# Helper function to validate secret names for safe use

secrets_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero secrets ${GREEN}<create|list|show|remove> <name> [source]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage Docker secrets (passwords, API keys).
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}create <name> [source]${RESET_COLOR}  Create from file or stdin.
     - ${GREEN}list${RESET_COLOR}                    List all secrets.
     - ${GREEN}show <name>${RESET_COLOR}              Show secret metadata.
     - ${GREEN}remove <name>${RESET_COLOR}            Remove a secret.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker secret create/ls/inspect/rm${RESET_COLOR}
EOF
}


    local name="$1"
    # Docker secret names typically allow alphanumeric, hyphens, underscores, and dots.
    if [[ ! "$name" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        log.error "Invalid secret name: '${RED}$name${RESET_COLOR}'. Secret names can only contain alphanumeric characters, underscores, hyphens, and dots."
        return 1
    fi
    return 0
}

secrets() {
  local subcommand="${args[1]:-}"
  
  if [[ -z "$subcommand" ]]; then
    log.error "Subcommand required. Use: ${BOLD_YELLOW}dockero secrets [create|list|remove|show]${RESET_COLOR}"
    log.hint "Run ${BOLD_YELLOW}dockero secrets -h${RESET_COLOR} for more information."
    return 1
  fi

  case "$subcommand" in
    create)
      secrets_create "${args[@]:2}"
      ;;
    list|ls)
      secrets_list "${args[@]:2}"
      ;;
    rm|remove)
      secrets_remove "${args[@]:2}"
      ;;
    show|inspect)
      secrets_show "${args[@]:2}"
      ;;
    *)
      log.error "Unknown secrets subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
      log.hint "Use: ${BOLD_YELLOW}dockero secrets [create|list|remove|show]${RESET_COLOR}"
      return 1
      ;;
  esac
}

secrets_create() {
  local secret_name="$1"
  local source_path="${2:-}" # Renamed 'source' to 'source_path' to avoid conflicts
  
  if [[ -z "$secret_name" ]]; then
    log.error "Secret name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero secrets create <name> [source]${RESET_COLOR}"
    return 1
  fi
  # --- Input Validation ---
  if ! _secrets_validate_name "$secret_name"; then return 1; fi
  
  log.setline "${BOLD_CYAN}🔒 Creating Secret${RESET_COLOR}"

  if [[ -z "$source_path" ]]; then
    log.info "Enter secret value for '${BOLD_YELLOW}$secret_name${RESET_COLOR}' (press Enter twice to finish):"
    local secret_value
    read -rs -p "${BOLD_WHITE}Secret value:${RESET_COLOR} " secret_value
    echo  # New line after hidden input
    # Create secret from stdin
    if echo -n "$secret_value" | ${DOCKERO_RUNTIME:-docker} secret create "$secret_name" -; then
      log.done "Secret '${BOLD_GREEN}$secret_name${RESET_COLOR}' created successfully."
    else
      log.error "Failed to create secret '${RED}$secret_name${RESET_COLOR}'."
      return 1
    fi
  else
    # Create secret from file or stdin
    # --- Input Validation for source_path ---
    if [[ "$source_path" =~ \.\. ]]; then
        log.error "Invalid source path: '${RED}$source_path${RESET_COLOR}'. Path traversal sequences (..) are not allowed."
        return 1
    fi
    if [[ ! -f "$source_path" ]]; then
        log.error "Source file not found or is not a regular file: ${RED}$source_path${RESET_COLOR}."
        return 1
    fi

    log.info "Creating secret '${BOLD_YELLOW}$secret_name${RESET_COLOR}' from file: ${YELLOW}$source_path${RESET_COLOR}."
    if ${DOCKERO_RUNTIME:-docker} secret create "$secret_name" "$source_path"; then # $secret_name and $source_path are validated
      log.done "Secret '${BOLD_GREEN}$secret_name${RESET_COLOR}' created successfully."
    else
      log.error "Failed to create secret '${RED}$secret_name${RESET_COLOR}' from ${RED}$source_path${RESET_COLOR}."
      return 1
    fi
  fi
}

secrets_list() {
  log.setline "${BOLD_CYAN}🔑 Listing Secrets${RESET_COLOR}"
  log.info "Displaying all Docker secrets:"
  ${DOCKERO_RUNTIME:-docker} secret ls --format "table {{.ID}}\t{{.Name}}\t{{.CreatedAt}}\t{{.UpdatedAt}}" | sed '1s/.*/\033[1;36m&\033[0m/' # Color header
}

secrets_remove() {
  local secret_name="$1"
  
  if [[ -z "$secret_name" ]]; then
    log.error "Secret name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero secrets remove <name>${RESET_COLOR}"
    return 1
  fi
  # --- Input Validation ---
  if ! _secrets_validate_name "$secret_name"; then return 1; fi
  
  log.setline "${BOLD_CYAN}🗑️ Removing Secret${RESET_COLOR}"
  log.warn "This will permanently remove the secret: ${BOLD_YELLOW}$secret_name${RESET_COLOR}."
  local response
  read -rp "${YELLOW}Are you sure? (y/N): ${RESET_COLOR}" -n 1 response
  echo # New line after hidden input
  if [[ "$response" =~ ^[Yy]$ ]]; then
    log.info "Attempting to remove secret: ${BOLD_YELLOW}$secret_name${RESET_COLOR}."
    if ${DOCKERO_RUNTIME:-docker} secret rm "$secret_name"; then # $secret_name is validated
      log.done "Secret '${BOLD_GREEN}$secret_name${RESET_COLOR}' removed successfully."
    else
      log.error "Failed to remove secret '${RED}$secret_name${RESET_COLOR}'."
      return 1
    fi
  else
    log.info "Operation cancelled."
    return 0
  fi
}

secrets_show() {
  local secret_name="$1"
  
  if [[ -z "$secret_name" ]]; then
    log.error "Secret name required."
    log.hint "Usage: ${BOLD_YELLOW}dockero secrets show <name>${RESET_COLOR}"
    return 1
  fi
  # --- Input Validation ---
  if ! _secrets_validate_name "$secret_name"; then return 1; fi
  
  log.setline "${BOLD_CYAN}🔍 Secret Details for ${BOLD_GREEN}$secret_name${RESET_COLOR}"
  log.info "Showing details for secret: ${BOLD_YELLOW}$secret_name${RESET_COLOR}."
  # Check if jq is available for pretty printing
  if command -v jq &> /dev/null; then
    ${DOCKERO_RUNTIME:-docker} secret inspect "$secret_name" | jq .
  else
    log.warn "jq not found. Showing raw JSON output."
    ${DOCKERO_RUNTIME:-docker} secret inspect "$secret_name"
  fi
  return 0
}