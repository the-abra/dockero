#!/usr/bin/env bash

# Source helper for regex escaping
# shellcheck disable=SC1091
source "${CORE_DIR}/extra/inipars.sh"

show() {
    local subcommand="${args[1]:-}" # Safely access args[1]
    
    if [[ -z "$subcommand" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero show <commands|dashboard|demo|visual|containers|status> [options]${RESET_COLOR}"
        return 1
    fi
    
    case "$subcommand" in
        "commands"|"list")
            show_commands "${args[2]:-}"
            ;;
        "dashboard")
            show_dashboard
            ;;
        "demo")
            show_demo "${args[@]:2}" # Pass all remaining args to demo
            ;;
        "visual")
            show_visual "${args[@]:2}" # Pass all remaining args to visual
            ;;
        "containers")
            show_containers_visual
            ;;
        "status")
            show_status_visual
            ;;
        *)
            log.error "Unknown show subcommand: ${BOLD_RED}$subcommand${RESET_COLOR}"
            log.hint "Usage: ${BOLD_YELLOW}dockero show <commands|dashboard|demo|visual|containers|status> [options]${RESET_COLOR}"
            return 1
            ;;
    esac
}

show_commands() {
    local filter="$1"
    local escaped_filter=""

    if [[ -n "$filter" ]]; then
        escaped_filter=$(_inipars_escape_regex "$filter")
    fi
    
    log.setline "${BOLD_CYAN}📊 Dockero Command Dashboard${RESET_COLOR}"
    
    # Define command categories with icons and descriptions
    local -a categories=(
        "🚀 Quick Start:run,list,start,stop"
        "⚙️  Container Management:setup,create,remove,rename"
        "🔗 Networking:net,compose"
        "🔄 Sync & Data:sync,export,import"
        "🌍 Environment:env,system"
        "📚 Learning:learn,explain,validate"
        "📊 Monitoring:show,monitor,heal,registry,secrets,wizard" # Added monitor, heal, registry, secrets, wizard
    )
    
    for category_entry in "${categories[@]}"; do
        local cat_name="${category_entry%%:*}"
        local cat_commands="${category_entry#*:}"
        
        # Use escaped_filter in the regex comparison
        if [[ -n "$escaped_filter" ]] && ! [[ "$cat_name" =~ $escaped_filter ]]; then
            continue
        fi
        
        echo ""
        log.info "${BOLD_WHITE}$cat_name${RESET_COLOR}"
        
        IFS=',' read -ra cmds <<< "$cat_commands"
        for cmd in "${cmds[@]}"; do
            local desc=""
            case "$cmd" in
                "run") desc="Create and start containers" ;;
                "list") desc="List containers and images" ;;
                "start") desc="Start containers" ;;
                "stop") desc="Stop containers" ;;
                "setup") desc="Project container setup" ;;
                "create") desc="Create resource (e.g., secrets)" ;;
                "remove") desc="Remove containers/images" ;;
                "rename") desc="Rename containers/images" ;;
                "net") desc="Manage Docker networks" ;;
                "compose") desc="Multi-container apps" ;;
                "sync") desc="File synchronization" ;;
                "export") desc="Export containers as archives" ;;
                "import") desc="Import archives as images" ;;
                "env") desc="Environment management" ;;
                "system") desc="System integration & management" ;;
                "learn") desc="Docker learning system" ;;
                "explain") desc="Command explanations" ;;
                "validate") desc="Validate configurations" ;;
                "show") desc="Visual command dashboard" ;;
                "monitor") desc="Container monitoring and metrics" ;;
                "heal") desc="Self-healing automation system" ;;
                "registry") desc="Container registry management" ;;
                "secrets") desc="Manage sensitive data" ;;
                "wizard") desc="Interactive setup assistant" ;;
                *) desc="Docker command" ;;
            esac
            log.sub "  ${BOLD_GREEN}dockero $cmd${RESET_COLOR} - ${CYAN}$desc${RESET_COLOR}"
        done
    done
    
    echo ""
    log.info "💡 Tip: Use '${BOLD_YELLOW}dockero explain <command>${RESET_COLOR}' for detailed information."
    log.info "📚 Use '${BOLD_YELLOW}dockero learn basic${RESET_COLOR}' to start learning Docker."
}

show_dashboard() {
    # Explicitly source the dashboard function from the dedicated file
    # shellcheck disable=SC1091
    source "${COMMANDS_DIR}/dashboard.sh"
    dashboard
}

show_demo() {
    local command_to_demo="${1:-}"

    if [[ -z "$command_to_demo" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero show demo <command>${RESET_COLOR}"
        local -a available_demos=("run" "setup" "sync")
        log.sub "Interactive demonstration of Dockero commands. Available demos: ${BOLD_GREEN}$(echo "${available_demos[@]}" | tr ' ' ',')${RESET_COLOR}"
        return 1
    fi

    log.setline "${BOLD_CYAN}🎬 Command Demonstration: ${GREEN}$command_to_demo${RESET_COLOR}"

    case "$command_to_demo" in
        "run")
            cat << EOF
${BOLD_BLUE}DEMO: dockero run${RESET_COLOR}
${YELLOW}Scenario:${RESET_COLOR} Starting a web server container.

${BOLD_GREEN}dockero run web-server nginx:alpine${RESET_COLOR}

${BOLD_YELLOW}What happens:${RESET_COLOR}
  1. Checks if '${YELLOW}web-server${RESET_COLOR}' container exists.
     -> If yes: starts it.
     -> If no: creates from ${YELLOW}nginx:alpine${RESET_COLOR}.
  2. Sets up standard volumes and ports.
  3. Attaches to container for interaction.
  4. Container starts running.

${BOLD_YELLOW}Alternative:${RESET_COLOR}
${BOLD_GREEN}dockero run my-app node:16${RESET_COLOR} # Create new container.
EOF
            ;;
        "setup")
            cat << EOF
${BOLD_BLUE}DEMO: dockero setup${RESET_COLOR}
${YELLOW}Scenario:${RESET_COLOR} Setting up a development environment.

${BOLD_GREEN}dockero setup ./my-project${RESET_COLOR}

${BOLD_YELLOW}Prerequisites:${RESET_COLOR}
- .dockero file in project directory:
  ${YELLOW}[default]
  name = my-project-dev
  image = node:16
  [volumes]
  env = .:/workspace${RESET_COLOR}

${BOLD_YELLOW}What happens:${RESET_COLOR}
  1. Reads .dockero configuration.
  2. Pulls ${YELLOW}node:16${RESET_COLOR} image (if needed).
  3. Creates container with workspace mapping.
  4. Starts container with config settings.
  5. Connects to container terminal.

${BOLD_YELLOW}Alternative commands:${RESET_COLOR}
${BOLD_GREEN}dockero setup init .${RESET_COLOR}    # Create config file.
${BOLD_GREEN}dockero setup update .${RESET_COLOR}  # Modify config.
${BOLD_GREEN}dockero setup run .${RESET_COLOR}    # Execute setup.
EOF
            ;;
        "sync")
            cat << EOF
${BOLD_BLUE}DEMO: dockero sync${RESET_COLOR}
${YELLOW}Scenario:${RESET_COLOR} Synchronizing files between host and container.

${BOLD_GREEN}dockero sync push web-server${RESET_COLOR}

${BOLD_YELLOW}What happens:${RESET_COLOR}
  1. Takes current directory contents.
  2. Creates temporary archive.
  3. Copies to container at /workspace.
  4. Extracts files in container.

${BOLD_YELLOW}Other sync operations:${RESET_COLOR}
${BOLD_GREEN}dockero sync pull web-server${RESET_COLOR}    # Get files from container.
${BOLD_GREEN}dockero sync watch web-server${RESET_COLOR}   # Auto-sync on file changes.
${BOLD_GREEN}dockero sync status web-server${RESET_COLOR}  # Check sync status.

${BOLD_YELLOW}Use case:${RESET_COLOR} Live development where you edit on host but run in container.
EOF
            ;;
        *)
            log.warn "No demonstration available for: ${BOLD_YELLOW}$command_to_demo${RESET_COLOR}."
            local -a available_demos=("run" "setup" "sync")
            log.sub "Available demos: ${BOLD_GREEN}$(echo "${available_demos[@]}" | tr ' ' ',')${RESET_COLOR}"
            ;;
    esac
}

show_visual() {
    local element="${1:-}"
    
    if [[ -z "$element" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero show visual <element>${RESET_COLOR}"
        local -a available_elements=("container" "network" "setup")
        log.sub "Visual representations: ${BOLD_GREEN}$(echo "${available_elements[@]}" | tr ' ' ',')${RESET_COLOR}"
        return 1
    fi
    
    case "$element" in
        "container"|"containers")
            show_container_visual
            ;;
        "network"|"networks")
            show_network_visual
            ;;
        "setup")
            show_setup_visual
            ;;
        *)
            log.warn "Unknown visual element: ${BOLD_YELLOW}$element${RESET_COLOR}."
            local -a available_elements=("container" "network" "setup")
            log.sub "Available: ${BOLD_GREEN}$(echo "${available_elements[@]}" | tr ' ' ',')${RESET_COLOR}"
            return 1
            ;;
    esac
}

show_container_visual() {
    log.setline "${BOLD_CYAN}🖼️ Container Visualization${RESET_COLOR}"

    cat << EOF

${BOLD_YELLOW}Docker Container Structure${RESET_COLOR}

${BOLD_WHITE}[ Host System ]${RESET_COLOR}
    ${GREEN}|${RESET_COLOR}
    ${GREEN}| Mounts/Ports${RESET_COLOR}
    ${GREEN}v${RESET_COLOR}
${BOLD_WHITE}[ Docker Container ]${RESET_COLOR}
    ${GREEN}|${RESET_COLOR}
    ${GREEN}|-- [ App Files: app.js, package.json ]${RESET_COLOR}
    ${GREEN}|-- [ Runtime: Node.js v16, Dependencies ]${RESET_COLOR}
    ${GREEN}|-- [ Isolated Space: Process, Network, FS ]${RESET_COLOR}

${BOLD_YELLOW}Key Features:${RESET_COLOR}
  ${CYAN}Isolated:${RESET_COLOR} Separate process space
  ${CYAN}Portable:${RESET_COLOR} Same everywhere
  ${CYAN}Lightweight:${RESET_COLOR} No full OS overhead
  ${CYAN}Immutable:${RESET_COLOR} Built from base image

EOF
}

show_network_visual() {
    log.setline "${BOLD_CYAN}🖼️ Network Visualization${RESET_COLOR}"

    cat << EOF

${BOLD_YELLOW}Container Networking${RESET_COLOR}

${BOLD_GREEN}Single Container:${RESET_COLOR}
${BOLD_WHITE}[ Host: localhost:80 ]${RESET_COLOR} <---> ${BOLD_WHITE}[ Container: app:80 ]${RESET_COLOR}

${BOLD_GREEN}Multi-Container:${RESET_COLOR}
${BOLD_WHITE}[ Web App:3000 ]${RESET_COLOR} <---> ${BOLD_WHITE}[ Database:5432 ]${RESET_COLOR}
      ${GREEN}|${RESET_COLOR}
      ${GREEN}+---------> [ Cache:6379 ]${RESET_COLOR}

EOF
}

show_setup_visual() {
    log.setline "${BOLD_CYAN}🖼️ Setup Process Visualization${RESET_COLOR}"

    cat << EOF

${BOLD_YELLOW}Dockero Setup Process${RESET_COLOR}

${BOLD_GREEN}Step 1: Configuration${RESET_COLOR}
${BOLD_WHITE}[ Project Directory ]${RESET_COLOR} --> ${BOLD_WHITE}[ .dockero file ]${RESET_COLOR}
                           ${YELLOW}name = my-app${RESET_COLOR}
                           ${YELLOW}image = node:16${RESET_COLOR}
                           ${YELLOW}env = .:/app${RESET_COLOR}

${BOLD_GREEN}Step 2: Container Creation${RESET_COLOR}
${BOLD_WHITE}[ .dockero data ]${RESET_COLOR} --> ${BOLD_WHITE}[ Docker run ]${RESET_COLOR}
      ${GREEN}|${RESET_COLOR}                   ${GREEN}|${RESET_COLOR}
      ${GREEN}v${RESET_COLOR}                   ${GREEN}v${RESET_COLOR}
${BOLD_WHITE}[ Final Container: my-app, node:16, .:/app ]${RESET_COLOR}

EOF
}

show_containers_visual() {
    log.setline "${BOLD_CYAN}📊 Container Status Dashboard${RESET_COLOR}"
    
    local containers_output
    containers_output=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
    
    if [[ -n "$containers_output" ]]; then
        echo "$containers_output" | sed '1s/.*/\033[1;36m&\033[0m/' # Color header
    else
        log.info "No containers found."
        log.sub "Create a container with: ${BOLD_YELLOW}dockero run <name> <image>${RESET_COLOR}"
    fi
}

show_status_visual() {
    log.setline "${BOLD_CYAN}🔍 System Status Overview${RESET_COLOR}"
    
    # Check Docker daemon
    if command -v docker &> /dev/null && docker ps -q &> /dev/null; then # Faster check
        # shellcheck disable=SC2059
        printf "${GREEN}✓ Docker daemon:${RESET_COLOR} ${BOLD_GREEN}Running${RESET_COLOR}\n"
    else
        # shellcheck disable=SC2059
        printf "${RED}✗ Docker daemon:${RESET_COLOR} ${BOLD_RED}Not running${RESET_COLOR}\n"
    fi
    
    # Count containers
    local total_containers
    total_containers=$(docker ps -a -q | wc -l 2>/dev/null || echo 0)
    local running_containers
    running_containers=$(docker ps -q | wc -l 2>/dev/null || echo 0)
    
    # shellcheck disable=SC2059
    printf "${BOLD_WHITE}📦 Containers:${RESET_COLOR} ${BOLD_GREEN}${total_containers:-0}${RESET_COLOR} total (${BOLD_YELLOW}${running_containers:-0}${RESET_COLOR} running)\n"
    
    # Count images  
    local total_images
    total_images=$(docker images -q | wc -l 2>/dev/null || echo 0)
    # shellcheck disable=SC2059
    printf "${BOLD_WHITE}📚 Images:${RESET_COLOR} ${BOLD_GREEN}${total_images:-0}${RESET_COLOR} available\n"
    
    # Disk usage if available
    if command -v docker &> /dev/null; then
        local disk_usage
        disk_usage=$(docker system df -q 2>/dev/null | grep "Local Images" | awk '{print $3}' 2>/dev/null || echo "N/A")
        # shellcheck disable=SC2059
    printf "${BOLD_WHITE}💾 Disk usage:${RESET_COLOR} ${BOLD_YELLOW}$disk_usage${RESET_COLOR}\n"
    fi
    
    echo ""
    log.info "💡 Quick actions:"
    log.sub "  ${BOLD_GREEN}dockero run <name> <image>${RESET_COLOR}    # Create container"
    log.sub "  ${BOLD_GREEN}dockero list${RESET_COLOR}                    # View containers" 
    log.sub "  ${BOLD_GREEN}dockero learn start${RESET_COLOR}           # Docker learning"
}