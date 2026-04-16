#!/usr/bin/env bash

# Helper function to extract environment name from file name

env_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero env ${GREEN}<list|use|show|create|delete|switch> [environment]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage deployment environments (dev, staging, prod).
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}list${RESET_COLOR}          List available environments.
     - ${GREEN}use <env>${RESET_COLOR}     Switch to an environment.
     - ${GREEN}show${RESET_COLOR}          Show current environment info.
     - ${GREEN}create <env>${RESET_COLOR}  Create a new environment.
     - ${GREEN}delete <env>${RESET_COLOR}  Remove an environment.
EOF
}


    local filename="$1"
    echo "$filename" | sed 's/^\.dockero[-.]//' | sed 's/^\.env\.//' | sed 's/^\.environment\.//' | sed 's/\.yaml$//' | sed 's/\.yml$//'
}

# Helper function to validate environment name for safe use in paths
_env_validate_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log.error "Invalid environment name: '${RED}$name${RESET_COLOR}'. Environment names can only contain alphanumeric characters, underscores, and hyphens."
        return 1
    fi
    return 0
}

env() {
    local subcommand="${args[1]:-}"
    
    if [[ -z "$subcommand" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero env <list|use|show|create|delete> [environment-name]${RESET_COLOR}"
        return 1
    fi
    
    case "$subcommand" in
        "list")
            env_list
            ;;
        "use"|"switch")
            env_use "${args[2]:-}"
            ;;
        "show")
            env_show
            ;;
        "create")
            env_create "${args[2]:-./}"
            ;;
        "delete")
            env_delete "${args[2]:-}"
            ;;
        *)
            log.error "Unknown env subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
            log.hint "Usage: ${BOLD_YELLOW}dockero env <list|use|show|create|delete> [environment-name]${RESET_COLOR}"
            return 1
            ;;
    esac
}

# Function to get current environment from config file
get_current_env() {
    local env_file=".dockero-env"
    local current_env_name="dev" # Default value

    if [[ -f "$env_file" ]]; then
        local file_content
        file_content=$(<"$env_file")
        if [[ -n "$file_content" ]]; then
            # Get the first line and sanitize it
            local raw_env
            raw_env=$(echo "$file_content" | head -n 1 | tr -d '\n')
            if _env_validate_name "$raw_env"; then # Validate content read from file
                current_env_name="$raw_env"
            else
                log.warn "Invalid environment name '${BOLD_YELLOW}$raw_env${RESET_COLOR}' found in ${BOLD_YELLOW}$env_file${RESET_COLOR}. Using default 'dev'."
            fi
        fi
    fi
    echo "$current_env_name"
}

# Function to set current environment
set_current_env() {
    local env_name="$1"
    local env_file=".dockero-env"
    echo "$env_name" > "$env_file" # Safe as env_name is validated before calling this
}

env_list() {
    log.setline "${BOLD_CYAN}🌍 Available Environments${RESET_COLOR}"
    
    local -a envs=()
    envs+=("dev")  # Always include dev as default
    
    shopt -s nullglob # Enable nullglob to prevent literal glob expansion
    
    # Find environment-specific files
    for file in .dockero-*.yaml .dockero-* .dockero.compose-* .dockero-compose-*; do
        if [[ -f "$file" ]]; then
            local env_name
            env_name=$(_env_extract_name "$(basename "$file")")
            if [[ -n "$env_name" ]] && _env_validate_name "$env_name" && ! [[ " ${envs[*]} " =~ $env_name ]]; then
                envs+=("$env_name")
            fi
        fi
    done
    
    # Also check for any .env files or environment markers
    for file in .env.* .environment.*; do
        if [[ -f "$file" || -d "$file" ]]; then
            local env_name
            env_name=$(_env_extract_name "$(basename "$file")")
            if [[ -n "$env_name" ]] && _env_validate_name "$env_name" && ! [[ " ${envs[*]} " =~ $env_name ]]; then
                envs+=("$env_name")
            fi
        fi
    done
    
    shopt -u nullglob # Disable nullglob

    # Remove duplicates and show list
    local -a unique_envs
    mapfile -t unique_envs < <(printf '%s\n' "${envs[@]}" | sort -u)
    
    local current_active_env
    current_active_env=$(get_current_env)

    for env_entry in "${unique_envs[@]}"; do
        if [[ "$env_entry" == "$current_active_env" ]]; then
            log.done "  ✅ ${BOLD}$env_entry${RESET_COLOR} (active)"
        else
            log.sub "  $env_entry"
        fi
    done
    
    log.info "Use '${BOLD_YELLOW}dockero env use <env>${RESET_COLOR}' to switch environments."
}

env_show() {
    local current_env
    current_env=$(get_current_env) || return 1 # get_current_env now validates
    log.setline "${BOLD_CYAN}🌍 Current Environment${RESET_COLOR}"
    log.info "Active environment: ${BOLD_GREEN}$current_env${RESET_COLOR}"
    
    # Show associated config files (paths are constructed using validated current_env)
    local -a config_files=()
    local compose_file=".dockero-compose-$current_env"
    local dockero_file=".dockero-$current_env"
    local env_vars_file=".env.$current_env"

    if [[ -f "$dockero_file" ]]; then
        config_files+=("$dockero_file")
    fi
    if [[ -f "$compose_file" ]]; then
        config_files+=("$compose_file")
    fi
    if [[ -f "$env_vars_file" ]]; then
        config_files+=("$env_vars_file")
    fi
    
    if [[ ${#config_files[@]} -gt 0 ]]; then
        log.sub "Associated configuration files:"
        for file in "${config_files[@]}"; do
            log.sub "- $file"
        done
    else
        log.sub "No environment-specific configuration files found."
    fi
}

env_use() {
    local env_name="$1"
    
    if [[ -z "$env_name" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero env use <environment-name>${RESET_COLOR}"
        return 1
    fi
    
    # Validate user-supplied env_name early
    if ! _env_validate_name "$env_name"; then return 1; fi

    # Validate that environment exists by checking for associated files
    local env_exists=0
    # Check for hardcoded common names first
    if [[ "$env_name" == "dev" || "$env_name" == "staging" || "$env_name" == "prod" || "$env_name" == "production" ]]; then
        env_exists=1
    else
        # Check for any files that might contain this environment
        shopt -s nullglob
        for file in .dockero-* .dockero-compose-* .env.* .environment.*; do
            if [[ -f "$file" || -d "$file" ]]; then
                local check_env
                check_env=$(_env_extract_name "$(basename "$file")")
                if [[ -n "$check_env" ]] && _env_validate_name "$check_env" && [[ "$check_env" == "$env_name" ]]; then
                    env_exists=1
                    break
                fi
            fi
        done
        shopt -u nullglob
    fi
    
    if [[ $env_exists -eq 0 ]]; then
        log.warn "Environment '${BOLD_YELLOW}$env_name${RESET_COLOR}' files not found, but setting environment anyway."
    fi
    
    local prev_env
    prev_env=$(get_current_env) || return 1 # get_current_env now validates
    set_current_env "$env_name"
    
    log.setline "Environment Switch"
    log.done "Switched from '${BOLD_YELLOW}$prev_env${RESET_COLOR}' to '${BOLD_GREEN}$env_name${RESET_COLOR}'."
    log.info "Environment set to: ${BOLD_GREEN}$env_name${RESET_COLOR}"
    
    # Show any differences or important notes about the new environment (paths are constructed using validated env_name)
    local compose_file=".dockero-compose-$env_name"
    local dockero_file=".dockero-$env_name"
    
    if [[ -f "$compose_file" ]]; then
        log.sub "Using compose file: ${YELLOW}$compose_file${RESET_COLOR}"
    fi
    
    if [[ -f "$dockero_file" ]]; then
        log.sub "Using config file: ${YELLOW}$dockero_file${RESET_COLOR}"
    fi
}

env_create() {
    local env_name="$1"
    
    if [[ -z "$env_name" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero env create <environment-name>${RESET_COLOR}"
        return 1
    fi
    
    # Validate user-supplied env_name early
    if ! _env_validate_name "$env_name"; then return 1; fi

    # Check if environment already exists (paths are constructed using validated env_name)
    if [[ -f ".dockero-$env_name" ]] || [[ -f ".dockero-compose-$env_name" ]] || [[ -f ".env.$env_name" ]]; then
        log.warn "Environment '${BOLD_YELLOW}$env_name${RESET_COLOR}' configuration files already exist."
        return 1
    fi
    
    log.setline "${BOLD_CYAN}✨ Create Environment${RESET_COLOR}"
    log.info "Creating new environment: ${BOLD_GREEN}$env_name${RESET_COLOR}."
    
    # Create a template environment file (path constructed using validated env_name)
    local template_file=".dockero-$env_name"
    cat > "$template_file" << EOF
# Environment configuration for $env_name
# This is a generated template for $env_name environment

[default]
# Override any settings from .dockero for this environment
# name = ${env_name}
# image = 

# Environment-specific overrides
[overrides]
# Add environment-specific settings here
# port = 
# volume = 
EOF
    
    log.done "Created environment configuration: ${YELLOW}$template_file${RESET_COLOR}."
    log.info "Edit ${YELLOW}$template_file${RESET_COLOR} to customize settings for ${BOLD_GREEN}$env_name${RESET_COLOR} environment."
    
    # Set as current environment if user wants to
    local response
    read -rp "${YELLOW}Make '$env_name' the current environment?${RESET_COLOR} [y/N]: " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        set_current_env "$env_name"
        log.info "Environment set to: ${BOLD_GREEN}$env_name${RESET_COLOR}."
    fi
}

env_delete() {
    local env_name="$1"
    
    if [[ -z "$env_name" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero env delete <environment-name>${RESET_COLOR}"
        return 1
    fi
    
    # Validate user-supplied env_name early
    if ! _env_validate_name "$env_name"; then return 1; fi

    # Check if trying to delete current environment (get_current_env now validates)
    local current_env
    current_env=$(get_current_env) || return 1
    if [[ "$env_name" == "$current_env" ]]; then
        log.warn "Cannot delete currently active environment '${BOLD_YELLOW}$env_name${RESET_COLOR}'."
        log.info "Please switch to a different environment first."
        return 1
    fi
    
    # Find and list files to be deleted (paths constructed using validated env_name)
    local -a files_to_delete=()
    local dockero_file=".dockero-$env_name"
    local compose_file=".dockero-compose-$env_name"
    local env_vars_file=".env.$env_name"

    if [[ -f "$dockero_file" ]]; then
        files_to_delete+=("$dockero_file")
    fi
    if [[ -f "$compose_file" ]]; then
        files_to_delete+=("$compose_file")
    fi
    if [[ -f "$env_vars_file" ]]; then
        files_to_delete+=("$env_vars_file")
    fi
    
    if [[ ${#files_to_delete[@]} -eq 0 ]]; then
        log.warn "No configuration files found for environment: '${BOLD_YELLOW}$env_name${RESET_COLOR}'."
        return 1
    fi
    
    log.setline "Delete Environment"
    log.info "Files to be deleted for environment '${BOLD_YELLOW}$env_name${RESET_COLOR}':"
    for file in "${files_to_delete[@]}"; do
        log.sub "- $file"
    done
    
    local response
    read -rp "${YELLOW}Confirm deletion?${RESET_COLOR} [y/N]: " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log.info "Deletion cancelled."
        return 0
    fi
    
    # Delete the files
    for file in "${files_to_delete[@]}"; do
        if rm "$file"; then
            log.sub "Deleted: ${YELLOW}$file${RESET_COLOR}"
        else
            log.error "Failed to delete: ${RED}$file${RESET_COLOR}"
        fi
    done
    
    log.done "Environment '${BOLD_GREEN}$env_name${RESET_COLOR}' deleted."
    return 0
}