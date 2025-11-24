#!/usr/bin/env bash

show() {
    local subcommand="${args[1]}"
    
    if [[ -z "$subcommand" ]] || [[ "$subcommand" != "commands" && "$subcommand" != "dashboard" && "$subcommand" != "demo" && "$subcommand" != "visual" && "$subcommand" != "containers" && "$subcommand" != "status" ]]; then
        log.hint "show <commands|dashboard|demo|visual|containers|status> [options]"
        return 1
    fi
    
    case "$subcommand" in
        "commands"|"list")
            show_commands "${args[2]}"
            ;;
        "dashboard")
            show_dashboard
            ;;
        "demo")
            show_demo "${args[2]}"
            ;;
        "visual")
            show_visual "${args[2]}"
            ;;
        "containers")
            show_containers_visual
            ;;
        "status")
            show_status_visual
            ;;
        *)
            log.error "Unknown show subcommand: $subcommand"
            return 1
            ;;
    esac
}

show_commands() {
    local filter="$1"
    
    log.setline "📊 Dockero Command Dashboard"
    
    # Define command categories with icons and descriptions
    local categories=(
        "🚀 Quick Start:run,list,start,stop"
        "⚙️  Container Management:setup,create,remove,rename"
        "🔗 Networking:net,compose"
        "🔄 Sync & Data:sync,export,import"
        "🌍 Environment:env,system"
        "📚 Learning:learn,explain,validate"
        "📊 Monitoring:show"
    )
    
    for category in "${categories[@]}"; do
        local cat_name="${category%%:*}"
        local cat_commands="${category#*:}"
        
        if [[ -n "$filter" && "$cat_name" != *"$filter"* ]]; then
            continue
        fi
        
        echo
        log.info "$cat_name"
        
        IFS=',' read -ra cmds <<< "$cat_commands"
        for cmd in "${cmds[@]}"; do
            # Get a short description for each command
            local desc=""
            case "$cmd" in
                "run") desc="Create and start containers" ;;
                "list") desc="List containers and images" ;;
                "setup") desc="Project container setup" ;;
                "sync") desc="File synchronization" ;;
                "compose") desc="Multi-container apps" ;;
                "env") desc="Environment management" ;;
                "learn") desc="Docker learning system" ;;
                "explain") desc="Command explanations" ;;
                "show") desc="Visual command dashboard" ;;
                "system") desc="System integration" ;;
                *) desc="Docker command" ;;
            esac
            log.sub "  dockero $cmd - $desc"
        done
    done
    
    echo
    log.info "💡 Tip: Use 'dockero explain <command>' for detailed information"
    log.info "📚 Use 'dockero learn basic' to start learning Docker"
}

show_dashboard() {
    log.setline "📊 Dockero Command Dashboard"
    
    # Show system status
    local docker_status="(not running)"
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        docker_status="✓ Running"
    else
        docker_status="✗ Not available" 
    fi
    
    echo
    printf "${BOLD_YELLOW}System Status${RESET_COLOR}\n"
    printf "  Docker: %s\n" "$docker_status"
    printf "  Dockero: v$DOCKERO_VERSION\n"
    
    # Count containers
    local total_containers=$(docker ps -a -q | wc -l)
    local running_containers=$(docker ps -q | wc -l)
    
    if [[ "$total_containers" -gt 0 ]]; then
        printf "  Containers: %s total, %s running\n" "$total_containers" "$running_containers"
    fi
    
    echo
    printf "${BOLD_YELLOW}Getting Started${RESET_COLOR}\n"
    printf "  ${GREEN}dockero run${RESET_COLOR} <name> [image]         ${CYAN}# Create/start containers${RESET_COLOR}\n"
    printf "  ${GREEN}dockero setup${RESET_COLOR} <path>            ${CYAN}# Project setup${RESET_COLOR}\n" 
    printf "  ${GREEN}dockero list${RESET_COLOR}                    ${CYAN}# View containers${RESET_COLOR}\n"
    printf "  ${GREEN}dockero learn basic${RESET_COLOR}            ${CYAN}# Start Docker learning${RESET_COLOR}\n"
    
    echo  
    printf "${BOLD_YELLOW}Popular Commands${RESET_COLOR}\n"
    printf "  ${GREEN}dockero compose up${RESET_COLOR}             ${CYAN}# Start multi-container${RESET_COLOR}\n"
    printf "  ${GREEN}dockero sync push${RESET_COLOR} <c>          ${CYAN}# Sync files${RESET_COLOR}\n"
    printf "  ${GREEN}dockero env list${RESET_COLOR}              ${CYAN}# View environments${RESET_COLOR}\n"
    printf "  ${GREEN}dockero explain run${RESET_COLOR}           ${CYAN}# Command explanations${RESET_COLOR}\n"
    
    echo
    log.info "🔍 Use 'dockero show commands' for full command reference"
    log.info "🎓 Use 'dockero learn start' to begin Docker journey"
}

show_demo() {
    local command_to_demo="$1"

    if [[ -z "$command_to_demo" ]]; then
        log.hint "show demo <command> [subcommand]"
        log.sub "Interactive demonstration of Dockero commands"
        return 1
    fi

    log.setline "Command Demonstration: $command_to_demo"

    case "$command_to_demo" in
        "run")
            echo -e "${BOLD_BLUE}DEMO: dockero run${RESET_COLOR}"
            echo
            echo -e "${YELLOW}Scenario:${RESET_COLOR} Starting a web server container"
            echo
            echo -e "${GREEN}dockero run web-server nginx:alpine${RESET_COLOR}"
            echo
            echo -e "${YELLOW}What happens:${RESET_COLOR}"
            echo "  1. Checks if 'web-server' container exists"
            echo "     -> If yes: starts it"
            echo "     -> If no: creates from nginx:alpine"
            echo "  2. Sets up standard volumes and ports  "
            echo "  3. Attaches to container for interaction"
            echo "  4. Container starts running"
            echo
            echo -e "${YELLOW}Alternative:${RESET_COLOR}"
            echo -e "${GREEN}dockero run my-app node:16${RESET_COLOR} # Create new container"
            echo
            ;;
        "setup")
            echo -e "${BOLD_BLUE}DEMO: dockero setup${RESET_COLOR}"
            echo
            echo -e "${YELLOW}Scenario:${RESET_COLOR} Setting up development environment"
            echo
            echo -e "${GREEN}dockero setup ./my-project${RESET_COLOR}"
            echo
            echo -e "${YELLOW}Prerequisites:${RESET_COLOR}"
            echo "- .dockero file in project directory:"
            echo "  [default]"
            echo "  name = my-project-dev"
            echo "  image = node:16"
            echo "  [volumes]"
            echo "  env = .:/workspace"
            echo
            echo -e "${YELLOW}What happens:${RESET_COLOR}"
            echo "  1. Reads .dockero configuration"
            echo "  2. Pulls node:16 image (if needed)"
            echo "  3. Creates container with workspace mapping"
            echo "  4. Starts container with config settings"
            echo "  5. Connects to container terminal"
            echo
            echo -e "${YELLOW}Alternative commands:${RESET_COLOR}"
            echo -e "${GREEN}dockero setup init .${RESET_COLOR}    # Create config file"
            echo -e "${GREEN}dockero setup update .${RESET_COLOR}  # Modify config"
            echo -e "${GREEN}dockero setup run .${RESET_COLOR}    # Execute setup"
            echo
            ;;
        "sync")
            echo -e "${BOLD_BLUE}DEMO: dockero sync${RESET_COLOR}"
            echo
            echo -e "${YELLOW}Scenario:${RESET_COLOR} Synchronizing files between host and container"
            echo
            echo -e "${GREEN}dockero sync push web-server${RESET_COLOR}"
            echo
            echo -e "${YELLOW}What happens:${RESET_COLOR}"
            echo "  1. Takes current directory contents"
            echo "  2. Creates temporary archive"
            echo "  3. Copies to container at /workspace"
            echo "  4. Extracts files in container"
            echo
            echo -e "${YELLOW}Other sync operations:${RESET_COLOR}"
            echo -e "${GREEN}dockero sync pull web-server${RESET_COLOR}    # Get files from container"
            echo -e "${GREEN}dockero sync watch web-server${RESET_COLOR}   # Auto-sync on file changes"
            echo -e "${GREEN}dockero sync status web-server${RESET_COLOR}  # Check sync status"
            echo
            echo -e "${YELLOW}Use case:${RESET_COLOR} Live development where you edit on host but run in container"
            echo
            ;;
        "")
            echo -e "${BOLD_BLUE}Dockero Command Demonstrations${RESET_COLOR}"
            echo
            echo -e "${GREEN}dockero show demo run${RESET_COLOR}      -> Basic container operations"
            echo -e "${GREEN}dockero show demo setup${RESET_COLOR}    -> Project environment setup"
            echo -e "${GREEN}dockero show demo sync${RESET_COLOR}     -> File synchronization"
            echo
            echo "💡 Run 'dockero show demo <command>' to see interactive demonstration"
            echo "🎓 Try 'dockero learn basic containers' to understand concepts first"
            echo
            ;;
        *)
            log.info "No demonstration available for: $command_to_demo"
            log.sub "Available demos: run, setup, sync"
            ;;
    esac
}

show_visual() {
    local element="$1"
    
    if [[ -z "$element" ]]; then
        log.hint "show visual <element>"
        log.sub "Visual representations: container, network, volume, setup"
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
            log.info "Unknown visual element: $element"
            log.sub "Available: container, network, setup"
            ;;
    esac
}

show_container_visual() {
    log.setline "Container Visualization"

    cat << EOF

${BOLD_YELLOW}Docker Container Structure${RESET_COLOR}

[ Host System ]
    |
    | Mounts/Ports
    v
[ Docker Container ]
    |
    |-- [ App Files: app.js, package.json ]
    |-- [ Runtime: Node.js v16, Dependencies ]
    |-- [ Isolated Space: Process, Network, FS ]

${YELLOW}Key Features:${RESET_COLOR}
  Isolated: Separate process space
  Portable: Same everywhere
  Lightweight: No full OS overhead
  Immutable: Built from base image

EOF
}

show_network_visual() {
    log.setline "Network Visualization"

    cat << EOF

${BOLD_YELLOW}Container Networking${RESET_COLOR}

${BOLD_GREEN}Single Container:${RESET_COLOR}
[ Host: localhost:80 ] <---> [ Container: app:80 ]

${BOLD_GREEN}Multi-Container:${RESET_COLOR}
[ Web App:3000 ] <---> [ Database:5432 ]
      |
      +-------> [ Cache:6379 ]

EOF
}

show_setup_visual() {
    log.setline "Setup Process Visualization"

    cat << EOF

${BOLD_YELLOW}Dockero Setup Process${RESET_COLOR}

${BOLD_GREEN}Step 1: Configuration${RESET_COLOR}
[ Project Directory ] --> [ .dockero file ]
                           name = my-app
                           image = node:16
                           env = .:/app

${BOLD_GREEN}Step 2: Container Creation${RESET_COLOR}
[ .dockero data ] --> [ Docker run ]
      |                   |
      v                   v
[ Final Container: my-app, node:16, .:/app ]

EOF
}

show_containers_visual() {
    log.setline "📊 Container Status Dashboard"
    
    local containers_output=$(docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
    
    if [[ -n "$containers_output" ]]; then
        echo "$containers_output"
    else
        log.info "No containers found"
        log.sub "Create a container with: dockero run <name> <image>"
    fi
}

show_status_visual() {
    log.setline "🔍 System Status Overview"
    
    # Check Docker daemon
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        printf "${GREEN}✓${RESET_COLOR} Docker daemon: ${BOLD_GREEN}Running${RESET_COLOR}\n"
    else
        printf "${RED}✗${RESET_COLOR} Docker daemon: ${BOLD_RED}Not running${RESET_COLOR}\n"
    fi
    
    # Count containers
    local total=$(docker ps -a -q | wc -l 2>/dev/null || echo 0)
    local running=$(docker ps -q | wc -l 2>/dev/null || echo 0)
    
    printf "📦 Containers: ${total:-0} total (${running:-0} running)\n"
    
    # Count images  
    local images=$(docker images -q | wc -l 2>/dev/null || echo 0)
    printf "📚 Images: ${images:-0} available\n"
    
    # Disk usage if available
    if command -v docker &> /dev/null; then
        local disk_usage=$(docker system df -q 2>/dev/null | grep "Local Images" | awk '{print $3}' 2>/dev/null || echo "N/A")
        printf "💾 Disk usage: $disk_usage\n"
    fi
    
    echo
    log.info "💡 Quick actions:"
    log.sub "  dockero run <name> <image>    # Create container"
    log.sub "  dockero list                  # View containers" 
    log.sub "  dockero learn start           # Docker learning"
}