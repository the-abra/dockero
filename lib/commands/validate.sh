#!/usr/bin/env bash

# Helper function to validate file paths for safe use

validate_help() {
cat << EOF
${BOLD_CYAN}dockero validate ${GREEN}[path] [config-file]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Validate .dockero and .dockero-compose config files.
   ${BOLD_WHITE}• What it checks:${RESET_COLOR} INI structure, required fields, container names, images, ports, paths.
EOF
}

_validate_file_path_basic() {
    local path="${1:-}"
    if [[ -z "$path" ]]; then
        log.error "Path cannot be empty."
        return 1
    fi
    # Disallow path traversal sequences
    if [[ "$path" =~ \.\. ]]; then
        log.error "Invalid path: '${RED}$path${RESET_COLOR}'. Path traversal sequences (..) are not allowed."
        return 1
    fi
    return 0
}

validate() {
    local target="${args[1]:-.}" # Default to current directory
    local config_file_arg="${args[2]:-}"

    if ! _validate_file_path_basic "$target"; then return 1; fi
    if [[ -n "$config_file_arg" ]] && ! _validate_file_path_basic "$config_file_arg"; then return 1; fi
    
    log.setline "${BOLD_CYAN}✅ Configuration Validation${RESET_COLOR}"
    
    # If specific config file is provided
    if [[ -n "$config_file_arg" ]]; then
        local full_config_path=""
        
        if [[ "$config_file_arg" == /* ]]; then
            if [[ -f "$config_file_arg" ]]; then
                full_config_path="$config_file_arg"
            fi
        elif [[ -f "$target/$config_file_arg" ]]; then
            full_config_path="$target/$config_file_arg"
        elif [[ -f "$config_file_arg" ]]; then
            full_config_path="$config_file_arg"
        fi

        if [[ -n "$full_config_path" ]]; then
            if ! validate_single_config "$full_config_path"; then return 1; fi
        else
            log.error "Configuration file '${RED}$config_file_arg${RESET_COLOR}' not found in '${YELLOW}$target${RESET_COLOR}' or current directory."
            return 1
        fi
    else
        # Validate all .dockero files in the target path
        local -a config_files=()
        while IFS= read -r -d '' file; do
            config_files+=("$file")
        done < <(find "$target" -name ".dockero*" -type f -print0 2>/dev/null)
        
        local success_count=0
        local failed_count=0
        
        if [[ ${#config_files[@]} -eq 0 ]]; then
            log.warn "No .dockero configuration files found in '${BOLD_YELLOW}$target${RESET_COLOR}'."
            return 0
        fi

        for file in "${config_files[@]}"; do
            log.info "Validating: ${YELLOW}$file${RESET_COLOR}"
            if validate_single_config "$file"; then
                ((success_count++)) || true
            else
                ((failed_count++)) || true
            fi
            echo
        done
        
        if [[ "$failed_count" -eq 0 ]]; then
            log.done "Validation completed: ${BOLD_GREEN}$success_count${RESET_COLOR} files passed."
            return 0
        else
            log.warn "Validation completed: ${BOLD_GREEN}$success_count${RESET_COLOR} passed, ${BOLD_RED}$failed_count${RESET_COLOR} failed."
            return 1
        fi
    fi
    return 0
}

validate_single_config() {
    local config_file="${1:-}"
    local file_type=""
    
    if ! _validate_file_path_basic "$config_file"; then return 1; fi

    # Determine file type based on name
    if [[ "$config_file" == *".dockero-compose"* ]]; then
        file_type="compose"
    elif [[ "$config_file" == *".dockero"* ]]; then
        file_type="dockero"
    else
        log.error "Unknown configuration file type: ${RED}$config_file${RESET_COLOR}. Expecting '.dockero' or '.dockero-compose'."
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log.error "File does not exist: ${RED}$config_file${RESET_COLOR}."
        return 1
    fi
    
    log.sub "File: ${BOLD_YELLOW}$config_file${RESET_COLOR}"
    
    if [[ ! -r "$config_file" ]]; then
        log.error "File is not readable: ${RED}$config_file${RESET_COLOR}. Check permissions."
        return 1
    fi
    
    if [[ ! -s "$config_file" ]]; then
        log.error "File is empty: ${RED}$config_file${RESET_COLOR}."
        return 1
    fi
    
    # Validate INI structure
    if ! validate_ini_structure "$config_file"; then
        log.error "Invalid INI structure in: ${RED}$config_file${RESET_COLOR}."
        return 1
    fi
    
    local validation_passed=1
    case "$file_type" in
        "dockero")
            if validate_dockero_config "$config_file"; then
                log.sub "✅ .dockero format validation passed."
            else
                validation_passed=0
            fi
            ;;
        "compose")
            if validate_compose_config "$config_file"; then
                log.sub "✅ .dockero-compose format validation passed."
            else
                validation_passed=0
            fi
            ;;
    esac
    
    # Validate file access patterns are safe
    if ! validate_safe_paths "$config_file"; then
        log.error "Configuration contains unsafe paths: ${RED}$config_file${RESET_COLOR}."
        return 1
    fi
    
    if [[ "$validation_passed" -eq 1 ]]; then
        log.done "✓ Configuration validation passed for: ${BOLD_GREEN}$config_file${RESET_COLOR}"
        return 0
    else
        log.warn "✗ Configuration validation failed for: ${BOLD_YELLOW}$config_file${RESET_COLOR}"
        return 1
    fi
}

validate_ini_structure() {
    local config_file="${1:-}"
    local sections=0
    local errors_found=0
    
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            ((sections++)) || true
        elif [[ "$line" != *"="* ]]; then
            log.warn "Potentially invalid line (no '='): ${BOLD_YELLOW}$line${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}"
            ((errors_found++)) || true
        fi
    done < "$config_file"
    
    if [[ "$sections" -eq 0 ]]; then
        log.error "No sections found in INI file: ${RED}$config_file${RESET_COLOR}."
        return 1
    fi
    
    return $((errors_found > 0 ? 1 : 0))
}

validate_dockero_config() {
    local config_file="${1:-}"
    local errors=0
    
    local name
    name=$(inipars.get "default" "name" "$config_file")
    local image
    image=$(inipars.get "default" "image" "$config_file")
    
    if [[ -z "$name" ]]; then
        log.error "Missing required field: ${RED}name${RESET_COLOR} (in [default] section of ${BOLD_YELLOW}$config_file${RESET_COLOR})."
        ((errors++)) || true
    else
        if ! validate_container_name "$name"; then
            log.error "Invalid container name format: ${RED}$name${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
            ((errors++)) || true
        fi
    fi
    
    if [[ -z "$image" ]]; then
        log.error "Missing required field: ${RED}image${RESET_COLOR} (in [default] section of ${BOLD_YELLOW}$config_file${RESET_COLOR})."
        ((errors++)) || true
    else
        if ! validate_image_name "$image"; then
            log.warn "Image name might be invalid: ${BOLD_YELLOW}$image${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
        fi
    fi
    
    local port
    port=$(inipars.get "volumes" "port" "$config_file")
    if [[ -n "$port" ]]; then
        if [[ ! "$port" =~ ^[0-9]+:[0-9]+$ ]]; then
            log.warn "Port mapping might be invalid: ${BOLD_YELLOW}$port${RESET_COLOR} (expected format: host:container) in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
        fi
    fi
    
    local restart_policy
    restart_policy=$(inipars.get "default" "restart_policy" "$config_file")
    if [[ -n "$restart_policy" ]]; then
        if [[ ! "$restart_policy" =~ ^(no|always|on-failure|unless-stopped)$ ]]; then
            log.warn "Invalid restart policy: ${BOLD_YELLOW}$restart_policy${RESET_COLOR} (valid: no, always, on-failure, unless-stopped) in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
        fi
    fi
    
    return $((errors > 0 ? 1 : 0))
}

validate_compose_config() {
    local config_file="${1:-}"
    local errors=0
    local services_found=0
    local -a config_lines=()
    
    mapfile -t config_lines < "$config_file"
    
    for line in "${config_lines[@]}"; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        if [[ "$line" =~ ^\[service: ]]; then
            ((services_found++)) || true
            local service_name
            service_name=$(echo "$line" | sed 's/^\[service://' | sed 's/\]$//')
            
            if [[ -z "$service_name" ]]; then
                log.error "Empty service name in section: ${RED}$line${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                ((errors++)) || true
                continue
            fi
            
            if ! validate_container_name "$service_name"; then
                log.error "Invalid service name format: ${RED}$service_name${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                ((errors++)) || true
            fi
            
            local container_name
            container_name=$(inipars.get "service:$service_name" "container_name" "$config_file")
            local image
            image=$(inipars.get "service:$service_name" "image" "$config_file")
            
            if [[ -z "$container_name" ]]; then
                log.error "Service ${BOLD_YELLOW}$service_name${RESET_COLOR} missing required field: ${RED}container_name${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                ((errors++)) || true
            else
                if ! validate_container_name "$container_name"; then
                    log.error "Invalid container name for service ${BOLD_YELLOW}$service_name${RESET_COLOR}: ${RED}$container_name${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                    ((errors++)) || true
                fi
            fi
            
            if [[ -z "$image" ]]; then
                log.error "Service ${BOLD_YELLOW}$service_name${RESET_COLOR} missing required field: ${RED}image${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                ((errors++)) || true
            else
                if ! validate_image_name "$image"; then
                    log.warn "Image name might be invalid for service ${BOLD_YELLOW}$service_name${RESET_COLOR}: ${BOLD_YELLOW}$image${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                fi
            fi
        fi
    done
    
    if [[ "$services_found" -eq 0 ]]; then
        log.warn "No services found in compose file: ${BOLD_YELLOW}$config_file${RESET_COLOR}."
    fi
    
    return $((errors > 0 ? 1 : 0))
}

validate_safe_paths() {
    local config_file="${1:-}"
    local errors=0
    
    local all_content
    all_content=$(cat "$config_file")
    
    if [[ "$all_content" =~ \.\./\.\. ]] || [[ "$all_content" =~ \.\./\.\./ ]] || [[ "$all_content" =~ /\.\.\.*/ ]] || [[ "$all_content" =~ /\.\./\.\. ]]; then
        log.warn "Config contains potentially unsafe directory traversal patterns (e.g., ../..). Review carefully."
    fi
    
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^\[.*\]$ ]] && continue
        
        if [[ "$line" == *"="* ]]; then
            local value="${line#*=}"
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
            
            if [[ "$value" == *":"* ]]; then
                local host_path="${value%%:*}"
                
                if [[ "$host_path" == "/etc" ]] || \
                   [[ "$host_path" == "/usr" ]] || \
                   [[ "$host_path" == "/bin" ]] || \
                   [[ "$host_path" == "/sbin" ]] || \
                   [[ "$host_path" == "/proc" ]] || \
                   [[ "$host_path" == "/sys" ]] ; then
                    log.warn "Config references potentially sensitive system path: ${BOLD_YELLOW}$host_path${RESET_COLOR} in ${BOLD_YELLOW}$config_file${RESET_COLOR}."
                fi
            fi
        fi
    done < "$config_file"
    
    return $((errors > 0 ? 1 : 0))
}