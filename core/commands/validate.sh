#!/usr/bin/env bash

validate() {
    local target="${args[1]:-.}"
    local config_file="${args[2]}"
    
    if [[ -z "$target" ]]; then
        log.hint "validate [path] [config-file]"
        log.sub "Validate configuration files in the specified path"
        log.sub "If no config-file specified, validates all .dockero files in path"
        return 1
    fi
    
    log.setline "Configuration Validation"
    
    # If specific config file is provided
    if [[ -n "$config_file" ]]; then
        if [[ -f "$target/$config_file" ]]; then
            validate_single_config "$target/$config_file"
        elif [[ -f "$config_file" ]]; then
            validate_single_config "$config_file"
        else
            log.error "Configuration file not found: $config_file"
            return 1
        fi
    else
        # Validate all .dockero files in the target path
        local config_files=()
        while IFS= read -r -d '' file; do
            config_files+=("$file")
        done < <(find "$target" -name ".dockero*" -type f -print0)
        
        local success_count=0
        local failed_count=0
        
        for file in "${config_files[@]}"; do
            log.info "Validating: $file"
            if validate_single_config "$file"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
            echo
        done
        
        if [[ $failed_count -eq 0 ]]; then
            log.done "Validation completed: $success_count files passed"
        else
            log.warn "Validation completed: $success_count passed, $failed_count failed"
            return 1
        fi
    fi
}

validate_single_config() {
    local config_file="$1"
    local file_type=""
    
    # Determine file type based on name
    if [[ "$config_file" == *".dockero-compose"* ]]; then
        file_type="compose"
    elif [[ "$config_file" == *".dockero"* ]]; then
        file_type="dockero"
    else
        log.error "Unknown configuration file type: $config_file"
        return 1
    fi
    
    if [[ ! -f "$config_file" ]]; then
        log.error "File does not exist: $config_file"
        return 1
    fi
    
    log.sub "File: $config_file"
    
    # Basic validation: check if file is readable and not empty
    if [[ ! -r "$config_file" ]]; then
        log.error "File is not readable: $config_file"
        return 1
    fi
    
    if [[ ! -s "$config_file" ]]; then
        log.error "File is empty: $config_file"
        return 1
    fi
    
    # Validate INI structure
    if ! validate_ini_structure "$config_file"; then
        log.error "Invalid INI structure in: $config_file"
        return 1
    fi
    
    # Validate based on file type
    local validation_passed=1
    case "$file_type" in
        "dockero")
            if validate_dockero_config "$config_file"; then
                log.sub "✅ .dockero format validation passed"
            else
                validation_passed=0
            fi
            ;;
        "compose")
            if validate_compose_config "$config_file"; then
                log.sub "✅ .dockero-compose format validation passed"
            else
                validation_passed=0
            fi
            ;;
    esac
    
    # Validate file access patterns are safe
    if ! validate_safe_paths "$config_file"; then
        log.error "Configuration contains unsafe paths: $config_file"
        return 1
    fi
    
    if [[ $validation_passed -eq 1 ]]; then
        log.done "✓ Configuration validation passed: $config_file"
        return 0
    else
        return 1
    fi
}

validate_ini_structure() {
    local config_file="$1"
    
    # Check for basic INI structure: sections in brackets
    local sections=0
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ $line =~ ^[[:space:]]*$ ]] && continue
        
        # Check for section headers [section]
        if [[ $line =~ ^\[.*\]$ ]]; then
            ((sections++))
        elif [[ $line != *"="* ]]; then
            # Non-section line should be key=value format
            log.warn "Potentially invalid line (no '='): $line"
        fi
    done < "$config_file"
    
    # A valid config should have at least one section
    if [[ $sections -eq 0 ]]; then
        log.error "No sections found in INI file"
        return 1
    fi
    
    return 0
}

validate_dockero_config() {
    local config_file="$1"
    local errors=0
    
    # Get required fields from the config
    local name=$(inipars.get "default" "name" "$config_file")
    local image=$(inipars.get "default" "image" "$config_file")
    
    # Validate required fields exist
    if [[ -z "$name" ]]; then
        log.error "Missing required field: name (in [default] section)"
        ((errors++))
    else
        # Validate name doesn't contain invalid characters
        if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
            log.error "Invalid container name format: $name"
            log.sub "Container names should contain only alphanumeric characters, underscores, hyphens, and dots"
            ((errors++))
        fi
    fi
    
    if [[ -z "$image" ]]; then
        log.error "Missing required field: image (in [default] section)"
        ((errors++))
    else
        # Validate image format (basic check - should contain only valid characters)
        if [[ ! "$image" =~ ^[a-zA-Z0-9/_.:-]+$ ]]; then
            log.warn "Image name might be invalid: $image"
        fi
    fi
    
    # Validate optional fields have reasonable formats
    local port=$(inipars.get "volumes" "port" "$config_file")
    if [[ -n "$port" ]]; then
        # Basic port format validation (host:container or host-port:container-port)
        if [[ ! "$port" =~ ^[0-9]+:[0-9]+$ ]]; then
            log.warn "Port mapping might be invalid: $port (expected format: host:container)"
        fi
    fi
    
    local restart_policy=$(inipars.get "default" "restart_policy" "$config_file")
    if [[ -n "$restart_policy" ]]; then
        # Validate restart policy
        if [[ ! "$restart_policy" =~ ^(no|always|on-failure|unless-stopped)$ ]]; then
            log.warn "Invalid restart policy: $restart_policy (valid: no, always, on-failure, unless-stopped)"
        fi
    fi
    
    return $((errors > 0 ? 1 : 0))
}

validate_compose_config() {
    local config_file="$1"
    local errors=0
    local services_found=0
    
    # Parse the file to find service sections
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ $line =~ ^[[:space:]]*$ ]] && continue
        
        # Check for service sections [service:name]
        if [[ $line =~ ^\[service: ]]; then
            ((services_found++))
            local service_name=$(echo "$line" | sed 's/\[service://' | sed 's/\]//')
            
            if [[ -z "$service_name" ]]; then
                log.error "Empty service name in section: $line"
                ((errors++))
                continue
            fi
            
            # Validate service name doesn't contain invalid characters
            if [[ ! "$service_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                log.error "Invalid service name format: $service_name"
                ((errors++))
            fi
            
            # Validate required fields for the service
            local container_name=$(inipars.get "service:$service_name" "container_name" "$config_file")
            local image=$(inipars.get "service:$service_name" "image" "$config_file")
            
            if [[ -z "$container_name" ]]; then
                log.error "Service $service_name missing required field: container_name"
                ((errors++))
            else
                if [[ ! "$container_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
                    log.error "Invalid container name for service $service_name: $container_name"
                    ((errors++))
                fi
            fi
            
            if [[ -z "$image" ]]; then
                log.error "Service $service_name missing required field: image"
                ((errors++))
            else
                if [[ ! "$image" =~ ^[a-zA-Z0-9/_.:-]+$ ]]; then
                    log.warn "Image name might be invalid for service $service_name: $image"
                fi
            fi
        fi
    done < "$config_file"
    
    if [[ $services_found -eq 0 ]]; then
        log.warn "No services found in compose file"
    fi
    
    return $((errors > 0 ? 1 : 0))
}

validate_safe_paths() {
    local config_file="$1"
    
    # Check for potentially dangerous paths in volume configurations
    local all_content=$(cat "$config_file")
    
    # Check for attempts to escape the filesystem root
    if [[ $all_content =~ \.\./\.\. ]] || [[ $all_content =~ \.\./\.\./ ]] || [[ $all_content =~ /\.\.\.*/ ]] || [[ $all_content =~ /\.\./\.\. ]]; then
        log.error "Config contains potentially unsafe directory traversal patterns"
        return 1
    fi
    
    # Check for absolute paths that might access system areas
    # This is a basic check - in a real implementation, we'd want more sophisticated validation
    while IFS= read -r line; do
        [[ $line =~ ^[[:space:]]*# ]] && continue
        [[ $line =~ ^[[:space:]]*$ ]] && continue
        [[ $line =~ ^\[.*\]$ ]] && continue  # Skip section headers
        
        # Check if line contains a path (volume mapping)
        if [[ $line == *"="* ]]; then
            local value="${line#*=}"
            value=$(echo "$value" | xargs)  # trim whitespace
            
            # Check if it looks like a volume path (contains ':')
            if [[ $value == *":"* ]]; then
                local host_path="${value%%:*}"
                
                # Check if the host path goes too high up
                if [[ $host_path =~ ^(/\.\.)+ ]] || [[ $host_path =~ ^\.\./ ]] || [[ $host_path == "/root" ]] || [[ $host_path == "/etc" ]] || [[ $host_path == "/usr" ]] || [[ $host_path == "/bin" ]] || [[ $host_path == "/sbin" ]]; then
                    # These are not inherently unsafe but might be worth warning about
                    log.sub "Note: Config references system path: $host_path"
                fi
            fi
        fi
    done < "$config_file"
    
    return 0
}