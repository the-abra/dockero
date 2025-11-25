#!/usr/bin/env bash

env() {
    local subcommand="${args[1]}"
    
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "list" && "$subcommand" != "use" && "$subcommand" != "show" && "$subcommand" != "create" && "$subcommand" != "delete" && "$subcommand" != "switch" ]]; then
        log.hint "env <list|use|show|create|delete|switch> [environment-name]"
        return 1
    fi
    
    case "$subcommand" in
        "list")
            env_list
            ;;
        "use"|"switch")
            env_use "${args[2]}"
            ;;
        "show")
            env_show
            ;;
        "create")
            env_create "${args[2]}"
            ;;
        "delete")
            env_delete "${args[2]}"
            ;;
        *)
            log.error "Unknown env subcommand: $subcommand"
            return 1
            ;;
    esac
}

# Function to get current environment from config file
get_current_env() {
    local env_file=".dockero-env"
    if [[ -f "$env_file" ]]; then
        cat "$env_file" 2>/dev/null | head -n 1 | tr -d '\n'
    else
        echo "dev"  # default environment
    fi
}

# Function to set current environment
set_current_env() {
    local env_name="$1"
    local env_file=".dockero-env"
    echo "$env_name" > "$env_file"
}

env_list() {
    log.setline "Available Environments"
    
    # Look for all .dockero files with environment suffixes
    local envs=()
    envs+=("dev")  # Always include dev as default
    
    # Find environment-specific files
    for file in .dockero-*.yaml .dockero-* .dockero.compose-* .dockero-compose-*; do
        if [[ -f "$file" ]]; then
            # Extract environment name from file name
            local env_name=$(basename "$file" | sed 's/\.dockero[-\.]//' | sed 's/\.yaml$//' | sed 's/\.yml$//')
            if [[ -n "$env_name" && " ${envs[@]} " != *" $env_name "* ]]; then
                envs+=("$env_name")
            fi
        fi
    done
    
    # Also check for any .env files or environment markers
    for dir in .env.* .environment.*; do
        if [[ -d "$dir" || -f "$dir" ]]; then
            local env_name=$(basename "$dir" | cut -d'.' -f2)
            if [[ -n "$env_name" && " ${envs[@]} " != *" $env_name "* ]]; then
                envs+=("$env_name")
            fi
        fi
    done
    
    # Remove duplicates and show list
    local unique_envs
    mapfile -t unique_envs < <(printf '%s\n' "${envs[@]}" | sort -u)
    
    for env in "${unique_envs[@]}"; do
        if [[ "$env" == "$(get_current_env)" ]]; then
            echo "  ✅ $env (active)"
        else
            echo "  $env"
        fi
    done
    
    log.info "Use 'dockero env use <env>' to switch environments"
}

env_show() {
    local current_env=$(get_current_env)
    log.setline "Current Environment"
    log.info "Active environment: $current_env"
    
    # Show associated config files
    local config_files=()
    if [[ -f ".dockero-$current_env" ]]; then
        config_files+=(".dockero-$current_env")
    fi
    if [[ -f ".dockero-compose-$current_env" ]]; then
        config_files+=(".dockero-compose-$current_env")
    fi
    if [[ -f ".env.$current_env" ]]; then
        config_files+=(".env.$current_env")
    fi
    
    if [[ ${#config_files[@]} -gt 0 ]]; then
        log.sub "Associated configuration files:"
        for file in "${config_files[@]}"; do
            echo "  - $file"
        done
    else
        log.sub "No environment-specific configuration files found"
    fi
}

env_use() {
    local env_name="$1"
    
    if [[ -z "$env_name" ]]; then
        log.hint "env use <environment-name>"
        return 1
    fi
    
    # Validate that environment exists by checking for associated files
    local env_exists=0
    if [[ -f ".dockero-$env_name" ]] || [[ -f ".dockero-compose-$env_name" ]] || [[ -f ".env.$env_name" ]] || [[ "$env_name" == "dev" ]] || [[ "$env_name" == "staging" ]] || [[ "$env_name" == "prod" ]] || [[ "$env_name" == "production" ]]; then
        env_exists=1
    else
        # Check for any files that might contain this environment
        for file in .dockero-* .dockero-compose-* .env.* .environment.*; do
            if [[ -f "$file" ]]; then
                local check_env=$(basename "$file" | sed 's/\.dockero[-\.]//' | sed 's/\.env\.//' | sed 's/\.environment\.//' | sed 's/\.yaml$//' | sed 's/\.yml$//')
                if [[ "$check_env" == "$env_name" ]]; then
                    env_exists=1
                    break
                fi
            fi
        done
    fi
    
    if [[ $env_exists -eq 0 ]]; then
        log.warn "Environment '$env_name' files not found, but setting environment anyway"
    fi
    
    local prev_env=$(get_current_env)
    set_current_env "$env_name"
    
    log.setline "Environment Switch"
    log.done "Switched from '$prev_env' to '$env_name'"
    log.info "Environment set to: $env_name"
    
    # Show any differences or important notes about the new environment
    local compose_file=".dockero-compose-$env_name"
    if [[ -f "$compose_file" ]]; then
        log.sub "Using compose file: $compose_file"
    fi
    
    local dockero_file=".dockero-$env_name"
    if [[ -f "$dockero_file" ]]; then
        log.sub "Using config file: $dockero_file"
    fi
}

env_create() {
    local env_name="$1"
    
    if [[ -z "$env_name" ]]; then
        log.hint "env create <environment-name>"
        return 1
    fi
    
    # Check if environment already exists
    if [[ -f ".dockero-$env_name" ]] || [[ -f ".dockero-compose-$env_name" ]] || [[ -f ".env.$env_name" ]]; then
        log.warn "Environment '$env_name' configuration files already exist"
        return 1
    fi
    
    log.setline "Create Environment"
    log.info "Creating new environment: $env_name"
    
    # Create a template environment file
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
    
    log.done "Created environment configuration: $template_file"
    log.info "Edit $template_file to customize settings for $env_name environment"
    
    # Set as current environment if user wants to
    echo -e "${YELLOW}Make '$env_name' the current environment?${RESET_COLOR} [y/N]: \c"
    read -rp "Make '$env_name' the current environment? " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        set_current_env "$env_name"
        log.info "Environment set to: $env_name"
    fi
}

env_delete() {
    local env_name="$1"
    
    if [[ -z "$env_name" ]]; then
        log.hint "env delete <environment-name>"
        return 1
    fi
    
    # Check if trying to delete current environment
    if [[ "$env_name" == "$(get_current_env)" ]]; then
        log.warn "Cannot delete currently active environment '$env_name'"
        log.info "Please switch to a different environment first"
        return 1
    fi
    
    # Find and list files to be deleted
    local files_to_delete=()
    if [[ -f ".dockero-$env_name" ]]; then
        files_to_delete+=(".dockero-$env_name")
    fi
    if [[ -f ".dockero-compose-$env_name" ]]; then
        files_to_delete+=(".dockero-compose-$env_name")
    fi
    if [[ -f ".env.$env_name" ]]; then
        files_to_delete+=(".env.$env_name")
    fi
    
    if [[ ${#files_to_delete[@]} -eq 0 ]]; then
        log.warn "No configuration files found for environment: $env_name"
        return 1
    fi
    
    log.setline "Delete Environment"
    log.info "Files to be deleted for environment '$env_name':"
    for file in "${files_to_delete[@]}"; do
        echo "  - $file"
    done
    
    echo -e "${YELLOW}Confirm deletion?${RESET_COLOR} [y/N]: \c"
    read -rp "Confirm deletion? " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log.info "Deletion cancelled"
        return 0
    fi
    
    # Delete the files
    for file in "${files_to_delete[@]}"; do
        if rm "$file"; then
            log.sub "Deleted: $file"
        else
            log.error "Failed to delete: $file"
        fi
    done
    
    log.done "Environment '$env_name' deleted"
}