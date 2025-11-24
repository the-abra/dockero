#!/usr/bin/env bash

# The explain function is in learn.sh but we need a separate file for the explain command
# Since the command loading system expects explain.sh for the explain command

# Source the learn functionality to reuse the explain function
source "${CORE_DIR}/commands/learn.sh"

# The explain command will be handled by the explain function in learn.sh
# This is just a placeholder that will call the function from learn.sh
explain() {
    # This function is implemented in learn.sh
    # The CORE_DIR should be available since we're sourced from dockero.sh
    # But we need to redefine the explain function here or call it differently
    
    # Actually, we just need to make sure the explain function from learn.sh gets called
    # This will be handled by the sourcing mechanism
    learn_explain_wrapper "$@"  # This won't work as I intended
}

# Actually, the right approach is to just call the explain function directly if loaded
# But since dockero sources the file and then calls the function by name,
# and the explain function is defined in the learn.sh file, I have a problem.
# I need to either:
# 1. Move explain to its own file, or
# 2. Handle explain differently

# Let me just implement explain in its own file
explain() {
    local command_to_explain="${args[1]}"

    if [[ -z "$command_to_explain" ]]; then
        log.hint "explain <command> [subcommand]"
        log.sub "Shows what a Dockero command does and the equivalent Docker commands"
        return 1
    fi
    
    log.setline "Command Explanation"
    
    case "$command_to_explain" in
        "run")
            cat << EOF
🔹 dockero run <name> [image]
   • Purpose: Start an existing container or create a new one
   • What happens: 
     1. Checks if container named '<name>' exists
     2. If exists: starts the container and attaches interactively
     3. If not exists: creates new container from image and runs it
   • Equivalent Docker: 
     docker start -ai <name>  (if container exists)
     docker run -it [default volumes/ports] --name <name> <image>
   • Learn more: dockero learn docker containers
EOF
            ;;
        "setup")
            cat << EOF
🔹 dockero setup <project-path>
   • Purpose: Set up a containerized development environment for a project
   • What happens:
     1. Finds .dockero configuration in project directory
     2. Parses configuration for image, volumes, ports, etc.
     3. Pulls image if needed
     4. Runs container with specified configuration
   • Equivalent Docker: 
     docker run -it [config from .dockero file] 
   • Learn more: dockero learn concepts volumes && dockero learn concepts networks
EOF
            ;;
        "compose")
            cat << EOF
🔹 dockero compose up
   • Purpose: Start multi-container applications defined in .dockero-compose
   • What happens:
     1. Reads .dockero-compose file for service definitions
     2. Resolves dependencies between services
     3. Creates and starts all defined services
   • Equivalent Docker: 
     docker-compose up  or  docker run with dependencies managed manually
   • Learn more: dockero learn concepts multi-container
EOF
            ;;
        "sync")
            cat << EOF
🔹 dockero sync <push|pull|watch|status|init> [args]
   • Purpose: Synchronize files between host and container
   • What happens:
     • push: Copies files from host to container
     • pull: Copies files from container to host  
     • watch: Monitors file changes and syncs automatically
     • status: Shows sync status information
     • init: Creates sync configuration
   • Equivalent Docker:
     docker cp for file copying
     docker exec for executing commands
   • Learn more: dockero learn concepts volumes
EOF
            ;;
        "env")
            cat << EOF
🔹 dockero env <list|use|show|create|delete> [env]
   • Purpose: Manage deployment environments (dev, staging, prod)
   • What happens:
     • Switches between different configuration sets
     • Loads environment-specific .dockero files
     • Maintains context between commands
   • Equivalent Docker:
     Different sets of parameters and configuration files
   • Learn more: dockero learn concepts configuration
EOF
            ;;
        *)
            log.info "Explanation for command: $command_to_explain"
            log.sub "This command provides functionality for Docker container management."
            log.sub "To see detailed explanation, check dockero learn concepts for related topics."
            ;;
    esac
}