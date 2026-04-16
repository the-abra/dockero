#!/usr/bin/env bash

wizard_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero wizard ${GREEN}[start|setup|init|quickstart|beginner]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Interactive setup assistant for beginners.
   ${BOLD_WHITE}• What it does:${RESET_COLOR} Guides through common use cases (web server, dev env, database).
EOF
}


    local subcommand="${args[1]:-""}"
    
    if [[ -z "$subcommand" ]]; then
        wizard_interactive
    else
        case "$subcommand" in
            "start"|"setup"|"init"|"quickstart"|"beginner")
                wizard_setup_assistant
                ;;
            *)
                log.error "Unknown wizard subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
                log.hint "Usage: ${BOLD_YELLOW}dockero wizard [start|setup|init|quickstart|beginner]${RESET_COLOR}"
                return 1
                ;;
        esac
    fi
}

wizard_interactive() {
    log.setline "${BOLD_CYAN}🎯 Dockero Interactive Setup Wizard${RESET_COLOR}"
    
    echo ""
    log.info "Welcome to Dockero!"
    log.sub "This wizard will help you get started with Docker containers."
    echo ""
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log.error "Docker is not installed or not in your PATH."
        log.sub "Please install Docker first, then run this wizard again."
        return 1
    fi
    
    # Check if Docker daemon is running (using faster check)
    if ! ${DOCKERO_RUNTIME:-docker} ps -q &> /dev/null; then
        log.error "Docker daemon is not running."
        log.sub "Please start Docker daemon and run this wizard again."
        return 1
    fi
    
    log.done "Docker is available and running! 🎉"
    echo ""
    
    # Ask what they want to do
    log.info "What would you like to do?"
    log.sub "1. Run a simple web server"
    log.sub "2. Try a development environment"
    log.sub "3. Run a database container"
    log.sub "4. Just explore what's possible"
    echo ""
    
    local choice
    read -rp "${BOLD_WHITE}Choose an option (1-4): ${RESET_COLOR}" choice
    echo ""
    
    case "$choice" in
        1)
            wizard_run_simple_server
            ;;
        2)
            wizard_run_dev_env
            ;;
        3)
            wizard_run_database
            ;;
        4)
            wizard_explore_options
            ;;
        *)
            log.warn "Invalid choice: ${BOLD_YELLOW}$choice${RESET_COLOR}. Falling back to simple web server example."
            wizard_run_simple_server
            ;;
    esac
}

wizard_run_simple_server() {
    log.setline "${BOLD_CYAN}🌐 Simple Web Server Setup${RESET_COLOR}"
    log.info "Setting up a simple web server..."
    log.info "This will:"
    log.sub "Pull the nginx:alpine image."
    log.sub "Run it as a container named 'my-web-server'."
    log.sub "Map port 8080 on your host to port 80 in the container."
    echo ""
    
    local response
    read -rp "${BOLD_WHITE}Continue? (Y/n): ${RESET_COLOR}" response
    echo ""
    
    if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
        log.info "Pulling ${BOLD_YELLOW}nginx:alpine${RESET_COLOR} image..."
        if image_pulling "nginx:alpine"; then
            log.info "Running web server on port ${BOLD_YELLOW}8080${RESET_COLOR}..."
            log.done "Access your server at: http://localhost:8080"
            
            # Run in detached mode with port mapping using shared docker_run helper
            if docker_run "my-web-server" "nginx:alpine" "true" "" "" "8080:80" "no" "" ""; then
                log.done "Web server is now running!"
                log.info "Your web server is accessible at ${BOLD_GREEN}http://localhost:8080${RESET_COLOR}"
                log.sub "To stop: ${BOLD_YELLOW}dockero stop my-web-server${RESET_COLOR}"
                log.sub "To remove: ${BOLD_YELLOW}dockero remove my-web-server${RESET_COLOR}"
            else
                log.error "Failed to start web server."
                # Clean up if it failed (use validated container name)
                if validate_container_name "my-web-server"; then
                    ${DOCKERO_RUNTIME:-docker} rm -f my-web-server &>/dev/null
                fi
                return 1
            fi
        else
            log.error "Failed to pull ${RED}nginx:alpine${RESET_COLOR}."
            return 1
        fi
    else
        log.info "Operation cancelled."
        return 0
    fi
}

wizard_run_dev_env() {
    log.setline "${BOLD_CYAN}💻 Development Environment Setup${RESET_COLOR}"
    log.info "Setting up a development environment..."
    log.info "This will:"
    log.sub "Pull the node:16-alpine image."
    log.sub "Create a container with your current directory mapped to /workspace."
    log.sub "Start an interactive shell in the container."
    echo ""
    
    local response
    read -rp "${BOLD_WHITE}Continue? (Y/n): ${RESET_COLOR}" response
    echo ""
    
    if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
        log.info "Pulling ${BOLD_YELLOW}node:16-alpine${RESET_COLOR} image..."
        if image_pulling "node:16-alpine"; then
            local raw_container_name="dev-${PWD##*/}"
            # Sanitize generated container_name
            local container_name
            container_name=$(echo "$raw_container_name" | sed 's/[^a-zA-Z0-9_-]/ /g' | tr -s ' ' | sed 's/ /-/g' | tr '[:upper:]' '[:lower:]')
            container_name="${container_name//- /}" # Remove hyphens followed by space
            container_name="${container_name// /-}" # Replace spaces with hyphens
            container_name="${container_name//[^a-zA-Z0-9-]/}" # Remove remaining invalid chars
            container_name="${container_name,,}" # Ensure lowercase

            # Final validation of the generated name before use
            if ! validate_container_name "$container_name"; then
                log.error "Generated container name '${RED}$container_name${RESET_COLOR}' is invalid. Please try again with a simpler directory name."
                return 1
            fi

            log.info "Creating development container: ${BOLD_YELLOW}$container_name${RESET_COLOR}"
            log.sub "Mapping current directory (${BOLD_YELLOW}$PWD${RESET_COLOR}) to ${BOLD_YELLOW}/workspace${RESET_COLOR} in container."
            
            # Run with volume mapping using shared docker_run helper
            # PWD and /workspace are hardcoded, safe
            if docker_run "$container_name" "node:16-alpine" "false" "/bin/sh" "$PWD:/workspace" "" "no" "" ""; then
                log.done "Development session completed."
            else
                log.error "Failed to start development environment."
                # Clean up if it failed (use validated container name)
                if validate_container_name "$container_name"; then
                    ${DOCKERO_RUNTIME:-docker} rm -f "$container_name" &>/dev/null
                fi
                return 1
            fi
        else
            log.error "Failed to pull ${RED}node:16-alpine${RESET_COLOR}."
            return 1
        fi
    else
        log.info "Operation cancelled."
        return 0
    fi
}

wizard_run_database() {
    log.setline "${BOLD_CYAN}🗄️ Database Container Setup${RESET_COLOR}"
    log.info "Setting up a database container..."
    log.info "We'll set up a PostgreSQL database:"
    log.sub "Pull the postgres:13-alpine image."
    log.sub "Run in detached mode."
    log.sub "Set up default credentials."
    echo ""
    
    local response
    read -rp "${BOLD_WHITE}Continue? (Y/n): ${RESET_COLOR}" response
    echo ""
    
    if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
        log.info "Pulling ${BOLD_YELLOW}postgres:13-alpine${RESET_COLOR} image..."
        if image_pulling "postgres:13-alpine"; then
            echo ""
            local db_password
            read -rs -p "${BOLD_WHITE}Enter a password for the database (default: mysecretpassword): ${RESET_COLOR}" db_password
            echo  # New line after hidden input
            db_password="${db_password:-mysecretpassword}"

            # Validate db_password for basic safety (no shell metacharacters)
            # This is primarily to prevent unexpected behavior in the ${DOCKERO_RUNTIME:-docker} run command if db_password
            # were to contain things like quotes, backticks, or other shell special chars.
            if [[ "$db_password" =~ ['";`$()|&<>!{}[]'] ]]; then
                log.error "Database password contains special characters that are not allowed for security reasons."
                return 1
            fi
            
            log.info "Starting PostgreSQL database..."
            # Use shared docker_run helper.
            # Directly call ${DOCKERO_RUNTIME:-docker} run here because docker_run doesn't support -e multiple times yet without a string parsing helper.
            # Using hardcoded values validated as safe.
            if ${DOCKERO_RUNTIME:-docker} run -d --name my-postgres-db \
                -e "POSTGRES_PASSWORD=$db_password" \
                -p 5432:5432 \
                postgres:13-alpine; then # All values here are validated/hardcoded
                
                log.done "Database is now running!"
                log.info "PostgreSQL database setup complete."
                log.sub "Host: ${BOLD_GREEN}localhost${RESET_COLOR}, Port: ${BOLD_GREEN}5432${RESET_COLOR}"
                log.sub "User: ${BOLD_GREEN}postgres${RESET_COLOR}, Password: ${BOLD_GREEN}$db_password${RESET_COLOR}"
                log.sub "To stop: ${BOLD_YELLOW}dockero stop my-postgres-db${RESET_COLOR}"
                log.sub "To remove: ${BOLD_YELLOW}dockero remove my-postgres-db${RESET_COLOR}"
            else
                log.error "Failed to start database."
                # Clean up if it failed (use validated container name)
                if validate_container_name "my-postgres-db"; then
                    ${DOCKERO_RUNTIME:-docker} rm -f my-postgres-db &>/dev/null
                fi
                return 1
            fi
        else
            log.error "Failed to pull ${RED}postgres:13-alpine${RESET_COLOR}."
            return 1
        fi
    else
        log.info "Operation cancelled."
        return 0
    fi
}

wizard_explore_options() {
    log.setline "${BOLD_CYAN}🗺️ Explore Dockero Options${RESET_COLOR}"
    log.info "Here are some things you can do with Dockero:"
    echo ""
    log.info "Container Management:"
    echo -e "  • ${BOLD_GREEN}dockero create <name> <image>${RESET_COLOR} # Create containers."
    echo -e "  • ${BOLD_GREEN}dockero list${RESET_COLOR}                  # View all containers."
    echo -e "  • ${BOLD_GREEN}dockero stop <container>${RESET_COLOR}      # Stop a container."
    echo -e "  • ${BOLD_GREEN}dockero remove <container>${RESET_COLOR}    # Remove a container."
    echo ""
    log.info "Project Setup:"
    echo -e "  • ${BOLD_GREEN}dockero setup init .${RESET_COLOR}          # Create project config."
    echo -e "  • ${BOLD_GREEN}dockero setup run .${RESET_COLOR}           # Run project setup."
    echo ""
    log.info "Multi-Container Apps:"
    echo -e "  • ${BOLD_GREEN}dockero compose up${RESET_COLOR}            # Start multi-container apps."
    echo -e "  • ${BOLD_GREEN}dockero compose down${RESET_COLOR}          # Stop multi-container apps."
    echo ""
    log.info "Learning:"
    echo -e "  • ${BOLD_GREEN}dockero learn basic${RESET_COLOR}           # Start Docker learning."
    echo -e "  • ${BOLD_GREEN}dockero explain <command>${RESET_COLOR}     # Get command explanations."
    echo -e "  • ${BOLD_GREEN}dockero show dashboard${RESET_COLOR}         # Visual overview."
    echo ""
    log.info "Try running: ${BOLD_YELLOW}dockero show dashboard${RESET_COLOR}"
}

wizard_setup_assistant() {
    log.setline "${BOLD_CYAN}🔧 Setup Assistant${RESET_COLOR}"
    
    log.info "Dockero setup assistant will guide you through project configuration."
    echo ""
    
    # Find potential project directories
    local -a project_dirs=()
    shopt -s nullglob # Enable nullglob
    if [[ -f "./Dockerfile" ]]; then
        project_dirs+=(". (current directory)")
    fi
    
    if [[ -f "./docker-compose.yml" || -f "./docker-compose.yaml" ]]; then
        project_dirs+=(". (current directory)")
    fi
    
    if [[ -f "./package.json" ]]; then
        project_dirs+=(". (current directory)")
    fi
    
    # Look for other potential project files in subdirectories
    while IFS= read -r -d '' file; do
        local dir
        dir=$(dirname "$file")
        if [[ ! " ${project_dirs[*]} " =~ ${dir} ]]; then
            project_dirs+=("$dir")
        fi
    done < <(find . -maxdepth 3 \( -name "package.json" -o -name "Dockerfile" -o -name "*.csproj" -o -name "requirements.txt" -o -name "Gemfile" \) -print0 2>/dev/null)
    shopt -u nullglob # Disable nullglob
    
    if [[ ${#project_dirs[@]} -gt 0 ]]; then
        log.info "Detected potential project directories:"
        for i in "${!project_dirs[@]}"; do
            log.sub "$((i+1)). ${project_dirs[$i]}"
        done
        echo ""
        local choice
        read -rp "${BOLD_WHITE}Which directory would you like to set up? (1-${#project_dirs[@]}): ${RESET_COLOR}" choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#project_dirs[@]} ]]; then
            local selected_dir="${project_dirs[$((choice-1))]}"
            # Sanitize selected_dir before passing it to wizard_setup_project
            if ! _validate_file_path_basic "$selected_dir"; then
                log.error "Invalid project directory selected: ${RED}$selected_dir${RESET_COLOR}."
                return 1
            fi
            wizard_setup_project "$selected_dir"
        else
            log.error "Invalid selection."
            return 1
        fi
    else
        log.info "No project files detected in current directory."
        log.info "You can:"
        log.sub "Run in a project directory with Dockerfile/package.json."
        log.hint "Or run 'dockero setup init .' to create a new config."
        return 0
    fi
}

wizard_setup_project() {
    local project_dir="$1"
    
    # project_dir is already validated by wizard_setup_assistant
    
    log.info "Setting up project in: ${BOLD_GREEN}$project_dir${RESET_COLOR}"
    
    if [[ ! -d "$project_dir" ]]; then # Redundant with _validate_file_path_basic, but harmless.
        log.error "Directory not found: ${RED}$project_dir${RESET_COLOR}."
        return 1
    fi
    
    # Use pushd/popd for changing directories safely
    pushd "$project_dir" >/dev/null || { log.error "Failed to change directory to ${RED}$project_dir${RESET_COLOR}."; return 1; }
    
    local CONF_FILE=".dockero"

    if [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file already exists at: ${BOLD_YELLOW}$CONF_FILE${RESET_COLOR}."
        local response
        read -rp "${YELLOW}Do you want to update it? (Y/n): ${RESET_COLOR}" response
        echo ""
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log.info "Operation cancelled."
            popd >/dev/null || return 1 # Go back to original directory
            return 0
        fi
    fi
    
    # Determine best base image based on project files
    local base_image="ubuntu:latest"
    if [[ -f "./package.json" ]]; then
        base_image="node:16-alpine"
    elif [[ -f "./requirements.txt" ]]; then
        base_image="python:3.9-alpine"
    elif [[ -f "./Gemfile" ]]; then
        base_image="ruby:3.0-alpine"
    elif [[ -f "./Dockerfile" ]]; then
        # Extract base image from existing Dockerfile
        local dockerfile_from
        dockerfile_from=$(grep -i "^FROM " Dockerfile | head -n1 | cut -d' ' -f2)
        base_image="${dockerfile_from:-ubuntu:latest}"
    fi
    
    log.info "Detected project type, suggesting base image: ${BOLD}$base_image${RESET_COLOR}."
    local image_response
    read -rp "${BOLD_WHITE}Use this image? (Y/n): ${RESET_COLOR}" image_response
    echo ""
    
    local image_to_use="$base_image"
    if [[ "$image_response" =~ ^[Nn]$ ]]; then
        read -rp "${BOLD_WHITE}Enter the image you want to use: ${RESET_COLOR}" image_to_use
        image_to_use="${image_to_use:-$base_image}"
    fi

    # Validate image_to_use
    if ! validate_image_name "$image_to_use"; then
        log.error "Invalid image name: ${RED}$image_to_use${RESET_COLOR}."
        popd >/dev/null || return 1 # Go back to original directory
        return 1
    fi

    # Sanitize generated container name for .dockero file
    local raw_generated_name="${PWD##*/}-dev"
    local sanitized_generated_name
    sanitized_generated_name=$(echo "$raw_generated_name" | sed 's/[^a-zA-Z0-9_-]/ /g' | tr -s ' ' | sed 's/ /-/g' | tr '[:upper:]' '[:lower:]')
    sanitized_generated_name="${sanitized_generated_name//- /}" # Remove hyphens followed by space
    sanitized_generated_name="${sanitized_generated_name// /-}" # Replace spaces with hyphens
    sanitized_generated_name="${sanitized_generated_name//[^a-zA-Z0-9-]/}" # Remove remaining invalid chars
    sanitized_generated_name="${sanitized_generated_name,,}" # Ensure lowercase

    if ! validate_container_name "$sanitized_generated_name"; then
        log.error "Generated container name '${RED}$sanitized_generated_name${RESET_COLOR}' is invalid. Cannot write .dockero file."
        popd >/dev/null || return 1
        return 1
    fi
    
    # Create .dockero file
    cat > "$CONF_FILE" << EOF
[default]
name = $sanitized_generated_name
image = $image_to_use
command = /bin/sh
restart_policy = no

[volumes]
env = .:/workspace

[user]
name = $(whoami)
gid = $(id -g)
EOF
    
    log.done ".dockero configuration created: ${BOLD_GREEN}$CONF_FILE${RESET_COLOR}."
    echo ""
    log.info "Configuration created with:"
    log.sub "Container name: ${BOLD}$sanitized_generated_name${RESET_COLOR}"
    log.sub "Base image:     ${BOLD}$image_to_use${RESET_COLOR}"
    log.sub "Volume mapping: ./:/workspace"
    echo ""
    log.sub "To start your project: ${BOLD_YELLOW}dockero setup run .${RESET_COLOR}"
    log.sub "To learn more: ${BOLD_YELLOW}dockero explain setup${RESET_COLOR}"

    popd >/dev/null || return 1 # Go back to original directory
}