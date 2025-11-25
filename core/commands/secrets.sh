#!/usr/bin/env bash

secrets() {
  local subcommand="${args[1]}"
  
  case "$subcommand" in
    create|ls|list|rm|remove|show|inspect)
      shift 2  # Remove 'secrets' and subcommand from args
      "secrets_$subcommand" "$@"
      ;;
    "")
      log.error "Subcommand required. Use: dockero secrets [create|list|remove|show]"
      return 1
      ;;
    *)
      log.error "Unknown secrets subcommand: $subcommand"
      log.hint "Use: dockero secrets [create|list|remove|show]"
      return 1
      ;;
  esac
}

secrets_create() {
  local secret_name="${args[1]}"
  local source="${args[2]:-""}"
  
  if [[ -z "$secret_name" ]]; then
    log.error "Secret name required"
    log.hint "Usage: dockero secrets create <name> [source]"
    return 1
  fi
  
  if [[ -z "$source" ]]; then
    log.info "Enter secret value (press Enter twice to finish):"
    local secret_value
    read -rs -p "Secret value: " secret_value
    echo  # New line after hidden input
    # Create secret from stdin
    if echo -n "$secret_value" | docker secret create "$secret_name" -; then
      log.done "Secret '$secret_name' created successfully"
    else
      log.error "Failed to create secret '$secret_name'"
      return 1
    fi
  else
    # Create secret from file or stdin
    if [[ -f "$source" ]]; then
      if docker secret create "$secret_name" "$source"; then
        log.done "Secret '$secret_name' created successfully"
      else
        log.error "Failed to create secret '$secret_name'"
        return 1
      fi
    else
      log.error "Source file does not exist: $source"
      return 1
    fi
  fi
}

secrets_list() {
  secrets_ls "$@"
}

secrets_ls() {
  log.info "Listing secrets..."
  docker secret ls
}

secrets_remove() {
  local secret_name="${args[1]}"
  
  if [[ -z "$secret_name" ]]; then
    log.error "Secret name required"
    log.hint "Usage: dockero secrets remove <name>"
    return 1
  fi
  
  log.warn "This will permanently remove the secret: $secret_name"
  read -rp "Are you sure? (y/N): " -n 1
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if docker secret rm "$secret_name"; then
      log.done "Secret '$secret_name' removed successfully"
    else
      log.error "Failed to remove secret '$secret_name'"
      return 1
    fi
  else
    log.info "Operation cancelled"
    return 0
  fi
}

secrets_show() {
  secrets_inspect "$@"
}

secrets_inspect() {
  local secret_name="${args[1]}"
  
  if [[ -z "$secret_name" ]]; then
    log.error "Secret name required"
    log.hint "Usage: dockero secrets show <name>"
    return 1
  fi
  
  log.info "Showing details for secret: $secret_name"
  docker secret inspect "$secret_name"
}