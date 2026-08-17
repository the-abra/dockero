#!/usr/bin/env bash

# Source shared Docker helpers
# (assuming docker-helpers.sh is sourced by dockero globally now)

setup_help() {
cat << EOF
${BOLD_CYAN}dockero setup ${GREEN}[init|run|update|teardown] [path] [--dry-run] [--preset <type>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Set up and manage a containerized project from a .dockero config file.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}init [path] [--preset <type>]${RESET_COLOR}  Create a new .dockero config (presets: node, python, go, rust, php, ruby, java, nginx, redis, postgres, mysql).
     - ${GREEN}run [path] [--dry-run]${RESET_COLOR}         Run the project defined in .dockero (default).
     - ${GREEN}update [path]${RESET_COLOR}                  Rebuild and update a running project container.
     - ${GREEN}teardown [path]${RESET_COLOR}                Stop and remove the project container.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker run [config from .dockero file]${RESET_COLOR}
EOF
}

setup() {
    # shellcheck disable=SC2154
    local subcommand="${args[1]:-}"
    local has_dry_run=0 # Default to no dry-run

    # Check for --dry-run or -n flag first
    if [[ -n "${params[n]+set}" || -n "${params[dry-run]+set}" ]]; then
        has_dry_run=1
    fi

    # Default to 'run' subcommand if no explicit subcommand is provided
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "init" && "$subcommand" != "run" && "$subcommand" != "create" && "$subcommand" != "build" && "$subcommand" != "update" && "$subcommand" != "teardown" && "$subcommand" != "delete" ]]; then
        # If no argument or a path is given, assume 'run' on given path or current dir
        local target_path="${args[1]:-.}"
        setup_run "$target_path" "$has_dry_run"
    else
        case "$subcommand" in
            "init"|"create")
                setup_init "${args[2]:-./}"
                ;;
            "run"|"build")
                setup_run "${args[2]:-.}" "$has_dry_run"
                ;;
            "update")
                setup_update "${args[2]:-.}"
                ;;
            "teardown"|"delete")
                setup_teardown "${args[2]:-.}"
                ;;
            *)
                log.error "Unknown setup subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
                log.hint "Usage: ${BOLD_YELLOW}dockero setup [init|run|update|teardown] [path] [options]${RESET_COLOR}"
                return 1
                ;;
        esac
    fi
}

setup_run() {
    local project_path="${1:-.}"
    local dry_run="${2:-0}" # 0 for normal run, 1 for dry-run

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    local CONF_FILE="$project_path/.dockero"

    if [[ ! -d "$project_path" ]]; then
        log.error "Project not found: ${RED}$project_path${RESET_COLOR}"
        return 1
    elif [[ ! -f "$CONF_FILE" ]]; then
        log.error ".dockero file not found in project path: ${RED}$CONF_FILE${RESET_COLOR}."
        log.hint "Use '${BOLD_YELLOW}dockero setup init \"$project_path\"${RESET_COLOR}' to create a new configuration."
        return 1
    fi

    # Parse .dockero configuration
    local name
    local image
    local command_str
    local volume_mount
    local port_mapping
    local restart_policy
    local user_name
    local user_gid

    name=$(inipars.get "default" "name" "$CONF_FILE")
    image=$(inipars.get "default" "image" "$CONF_FILE")
    command_str=$(inipars.get "default" "command" "$CONF_FILE")
    volume_mount=$(inipars.get "volumes" "mount" "$CONF_FILE")
    if [[ -z "$volume_mount" ]]; then
        volume_mount=$(inipars.get "volumes" "env" "$CONF_FILE") # 'env' key fallback
    fi
    port_mapping=$(inipars.get "volumes" "port" "$CONF_FILE")
    restart_policy=$(inipars.get "default" "restart_policy" "$CONF_FILE")
    user_name=$(inipars.get "user" "name" "$CONF_FILE")
    user_gid=$(inipars.get "user" "gid" "$CONF_FILE")

    # Set defaults if not provided in .dockero
    volume_mount="${volume_mount:-$project_path:/workspace}"
    port_mapping="${port_mapping:-${DOCKERO_DEFAULT_PORT:-80}}" # Use global default if not in .dockero
    restart_policy="${restart_policy:-no}" # Default to 'no' if not in .dockero
    user_name="${user_name:-root}"
    user_gid="${user_gid:-$(id -g root)}" # Default to root's GID

    # Validate required fields
    if [[ -z "$name" || -z "$image" ]]; then
        log.error "Missing required fields in ${RED}$CONF_FILE${RESET_COLOR}: 'name' or 'image'."
        return 1
    fi

    # Check if container name is available only if not dry-run
    if [[ "$dry_run" -eq 0 ]]; then
        if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$name$"; then
            log.error "The container name ${RED}$name${RESET_COLOR} is already in use. Please choose a different name or remove the existing container."
            return 1
        fi
    fi

    log.setline "${BOLD_CYAN}Project Setup: ${GREEN}$name${RESET_COLOR}"

    if [[ "$dry_run" -eq 1 ]]; then
        log.info "DRY RUN MODE - Would launch container: ${BOLD_YELLOW}$name${RESET_COLOR}"
        log.sub "Image: ${YELLOW}$image${RESET_COLOR}"
        log.sub "Command: ${YELLOW}${command_str:-bash}${RESET_COLOR}"
        log.sub "Volume Mount: ${YELLOW}$volume_mount${RESET_COLOR}"
        log.sub "Port Mapping: ${YELLOW}$port_mapping${RESET_COLOR}"
        log.sub "Restart Policy: ${YELLOW}$restart_policy${RESET_COLOR}"
        log.sub "User: ${YELLOW}$user_name:$user_gid${RESET_COLOR}"
        log.info "DRY RUN MODE - No changes made."
        return 0
    fi

    # Pull image if not available locally
    local search_image="$image"
    if [[ "$image" != *:* ]]; then
        search_image="$image:latest"
    fi

    if ! ${DOCKERO_RUNTIME:-docker} images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$search_image$"; then
        log.warn "Image '${BOLD_YELLOW}$image${RESET_COLOR}' not found locally. Pulling..."
        if ! image_pulling "$image"; then
            log.error "Failed to pull image: ${RED}$image${RESET_COLOR}."
            return 1
        fi
    else
        log.info "Using local image: ${BOLD_GREEN}$image${RESET_COLOR}."
    fi

    log.info "Launching container: ${BOLD_YELLOW}$name${RESET_COLOR}..."
    # Call the global docker_run helper function
    # Arguments: container_name, image_name, detach_mode, cmd_args_array, volume_mount, port_mapping, restart_policy, user_name, user_gid
    if ! docker_run "$name" "$image" "true" "$command_str" "$volume_mount" "$port_mapping" "$restart_policy" "$user_name" "$user_gid"; then
        log.error "Failed to run container: ${RED}$name${RESET_COLOR}."
        return 1
    fi

    log.done "Container '${BOLD_GREEN}$name${RESET_COLOR}' started successfully."
    return 0
}

setup_init() {
    local project_path="$1"
    
    if [[ -z "$project_path" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero setup init <project-path> [--preset <type>]${RESET_COLOR}"
        return 1
    fi

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    local CONF_FILE="$project_path/.dockero"

    if [[ ! -d "$project_path" ]]; then
        log.error "Project path does not exist: ${RED}$project_path${RESET_COLOR}."
        return 1
    fi

    if [[ -f "$CONF_FILE" ]]; then
        log.warn ".dockero file already exists at: ${BOLD_YELLOW}$CONF_FILE${RESET_COLOR}."
        log.info "Use '${BOLD_YELLOW}dockero setup update \"$project_path\"${RESET_COLOR}' to modify existing configuration."
        return 1
    fi

    local preset=""
    if [[ -n "${params[preset]+set}" ]]; then
        preset="${params[preset]}"
    elif [[ -n "${params[p]+set}" ]]; then
        preset="${params[p]}"
    fi

    local container_name_default="${project_path##*/}"
    local container_name="$container_name_default"
    local docker_image="ubuntu:latest"
    local port_mapping="8080:80"
    local volume_mount="$project_path:/workspace"
    local custom_command="bash"
    local restart_policy="no"

    if [[ -n "$preset" ]]; then
        case "$preset" in
            "nginx")
                container_name="${container_name_default}-nginx"
                docker_image="nginx:alpine"
                port_mapping="8080:80"
                volume_mount="$project_path:/usr/share/nginx/html"
                custom_command=""
                ;;
            "postgres"|"postgresql")
                container_name="${container_name_default}-postgres"
                docker_image="postgres:alpine"
                port_mapping="5432:5432"
                volume_mount=""
                custom_command=""
                ;;
            "mysql"|"mariadb")
                container_name="${container_name_default}-mysql"
                docker_image="mysql:8.0"
                port_mapping="3306:3306"
                volume_mount=""
                custom_command=""
                ;;
            "node"|"nodejs")
                container_name="${container_name_default}-node"
                docker_image="node:alpine"
                port_mapping="3000:3000"
                volume_mount="$project_path:/app"
                custom_command="npm start"
                ;;
            "python")
                container_name="${container_name_default}-python"
                docker_image="python:3.11-alpine"
                port_mapping="8000:8000"
                volume_mount="$project_path:/app"
                custom_command="python app.py"
                ;;
            "go"|"golang")
                container_name="${container_name_default}-go"
                docker_image="golang:alpine"
                port_mapping="8080:8080"
                volume_mount="$project_path:/app"
                custom_command="go run ."
                ;;
            "rust")
                container_name="${container_name_default}-rust"
                docker_image="rust:alpine"
                port_mapping="8080:8080"
                volume_mount="$project_path:/app"
                custom_command="cargo run"
                ;;
            "php")
                container_name="${container_name_default}-php"
                docker_image="php:8.2-apache"
                port_mapping="8080:80"
                volume_mount="$project_path:/var/www/html"
                custom_command=""
                ;;
            "ruby")
                container_name="${container_name_default}-ruby"
                docker_image="ruby:alpine"
                port_mapping="3000:3000"
                volume_mount="$project_path:/app"
                custom_command="ruby app.rb"
                ;;
            "java")
                container_name="${container_name_default}-java"
                docker_image="eclipse-temurin:21-jre-alpine"
                port_mapping="8080:8080"
                volume_mount="$project_path:/app"
                custom_command="java -jar app.jar"
                ;;
            "redis")
                container_name="${container_name_default}-redis"
                docker_image="redis:alpine"
                port_mapping="6379:6379"
                volume_mount=""
                custom_command=""
                ;;
            *)
                log.error "Unknown preset: ${BOLD_RED}$preset${RESET_COLOR}"
                log.hint "Supported presets: node, python, go, rust, php, ruby, java, nginx, redis, postgres, mysql"
                return 1
                ;;
        esac
        log.info "Using preset configuration: ${BOLD_GREEN}$preset${RESET_COLOR}"
    else
        log.setline "${BOLD_CYAN}✨ Setup Configuration Wizard${RESET_COLOR}"
        log.info "Creating new .dockero configuration for: ${BOLD_GREEN}$project_path${RESET_COLOR}."

        # Interactive setup using read -rp for portability and coloring
        read -rp "${YELLOW}Container Name${RESET_COLOR} [default: ${container_name_default}]: " container_name
        container_name=${container_name:-$container_name_default}

        read -rp "${YELLOW}Docker Image${RESET_COLOR} [default: ubuntu:latest]: " docker_image
        docker_image=${docker_image:-ubuntu:latest}

        read -rp "${YELLOW}Port Mapping${RESET_COLOR} [format: host:container, default: 8080:80]: " port_mapping
        port_mapping=${port_mapping:-8080:80}

        read -rp "${YELLOW}Volume Mount${RESET_COLOR} [format: host:container, default: $project_path:/workspace]: " volume_mount
        volume_mount=${volume_mount:-$project_path:/workspace}

        read -rp "${YELLOW}Custom Command${RESET_COLOR} [optional, default: bash]: " custom_command
        custom_command=${custom_command:-bash}

        read -rp "${YELLOW}Restart Policy${RESET_COLOR} [no,always,on-failure,unless-stopped, default: no]: " restart_policy
        restart_policy=${restart_policy:-no}
    fi

    # Create the .dockero file
    cat > "$CONF_FILE" << EOF
[default]
name = $container_name
image = $docker_image
command = $custom_command
restart_policy = $restart_policy

[volumes]
env = $volume_mount
port = $port_mapping

[user]
name = root
EOF

    log.done "Configuration saved to: ${BOLD_GREEN}$CONF_FILE${RESET_COLOR}."
    log.info "Use '${BOLD_YELLOW}dockero setup run \"$project_path\"${RESET_COLOR}' to start your container."
}

setup_update() {
    local project_path="${1:-}"
    
    if [[ -z "$project_path" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero setup update <project-path>${RESET_COLOR}"
        return 1
    fi

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    local CONF_FILE="$project_path/.dockero"

    if [[ ! -d "$project_path" ]]; then
        log.error "Project not found: ${RED}$project_path${RESET_COLOR}."
        return 1
    elif [[ ! -f "$CONF_FILE" ]]; then
        log.error ".dockero file not found in project path: ${RED}$CONF_FILE${RESET_COLOR}."
        log.hint "Use '${BOLD_YELLOW}dockero setup init \"$project_path\"${RESET_COLOR}' to create a new configuration."
        return 1
    fi

    log.setline "${BOLD_CYAN}📝 Update Configuration${RESET_COLOR}"
    log.info "Updating .dockero configuration for: ${BOLD_GREEN}$project_path${RESET_COLOR}."

    # Read current values
    local current_name
    local current_image
    local current_port
    local current_env
    local current_command
    local current_restart
    current_name=$(inipars.get "default" "name" "$CONF_FILE")
    current_image=$(inipars.get "default" "image" "$CONF_FILE")
    current_port=$(inipars.get "volumes" "port" "$CONF_FILE")
    current_env=$(inipars.get "volumes" "env" "$CONF_FILE")
    current_command=$(inipars.get "default" "command" "$CONF_FILE")
    current_restart=$(inipars.get "default" "restart_policy" "$CONF_FILE")

    # Interactive update using read -rp for portability and coloring
    read -rp "${YELLOW}Container Name${RESET_COLOR} [current: ${current_name}]: " container_name
    container_name=${container_name:-$current_name}

    read -rp "${YELLOW}Docker Image${RESET_COLOR} [current: ${current_image}]: " docker_image
    docker_image=${docker_image:-$current_image}

    read -rp "${YELLOW}Port Mapping${RESET_COLOR} [current: ${current_port}]: " port_mapping
    port_mapping=${port_mapping:-$current_port}

    read -rp "${YELLOW}Volume Mount${RESET_COLOR} [current: ${current_env}]: " volume_mount
    volume_mount=${volume_mount:-$current_env}

    read -rp "${YELLOW}Custom Command${RESET_COLOR} [current: ${current_command}]: " custom_command
    custom_command=${custom_command:-$current_command}

    read -rp "${YELLOW}Restart Policy${RESET_COLOR} [current: ${current_restart}]: " restart_policy
    restart_policy=${restart_policy:-$current_restart}

    # Update the .dockero file (need to pass the CONF_FILE explicitly)
    inipars.set "default" "name" "$container_name" "$CONF_FILE"
    inipars.set "default" "image" "$docker_image" "$CONF_FILE"
    inipars.set "volumes" "port" "$port_mapping" "$CONF_FILE"
    inipars.set "volumes" "env" "$volume_mount" "$CONF_FILE"
    inipars.set "default" "command" "$custom_command" "$CONF_FILE"
    inipars.set "default" "restart_policy" "$restart_policy" "$CONF_FILE"

    log.done "Configuration updated in: ${BOLD_GREEN}$CONF_FILE${RESET_COLOR}."
    log.hint "Use '${BOLD_YELLOW}dockero setup run \"$project_path\"${RESET_COLOR}' to apply changes."
}

setup_teardown() {
    local project_path="${1:-}"
    
    if [[ -z "$project_path" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero setup teardown <project-path>${RESET_COLOR}"
        return 1
    fi

    [[ "$project_path" != /* ]] && project_path="$PWD/$project_path"
    local CONF_FILE="$project_path/.dockero"

    if [[ ! -d "$project_path" ]]; then
        log.error "Project not found: ${RED}$project_path${RESET_COLOR}."
        return 1
    elif [[ ! -f "$CONF_FILE" ]]; then
        log.error ".dockero file not found in project path: ${RED}$CONF_FILE${RESET_COLOR}."
        return 1
    fi

    # Parse .dockero configuration to get container name
    local name
    name=$(inipars.get "default" "name" "$CONF_FILE")

    if [[ -z "$name" ]]; then
        log.error "Container name not found in ${RED}$CONF_FILE${RESET_COLOR}."
        return 1
    fi

    log.setline "${BOLD_CYAN}Teardown Project: ${RED}$name${RESET_COLOR}"
    log.info "Stopping and removing container: ${BOLD_YELLOW}$name${RESET_COLOR}."

    # Stop container if running
    if ${DOCKERO_RUNTIME:-docker} ps --format '{{.Names}}' | grep -q "^$name$"; then
        log.info "Stopping container: ${BOLD_YELLOW}$name${RESET_COLOR}."
        if ${DOCKERO_RUNTIME:-docker} stop "$name" > /dev/null 2>&1; then
            log.done "Container '${BOLD_GREEN}$name${RESET_COLOR}' stopped."
        else
            log.error "Failed to stop container: ${RED}$name${RESET_COLOR}."
        fi
    else
        log.warn "Container ${BOLD_YELLOW}$name${RESET_COLOR} was not running."
    fi

    # Remove container
    if ${DOCKERO_RUNTIME:-docker} ps -a --format '{{.Names}}' | grep -q "^$name$"; then
        log.info "Removing container: ${BOLD_YELLOW}$name${RESET_COLOR}."
        if ${DOCKERO_RUNTIME:-docker} rm "$name" > /dev/null 2>&1; then
            log.done "Container '${BOLD_GREEN}$name${RESET_COLOR}' removed."
        else
            log.error "Failed to remove container: ${RED}$name${RESET_COLOR}."
            return 1
        fi
    else
        log.warn "Container ${BOLD_YELLOW}$name${RESET_COLOR} does not exist."
    fi

    log.info "Teardown completed for container: ${BOLD_GREEN}$name${RESET_COLOR}."
    return 0
}