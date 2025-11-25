#!/usr/bin/env bash

wizard() {
    local subcommand="${args[1]:-""}"
    
    case "$subcommand" in
        "start"|"setup"|"init"|"quickstart"|"beginner")
            wizard_setup_assistant
            ;;
        "")
            wizard_interactive
            ;;
        *)
            log.error "Unknown wizard subcommand: $subcommand"
            log.hint "Use: dockero wizard [start|setup|init|quickstart|beginner]"
            return 1
            ;;
    esac
}

wizard_interactive() {
    log.setline "🎯 Dockero Interactive Setup Wizard"
    
    echo
    echo -e "${BOLD_BLUE}Welcome to Dockero!${RESET_COLOR}"
    echo "This wizard will help you get started with Docker containers."
    echo
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null; then
        log.error "Docker is not installed or not in your PATH"
        log.sub "Please install Docker first, then run this wizard again"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log.error "Docker daemon is not running"
        log.sub "Please start Docker daemon and run this wizard again"
        return 1
    fi
    
    log.info "Docker is available and running! 🎉"
    echo
    
    # Ask what they want to do
    echo -e "${BOLD_YELLOW}What would you like to do?${RESET_COLOR}"
    echo "1. Run a simple web server"
    echo "2. Try a development environment" 
    echo "3. Run a database container"
    echo "4. Just explore what's possible"
    echo
    
    read -rp "Choose an option (1-4): " choice
    echo
    
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
            log.error "Invalid choice: $choice"
            log.info "Let's try the simple web server example..."
            wizard_run_simple_server
            ;;
    esac
}

wizard_run_simple_server() {
    log.info "Setting up a simple web server..."
    echo -e "${YELLOW}This will:${RESET_COLOR}"
    echo "  • Pull the nginx:alpine image"
    echo "  • Run it as a container named 'my-web-server'"
    echo "  • Map port 8080 on your host to port 80 in the container"
    echo
    
    read -rp "Continue? (Y/n): " -n 1
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        log.info "Pulling nginx:alpine image..."
        if docker pull nginx:alpine; then
            log.done "Image downloaded successfully"
            
            log.info "Running web server on port 8080..."
            echo -e "${YELLOW}Access your server at: http://localhost:8080${RESET_COLOR}"
            
            # Run in detached mode with port mapping
            if docker run -d -p 8080:80 --name my-web-server nginx:alpine; then
                log.done "Web server is now running!"
                log.info "Your web server is accessible at http://localhost:8080"
                log.sub "To stop: dockero stop my-web-server"
                log.sub "To remove: dockero remove my-web-server"
            else
                log.error "Failed to start web server"
                # Clean up if it failed
                docker rm -f my-web-server &>/dev/null
                return 1
            fi
        else
            log.error "Failed to pull nginx:alpine"
            return 1
        fi
    else
        log.info "Operation cancelled"
        return 0
    fi
}

wizard_run_dev_env() {
    log.info "Setting up a development environment..."
    echo -e "${YELLOW}This will:${RESET_COLOR}"
    echo "  • Pull the node:16-alpine image"
    echo "  • Create a container with your current directory mapped"
    echo "  • Start an interactive shell in the container"
    echo
    
    read -rp "Continue? (Y/n): " -n 1
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        log.info "Pulling node:16-alpine image..."
        if docker pull node:16-alpine; then
            log.done "Image downloaded successfully"
            
            local container_name="dev-${PWD##*/}"
            # Replace any non-alphanumeric characters with hyphens
            container_name="${container_name//[^[:alnum:]]/-}"
            
            log.info "Creating development container: $container_name"
            log.sub "Mapping current directory to /workspace in container"
            
            # Run with volume mapping
            if docker run -it --rm --name "$container_name" \
                -v "$PWD:/workspace" \
                -w /workspace \
                node:16-alpine /bin/sh; then
                log.done "Development session completed"
            else
                log.error "Failed to start development environment"
                return 1
            fi
        else
            log.error "Failed to pull node:16-alpine"
            return 1
        fi
    else
        log.info "Operation cancelled"
        return 0
    fi
}

wizard_run_database() {
    log.info "Setting up a database container..."
    echo -e "${YELLOW}We'll set up a PostgreSQL database${RESET_COLOR}"
    echo "  • Pull the postgres:13-alpine image"
    echo "  • Run in detached mode"
    echo "  • Set up default credentials"
    echo
    
    read -rp "Continue? (Y/n): " -n 1
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        log.info "Pulling postgres:13-alpine image..."
        if docker pull postgres:13-alpine; then
            log.done "Image downloaded successfully"
            
            echo
            read -rp "Enter a password for the database (default: mysecretpassword): " db_password
            db_password="${db_password:-mysecretpassword}"
            
            log.info "Starting PostgreSQL database..."
            if docker run -d --name my-postgres-db \
                -e POSTGRES_PASSWORD="$db_password" \
                -p 5432:5432 \
                postgres:13-alpine; then
                log.done "Database is now running!"
                log.info "PostgreSQL database setup complete"
                log.sub "Host: localhost, Port: 5432"
                log.sub "User: postgres, Password: $db_password"
                log.sub "To stop: dockero stop my-postgres-db"
                log.sub "To remove: dockero remove my-postgres-db"
            else
                log.error "Failed to start database"
                # Clean up if it failed
                docker rm -f my-postgres-db &>/dev/null
                return 1
            fi
        else
            log.error "Failed to pull postgres:13-alpine"
            return 1
        fi
    else
        log.info "Operation cancelled"
        return 0
    fi
}

wizard_explore_options() {
    log.info "Here are some things you can do with Dockero:"
    echo
    echo -e "${BOLD_YELLOW}Container Management:${RESET_COLOR}"
    echo "  • dockero run <name> <image>    # Create/start containers"
    echo "  • dockero list                  # View all containers"
    echo "  • dockero stop <container>      # Stop a container"
    echo "  • dockero remove <container>    # Remove a container"
    echo
    echo -e "${BOLD_YELLOW}Project Setup:${RESET_COLOR}"
    echo "  • dockero setup init .          # Create project config"
    echo "  • dockero setup run .           # Run project setup"
    echo
    echo -e "${BOLD_YELLOW}Multi-Container Apps:${RESET_COLOR}"
    echo "  • dockero compose up            # Start multi-container apps"
    echo "  • dockero compose down          # Stop multi-container apps"
    echo
    echo -e "${BOLD_YELLOW}Learning:${RESET_COLOR}"
    echo "  • dockero learn basic           # Start Docker learning"
    echo "  • dockero explain <command>     # Get command explanations"
    echo "  • dockero show dashboard        # Visual overview"
    echo
    log.info "Try running: dockero show dashboard"
}

wizard_setup_assistant() {
    log.setline "🔧 Setup Assistant"
    
    log.info "Dockero setup assistant will guide you through project configuration"
    echo
    
    # Find potential project directories
    local project_dirs=()
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
        local dir=$(dirname "$file")
        if [[ ! " ${project_dirs[*]} " =~ " ${dir} " ]]; then
            project_dirs+=("$dir")
        fi
    done < <(find . -maxdepth 3 \( -name "package.json" -o -name "Dockerfile" -o -name "*.csproj" -o -name "requirements.txt" -o -name "Gemfile" \) -print0)
    
    if [[ ${#project_dirs[@]} -gt 0 ]]; then
        echo -e "${BOLD_YELLOW}Detected potential project directories:${RESET_COLOR}"
        for i in "${!project_dirs[@]}"; do
            echo "  $((i+1)). ${project_dirs[$i]}"
        done
        echo
        read -rp "Which directory would you like to set up? (1-${#project_dirs[@]}): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#project_dirs[@]} ]]; then
            local selected_dir="${project_dirs[$((choice-1))]}"
            wizard_setup_project "$selected_dir"
        else
            log.error "Invalid selection"
            return 1
        fi
    else
        log.info "No project files detected in current directory"
        echo -e "${YELLOW}You can:${RESET_COLOR}"
        echo "  • Run in a project directory with Dockerfile/package.json"
        echo "  • Or run 'dockero setup init .' to create a new config"
        return 0
    fi
}

wizard_setup_project() {
    local project_dir="$1"
    log.info "Setting up project in: $project_dir"
    
    if [[ ! -d "$project_dir" ]]; then
        log.error "Directory not found: $project_dir"
        return 1
    fi
    
    cd "$project_dir" || return 1
    
    if [[ -f ".dockero" ]]; then
        log.warn ".dockero file already exists"
        read -rp "Do you want to update it? (y/N): " -n 1
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log.info "Operation cancelled"
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
        base_image=$(grep -i "^FROM " Dockerfile | head -n1 | cut -d' ' -f2)
        base_image=${base_image:-"ubuntu:latest"}
    fi
    
    echo -e "${YELLOW}Detected project type, suggesting base image: $base_image${RESET_COLOR}"
    read -rp "Use this image? (Y/n): " -n 1
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        local image_to_use="$base_image"
    else
        read -rp "Enter the image you want to use: " image_to_use
        image_to_use=${image_to_use:-"$base_image"}
    fi
    
    # Create .dockero file
    cat > .dockero << EOF
[default]
name = ${PWD##*/}-dev
image = $image_to_use
command = /bin/sh
restart_policy = no

[volumes]
env = .:/workspace

[user]
name = $(whoami)
gid = $(id -g)
EOF
    
    log.done ".dockero configuration created"
    echo
    log.info "Configuration created with:"
    echo "  • Container name: ${PWD##*/}-dev"
    echo "  • Base image: $image_to_use"
    echo "  • Volume mapping: .:/workspace"
    echo
    log.sub "To start your project: dockero setup run ."
    log.sub "To learn more: dockero explain setup"
}