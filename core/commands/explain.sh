#!/usr/bin/env bash

# The explain command will be handled by the explain function in this file
explain() {
    local command_to_explain="${1:-}" # Use function's first argument, safely
    
    local -a explainable_commands=(
        "run" "list" "rename" "export" "import" "start" "stop" "setup" "remove"
        "sync" "compose" "env" "validate" "system" "learn" "explain" "show"
        "net" "heal" "registry" "secrets" "monitor" "wizard" "dashboard" "help"
    )

    if [[ -z "$command_to_explain" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}explain <command> [subcommand]${RESET_COLOR}"
        log.sub "Shows what a Dockero command does and the equivalent Docker commands."
        log.sub "Currently explainable commands: ${BOLD_GREEN}$(echo "${explainable_commands[@]}" | tr ' ' ',')${RESET_COLOR}"
        return 0 # <--- Changed from return 1 to return 0
    fi
    
    log.setline "${BOLD_CYAN}Command Explanation: ${YELLOW}$command_to_explain${RESET_COLOR}"
    
    case "$command_to_explain" in
        "run")
            cat << EOF
${BOLD_CYAN}🔹 dockero run ${GREEN}<name> [<image>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Launch an existing container or create a new one.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<name>${RESET_COLOR}: Name of the container to start or create.
     - ${GREEN}[<image>]${RESET_COLOR}: Docker image to use if creating a new container (optional if <name> is an image).
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     1. Checks if a container named '${YELLOW}<name>${RESET_COLOR}' exists.
     2. If exists: starts the container and attaches interactively.
     3. If not exists: creates a new container from <image> (or <name> if image is omitted) and runs it.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker start -ai <name>${RESET_COLOR}  (if container exists)
     ${YELLOW}docker run -it [default volumes/ports] --name <name> <image>${RESET_COLOR}
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 1${RESET_COLOR}
EOF
            ;;
        "list")
            cat << EOF
${BOLD_CYAN}🔹 dockero list [-img]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} List all Docker containers or images.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}-img${RESET_COLOR}: List images instead of containers.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • Without '-img': Displays running and stopped containers with their names, images, status, ports, and IP addresses.
     • With '-img': Displays all local Docker images.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker ps -a${RESET_COLOR}  (for containers)
     ${YELLOW}docker images${RESET_COLOR} (for images)
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 2${RESET_COLOR}
EOF
            ;;
        "rename")
            cat << EOF
${BOLD_CYAN}🔹 dockero rename ${GREEN}<old-name> <new-name> [-img]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Rename an existing container or retag an image.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<old-name>${RESET_COLOR}: Current name of the container or image.
     - ${GREEN}<new-name>${RESET_COLOR}: Target name/tag.
     - ${GREEN}-img${RESET_COLOR}: Rename (tag) an image instead of a container.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • Without '-img': Renames a Docker container from <old-name> to <new-name>.
     • With '-img': Retags a Docker image from <old-tag> to <new-tag>. The old tag will still exist.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker rename <old-name> <new-name>${RESET_COLOR} (for containers)
     ${YELLOW}docker tag <old-tag> <new-tag>${RESET_COLOR} (for images)
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 1${RESET_COLOR}
EOF
            ;;
        "export")
            cat << EOF
${BOLD_CYAN}🔹 dockero export ${GREEN}<container-name> [--tag <image-tag>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Export a Docker container's current state as a .tar archive.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<container-name>${RESET_COLOR}: Name of the container to export.
     - ${GREEN}--tag <image-tag>${RESET_COLOR}: Optional tag for the committed image before saving.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     1. Commits the specified container to a new image.
     2. Saves that image as a .tar file (e.g., '\$HOME/<container-name>.tar').
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker commit <container-name> <image-tag>${RESET_COLOR}
     ${YELLOW}docker save -o <path>.tar <image-tag>${RESET_COLOR}
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 2${RESET_COLOR}
EOF
            ;;
        "import")
            cat << EOF
${BOLD_CYAN}🔹 dockero import ${GREEN}</path/to/archive.tar>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Import a .tar archive as a Docker image.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}</path/to/archive.tar>${RESET_COLOR}: Local filesystem path to the archive file.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • Loads one or more images from a .tar archive into the local Docker image store.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker load -i /path/to/archive.tar${RESET_COLOR}
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 2${RESET_COLOR}
EOF
            ;;
        "start")
            cat << EOF
${BOLD_CYAN}🔹 dockero start ${GREEN}<container-name> [-c <command>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Start an existing, stopped container. Optionally execute a command inside it.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<container-name>${RESET_COLOR}: Name of the stopped container to start.
     - ${GREEN}-c <command>${RESET_COLOR}: Optional command to execute inside the container after starting.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     1. Starts the specified container.
     2. If '-c <command>' is provided, executes the command inside the running container.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker start <container-name>${RESET_COLOR}
     ${YELLOW}docker exec -it <container-name> <command>${RESET_COLOR} (for custom command)
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "stop")
            cat << EOF
${BOLD_CYAN}🔹 dockero stop ${GREEN}<container-name> [--timeout <seconds>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Gracefully stop a running container.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${GREEN}<container-name>${RESET_COLOR}: Name of the running container to stop.
     - ${GREEN}--timeout <seconds>${RESET_COLOR}: Seconds to wait for stop before killing it (default: 10).
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • Sends a SIGTERM signal to the container, waits for a specified timeout, then sends SIGKILL if it hasn't stopped.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker stop --time=<seconds> <container-name>${RESET_COLOR}
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "setup")
            cat << EOF
${BOLD_CYAN}🔹 dockero setup ${GREEN}<project-path>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Set up a containerized development environment for a project.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     1. Finds .dockero configuration in project directory.
     2. Parses configuration for image, volumes, ports, etc.
     3. Pulls image if needed.
     4. Runs container with specified configuration.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker run -it [config from .dockero file]${RESET_COLOR} 
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "remove")
            cat << EOF
${BOLD_CYAN}🔹 dockero remove ${GREEN}<container|image>[:tag]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Remove a Docker container or image.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • If <container> (without ':tag'): Removes the specified container.
     • If <image>:<tag>: Removes the specified image.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker rm -f <container-name>${RESET_COLOR}
     ${YELLOW}docker rmi -f <image-name>:${RESET_COLOR}
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 1${RESET_COLOR}
EOF
            ;;
        "sync")
            cat << EOF
${BOLD_CYAN}🔹 dockero sync ${GREEN}<push|pull|watch|status|init> [path]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Synchronize files between host and container.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}push:${RESET_COLOR} Copies files from host to container.
     • ${YELLOW}pull:${RESET_COLOR} Copies files from container to host.  
     • ${YELLOW}watch:${RESET_COLOR} Monitors host directory for changes and syncs automatically (requires inotify-tools).
     • ${YELLOW}status:${RESET_COLOR} Shows synchronization status information for a container.
     • ${YELLOW}init:${RESET_COLOR} Creates a '.dockero-sync' configuration file for advanced sync rules.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker cp${RESET_COLOR} for file copying
     ${YELLOW}docker exec${RESET_COLOR} for executing commands (e.g., tar)
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 3${RESET_COLOR}
EOF
            ;;
        "compose")
            cat << EOF
${BOLD_CYAN}🔹 dockero compose ${GREEN}<up|down|start|stop|restart|ps|logs>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage multi-container applications defined in '.dockero-compose' files.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}up:${RESET_COLOR} Creates and starts all defined services.
     • ${YELLOW}down:${RESET_COLOR} Stops and removes all services.
     • ${YELLOW}start:${RESET_COLOR} Starts existing containers for all services.
     • ${YELLOW}stop:${RESET_COLOR} Stops all running services.
     • ${YELLOW}restart:${RESET_COLOR} Stops and starts all services.
     • ${YELLOW}ps:${RESET_COLOR} Shows status of all defined services.
     • ${YELLOW}logs [service]:${RESET_COLOR} Shows logs for all services or a specific service.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker-compose up/down/start/stop/ps/logs${RESET_COLOR}
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "env")
            cat << EOF
${BOLD_CYAN}🔹 dockero env ${GREEN}<list|use|show|create|delete> [environment]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage deployment environments (e.g., dev, staging, prod).
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}list:${RESET_COLOR} Lists available environments.
     • ${YELLOW}use <env>:${RESET_COLOR} Switches to the specified environment, loading its configurations.
     • ${YELLOW}show:${RESET_COLOR} Shows information about the current active environment.
     • ${YELLOW}create <env>:${RESET_COLOR} Creates a new environment with template configuration files.
     • ${YELLOW}delete <env>:${RESET_COLOR} Removes configuration files for the specified environment.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}Different sets of parameters and configuration files${RESET_COLOR} managed manually.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn intermediate${RESET_COLOR}
EOF
            ;;
        "validate")
            cat << EOF
${BOLD_CYAN}🔹 dockero validate ${GREEN}[path] [config-file]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Validate Dockero configuration files (.dockero, .dockero-compose).
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • Checks INI file structure, required fields, and format for container names, images, ports, and safe paths.
     • Can validate a specific file or all '.dockero*' files in a given path.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}Manual inspection of Dockerfile/docker-compose.yml${RESET_COLOR} for syntax and best practices.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "system")
            cat << EOF
${BOLD_CYAN}🔹 dockero system ${GREEN}<service|config|info|cleanup|install> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} System integration and management for Dockero.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}service:${RESET_COLOR} Manage containers as systemd services (create, start, stop, enable, disable, status).
     • ${YELLOW}config:${RESET_COLOR} Manage Dockero's own system configuration (get, set, list, reset).
     • ${YELLOW}info:${RESET_COLOR} Display system information and Dockero environment status.
     • ${YELLOW}cleanup:${RESET_COLOR} Cleanup Docker resources (containers, images, volumes, networks, temp files).
     • ${YELLOW}install:${RESET_COLOR} Install Dockero to a system location.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker system prune${RESET_COLOR}, ${YELLOW}docker info${RESET_COLOR}, ${YELLOW}systemctl/service commands${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "learn")
            cat << EOF
${BOLD_CYAN}🔹 dockero learn ${GREEN}<start|basic|intermediate|advanced|docker|concepts|examples> [topic]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Interactive learning system for Docker concepts and Dockero usage.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • Provides structured lessons on Docker basics (containers, images, volumes), intermediate (networks, environment), advanced (security), and specific concepts (multi-container, lifecycle).
     • Includes examples for practical application.
   ${BOLD_WHITE}• • Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}Docker documentation, tutorials, and online courses${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn start${RESET_COLOR}
EOF
            ;;
        "explain")
            cat << EOF
${BOLD_CYAN}🔹 dockero explain ${GREEN}<command>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Shows detailed explanation of what a Dockero command does.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • Provides a summary of the command's purpose, what actions it performs, and its equivalent standard Docker commands.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker <command> --help${RESET_COLOR} combined with conceptual understanding.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn${RESET_COLOR}
EOF
            ;;
        "show")
            cat << EOF
${BOLD_CYAN}🔹 dockero show ${GREEN}<commands|dashboard|demo|visual|containers|status> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Provides visual dashboards, command references, demonstrations, and concept visualizations.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}commands:${RESET_COLOR} Displays a categorized list of all Dockero commands.
     • ${YELLOW}dashboard:${RESET_COLOR} Shows a quick overview of Docker system status and common actions.
     • ${YELLOW}demo <command>:${RESET_COLOR} Provides interactive demonstrations of specific commands.
     • ${YELLOW}visual <element>:${RESET_COLOR} Visualizes Docker concepts like containers, networks, or the setup process.
     • ${YELLOW}containers:${RESET_COLOR} Shows a visual dashboard of all containers with status.
     • ${YELLOW}status:${RESET_COLOR} Comprehensive system status overview.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}Multiple 'docker' commands and manual data correlation${RESET_COLOR} for system overview.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero show dashboard${RESET_COLOR}
EOF
            ;;
        "net")
            cat << EOF
${BOLD_CYAN}🔹 dockero net ${GREEN}<command> [<args>]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage Docker networks.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}new/create <name>:${RESET_COLOR} Creates a new Docker network.
     • ${YELLOW}delete <name>:${RESET_COLOR} Removes a Docker network.
     • ${YELLOW}add/connect <container> <network>:${RESET_COLOR} Connects a container to a network.
     • ${YELLOW}remove/disconnect <container> <network>:${RESET_COLOR} Disconnects a container from a network.
     • ${YELLOW}rename <old> <new>:${RESET_COLOR} Renames a network (by creating new and re-connecting containers).
     • ${YELLOW}prune:${RESET_COLOR} Removes all unused Docker networks.
     • ${YELLOW}list:${RESET_COLOR} Displays all Docker networks with connected containers.
     • ${YELLOW}inspect <name>:${RESET_COLOR} Shows detailed information for a network.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker network create/rm/connect/disconnect/prune/ls/inspect${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn intermediate 1${RESET_COLOR}
EOF
            ;;
        "heal")
            cat << EOF
${BOLD_CYAN}🔹 dockero heal ${GREEN}<check|fix|auto|diagnose|cleanup|restore|watch|policy> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Self-healing automation system for Dockero.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}check [target]:${RESET_COLOR} Performs health checks (system, containers, networks).
     • ${YELLOW}fix <target> [item]:${RESET_COLOR} Automatically fixes identified issues (containers, images, volumes, system).
     • ${YELLOW}auto:${RESET_COLOR} Runs automated health check and applies fixes.
     • ${YELLOW}diagnose <type>:${RESET_COLOR} Deep diagnosis for specific issues (startup, network, performance).
     • ${YELLOW}cleanup [target]:${RESET_COLOR} Proactively cleans up Docker resources (containers, images, volumes, networks, temp).
     • ${YELLOW}restore <target>:${RESET_COLOR} Restores environment to expected configuration state (config, workspace, containers).
     • ${YELLOW}watch <target>:${RESET_COLOR} Real-time monitoring of system components.
     • ${YELLOW}policy <action> [type]:${RESET_COLOR} Manages health policies and automated rules.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}Manual execution of various 'docker' and system commands${RESET_COLOR} for troubleshooting and maintenance.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn advanced${RESET_COLOR} (as related to system health)
EOF
            ;;
        "registry")
            cat << EOF
${BOLD_CYAN}🔹 dockero registry ${GREEN}<login|push|pull|list|search|logout> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage Docker container registries (e.g., Docker Hub).
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}login [url]:${RESET_COLOR} Authenticates to a registry.
     • ${YELLOW}logout [url]:${RESET_COLOR} Removes local authentication credentials.
     • ${YELLOW}push <image>:${RESET_COLOR} Uploads an image to a registry.
     • ${YELLOW}pull <image>:${RESET_COLOR} Downloads an image from a registry.
     • ${YELLOW}search <term>:${RESET_COLOR} Searches registries (e.g., Docker Hub) for images.
     • ${YELLOW}list:${RESET_COLOR} Lists images in a registry (note: direct listing from Docker API not supported).
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker login/logout/push/pull/search${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn basics 2${RESET_COLOR}
EOF
            ;;
        "secrets")
            cat << EOF
${BOLD_CYAN}🔹 dockero secrets ${GREEN}<create|list|show|remove> <name> [source]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage Docker secrets (sensitive data like passwords, API keys).
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}create <name> [source]:${RESET_COLOR} Creates a secret from a file or standard input.
     • ${YELLOW}list:${RESET_COLOR} Lists all Docker secrets.
     • ${YELLOW}show <name>:${RESET_COLOR} Displays details about a secret (metadata only, not the secret value).
     • ${YELLOW}remove <name>:${RESET_COLOR} Removes a secret (requires confirmation).
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker secret create/ls/inspect/rm${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn advanced${RESET_COLOR}
EOF
            ;;
        "monitor")
            cat << EOF
${BOLD_CYAN}🔹 dockero monitor ${GREEN}<top|stats|health|logs|watch> [options]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Provides various monitoring functionalities for Docker containers.
   ${BOLD_WHITE}• Parameters:${RESET_COLOR}
     - ${YELLOW}top [container]:${RESET_COLOR} Show processes in a container.
     - ${YELLOW}stats [container] [-f]:${RESET_COLOR} Resource usage stats. ${GREEN}-f${RESET_COLOR} for live stream.
     - ${YELLOW}health [container]:${RESET_COLOR} Check container health status.
     - ${YELLOW}logs <container> [-f] [-t <lines>]:${RESET_COLOR} View logs. ${GREEN}-f${RESET_COLOR} to follow, ${GREEN}-t${RESET_COLOR} for tail.
     - ${YELLOW}watch [container] [--interval <s>] [--duration <s>]:${RESET_COLOR} Continuous monitoring.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • ${YELLOW}top [container]:${RESET_COLOR} Shows running processes in a container.
     • ${YELLOW}stats [container]:${RESET_COLOR} Displays resource usage statistics (CPU, memory, etc.).
     • ${YELLOW}health [container]:${RESET_COLOR} Checks container health status.
     • ${YELLOW}logs <container> [-f -t]:${RESET_COLOR} Views container logs.
     • ${YELLOW}watch [container] [--interval --duration]:${RESET_COLOR} Continuously monitors container statistics.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker top/stats/inspect/logs${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn advanced${RESET_COLOR}
EOF
            ;;
        "wizard")
            cat << EOF
${BOLD_CYAN}🔹 dockero wizard ${GREEN}[start|setup|init|quickstart|beginner]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Interactive setup assistant for beginners.
   ${BOLD_WHITE}• What happens:${RESET_COLOR} 
     • Guides users through common Docker/Dockero use cases like setting up web servers, development environments, or databases.
     • Detects project types and helps create appropriate configuration files.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}Manual setup and configuration of Docker environments${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero learn start${RESET_COLOR}
EOF
            ;;
        "dashboard")
            cat << EOF
${BOLD_CYAN}🔹 dockero dashboard${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Display a quick overview of Docker system status.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     1. Checks if the Docker daemon is active.
     2. Collects container statistics (running, total, images).
     3. Lists currently running containers with their status.
     4. Suggests quick actions and displays Dockero system information.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker ps -a${RESET_COLOR}, ${YELLOW}docker images${RESET_COLOR}, and ${YELLOW}docker info${RESET_COLOR} combined.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero show dashboard${RESET_COLOR}
EOF
            ;;
        "help")
            cat << EOF
${BOLD_CYAN}🔹 dockero help [command]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Show usage information and a list of all available commands.
   ${BOLD_WHITE}• What happens:${RESET_COLOR}
     • If no command is provided, displays a general help menu with categorized command listings.
     • If a command is provided, it calls 'explain' to provide a detailed explanation of that specific command.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR} 
     ${YELLOW}docker help${RESET_COLOR} or ${YELLOW}docker <command> --help${RESET_COLOR}.
   ${BOLD_WHITE}• Learn more:${RESET_COLOR} ${MAGENTA}dockero explain help${RESET_COLOR}
EOF
            ;;
        *)
            log.warn "No specific explanation found for '${BOLD_YELLOW}$command_to_explain${RESET_COLOR}'."
            log.sub "This command provides functionality for Docker container management."
            log.sub "To see detailed explanation, check ${MAGENTA}dockero learn${RESET_COLOR} for related topics."
            ;;
    esac
}