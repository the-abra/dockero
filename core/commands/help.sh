#!/usr/bin/env bash

# === TITLE ===
log.setline "Dockero - V$DOCKERO_VERSION"
echo "Dockero - Simplified Docker CLI"

help() {
  echo "
Usage 🪬 :"

  log.sub "dockero net      ${YELLOW}<command> [<args>]                          ${RESET_COLOR}Manage Docker networks (new, delete, add, remove, rename, list)."
  log.sub "dockero run      ${YELLOW}<name> [<image>]                            ${RESET_COLOR}Run an existing container or create a new one."
  log.sub "dockero list     ${YELLOW}[-img]                                      ${RESET_COLOR}List containers or images."
  log.sub "dockero stop     ${YELLOW}<container> [--timeout <seconds>]           ${RESET_COLOR}Stop a container with an optional delay."
  log.sub "dockero setup    ${YELLOW}<project-path>                              ${RESET_COLOR}Set up a containerized environment for a project. (.dockero)"
  log.sub "dockero start    ${YELLOW}<container> [-c <command>]                  ${RESET_COLOR}Start a container, optionally with a custom command."
  log.sub "dockero sync     ${YELLOW}<push|pull|watch|status|init>              ${RESET_COLOR}Synchronize files between host and container."
  log.sub "dockero compose  ${YELLOW}<up|down|start|stop|restart|ps|logs>       ${RESET_COLOR}Manage multi-container applications."
  log.sub "dockero env      ${YELLOW}<list|use|show|create|delete>              ${RESET_COLOR}Manage deployment environments."
  log.sub "dockero validate ${YELLOW}[path] [config-file]                       ${RESET_COLOR}Validate configuration files."
  log.sub "dockero system   ${YELLOW}<service|config|info|cleanup|install>      ${RESET_COLOR}System integration and management."
  log.sub "dockero learn    ${YELLOW}<basic|intermediate|advanced|examples>      ${RESET_COLOR}Interactive Docker learning system."
  log.sub "dockero explain  ${YELLOW}<command>                                 ${RESET_COLOR}Explain what Dockero commands do."
  log.sub "dockero show     ${YELLOW}<commands|dashboard|demo|visual>          ${RESET_COLOR}Visual command dashboard and demonstrations."
  log.sub "dockero heal     ${YELLOW}<check|fix|auto|diagnose|cleanup>         ${RESET_COLOR}Self-healing automation system."
  log.sub "dockero export   ${YELLOW}<container-name>                            ${RESET_COLOR}Export a container as a .tar archive to \$HOME."
  log.sub "dockero import   ${YELLOW}</path/to/archive.tar>                      ${RESET_COLOR}Import a .tar archive as a container image."
  log.sub "dockero rename   ${YELLOW}<old-name>[:tag] <new-name>[:tag] [-img]    ${RESET_COLOR}Rename an existing container or image."
  log.sub "dockero remove   ${YELLOW}<container|image>[:tag]                     ${RESET_COLOR}Remove a container(s) or an image(s)."

  log.hint 'Check out the wiki section on the github page for more detailed information.'

  log.endline
  exit 0
}

help-() { help && exit 0; }
help-help() { help && exit 0; }

help-run() {
  echo "
💠 dockero run <name>
  🔹 Launch an existing container by <name>.
  🔹 If the container is not found, create a new container using <name> as both the image and container name.

💠 dockero run <name> <image>
  🔹 Create a new container named <name> based on the specified <image>.

💠 Default Configuration:
  🔹 Port Mapping: Host 80 ➔ Container 80
  🔹 Volume Binding: /opt/<name> ➔ /workspace
  🔹 Host Integrations:
    🔸 DISPLAY environment variable for GUI support
    🔸 /dev/snd device access for audio output (if available)
"
  exit 0
}

help-list() {
  echo "
💠 dockero list
  🔹 List all existing containers.

💠 dockero list -img
  🔹 List all existing images.
"
}

help-rename() {
  echo "
💠 dockero rename <current-name> <new-name>
  🔹 Rename an existing container.

💠 dockero rename <image-name:tag> <new-name:tag> -img
  🔹 Rename an existing image.
"
}

help-export() {
  echo "
💠 dockero export <container-name>
  🔹 Export an existing container as a .tar archive to $HOME.
"
}

help-import() {
  echo "
 dockero import </path/to/archive.tar>
  🔹 Import a .tar archive as a new image.
"
}

help-start() {
  echo "
 dockero start <container-name>
  🔹 Start an existing container.

 dockero start <container-name> -c <command>
  🔹 Start an existing container and execute a specific command.
"
}

help-stop() {
  echo "
 dockero stop <container-name>
  🔹 Gracefully stop an existing container.

 dockero stop <container-name> --timeout <seconds>
  🔹 Stop a container after a specified delay in seconds.
"
}

help-setup() {
  cat <<EOF

🔧 Dockero Setup Utility

Usage:

💠 dockero setup <project-path>
  ▸ Runs an existing setup configuration (default behavior, equivalent to 'dockero setup run <project-path>').
  ▸ Requires a valid \`.dockero\` configuration file located at <project-path>.

💠 dockero setup init <project-path> | dockero setup create <project-path>
  ▸ Interactively creates a new \`.dockero\` configuration file for the specified project path.
  ▸ Guides you through configuration options for container setup.

💠 dockero setup run <project-path> | dockero setup build <project-path>
  ▸ Runs the container setup using the configuration from the specified project path.
  ▸ Requires a valid \`.dockero\` configuration file.

🔸 dockero setup run <project-path> -n
  ▸ Performs a dry run of the setup without launching the container.
  ▸ Shows what would be executed without making changes.

💠 dockero setup update <project-path>
  ▸ Interactively updates an existing \`.dockero\` configuration file.
  ▸ Allows you to modify container settings without recreating the file.

💠 dockero setup teardown <project-path> | dockero setup delete <project-path>
  ▸ Stops and removes the container associated with the project configuration.
  • Performs cleanup of container resources.

📄 .dockero Configuration File Format

🔹 [default] section:
   🔸 name = Container name
   🔸 image = Docker image to use (e.g., ubuntu:latest)
   🔸 command = Command to run when container starts
   🔸 restart_policy = Restart policy (no, always, on-failure, unless-stopped)

🔹 [volumes] section:
   🔸 env = Volume mapping in format 'host_path:container_path'
   🔸 port = Port mapping in format 'host_port:container_port'

🔹 [user] section:
   🔸 name = Username for container execution
   🔸 gid = Group ID for container execution

EOF
}

help-remove() {
  echo "
 dockero remove <container-or-image>[:tag]
  🔹 Remove a specified container or image.
"
}

help-sync() {
  cat <<EOF

🔄 Dockero Sync Utility

Usage:

💠 dockero sync push <container-name> [path]
  ▸ Synchronize files from the current host directory to the specified container path.
  ▸ Defaults to syncing to /workspace if no path is provided.

💠 dockero sync pull <container-name> [path] 
  ▸ Synchronize files from the container path to the current host directory.
  ▸ Defaults to syncing from /workspace if no path is provided.

💠 dockero sync watch <container-name> [path]
  ▸ Watch the host directory for changes and automatically sync to the container.
  • Requires inotify-tools to be installed.
  ▸ Defaults to syncing /workspace if no path is provided.

💠 dockero sync status <container-name>
  ▸ Shows synchronization status information for the specified container.

💠 dockero sync init [project-path]
  ▸ Initialize a .dockero-sync configuration file for advanced sync rules.

EOF
}

help-compose() {
  cat <<EOF

🏗️  Dockero Compose Utility

Usage:

 dockero compose up 
  • Starts all services defined in .dockero-compose (or .dockero-compose.<env>).
  • Creates containers if they don't exist, starts them if already created.
  • Respects dependencies defined in the compose file.

 dockero compose down
  • Stops and removes all services defined in the compose file.
  • Stops services in reverse dependency order.

 dockero compose start
  • Starts existing containers for all services without recreating them.

 dockero compose stop
  • Stops all running services without removing containers.

 dockero compose restart
  • Stops and starts all services.

 dockero compose ps
  • Shows status of all defined services.

 dockero compose logs [service-name]
  • Shows logs for all services or a specific service.

📄 .dockero-compose File Format

🔹 [global] section:
   • Settings that apply to all services
   
🔹 [service:<service-name>] section:
   🔸 container_name = Name for the container
   🔸 image = Docker image to use
   🔸 command = Command to run in the container
   🔸 ports = Port mappings (comma-separated, format: host:container)
   🔸 volumes = Volume mappings (comma-separated, format: host:container)
   🔸 environment = Environment variables (comma-separated, format: KEY=VALUE)
   🔸 depends_on = Services that this service depends on
   🔸 restart = Restart policy (no, always, on-failure, unless-stopped)

EOF
}

help-env() {
  cat <<EOF

🌍 Dockero Environment Utility

Usage:

 dockero env list
  • Lists all available environments detected from configuration files.
  • Shows currently active environment.

 dockero env show
  • Shows information about the current active environment.

 dockero env use <environment> | dockero env switch <environment>
  • Switches to the specified environment.
  • Subsequent dockero commands will use environment-specific configurations.

 dockero env create <environment>
  • Creates a new environment with template configuration files.

 dockero env delete <environment>
  • Removes configuration files for the specified environment.

📋 Supported Environment Files:
  • .dockero-<env> - Environment-specific container configurations
  • .dockero-compose-<env> - Environment-specific multi-container configurations  
  • .env.<env> - Environment-specific environment variables

📌 When an environment is active, Dockero will look for environment-specific 
   versions of configuration files first before falling back to defaults.

EOF
}

help-validate() {
  cat <<EOF

✅ Dockero Configuration Validation

Usage:

 dockero validate [path] [config-file]
  • Validates configuration files in the specified path.
  • If no config-file specified, validates all .dockero* files in path.
  • Validates .dockero, .dockero-compose, and environment-specific files.

📋 Validation Checks Performed:
  • INI file structure validation
  • Required field validation (.dockero: name, image)
  • Service definition validation (.dockero-compose)
  • Format validation for container names, images, ports
  • Safe path validation (prevents directory traversal)
  • Docker configuration syntax validation

EOF
}

help-system() {
  cat <<EOF

⚙️  Dockero System Integration

Usage:

 dockero system service <create|start|stop|enable|disable|status> <container-name> [service-name]
  • Manage container as a systemd service.
  • Creates systemd unit files for persistent container management.

 dockero system config <get|set|list|reset> [key] [value]
  • Manage Dockero system configuration.
  • Stores configuration in ~/.dockero/config

📋 Supported Configuration Options:
  • default_docker_runtime = docker|podman
  • default_restart_policy = no|always|on-failure|unless-stopped
  • default_port_mapping = port:port format
  • default_volume_mapping = host_path:container_path format

 dockero system info
  • Display system information and Dockero environment status.

 dockero system cleanup [target]
  • Cleanup Docker resources. Targets: containers, images, volumes, networks, all, temp

📋 System Cleanup Targets:
  • containers: Remove stopped containers
  • images: Remove unused images
  • volumes: Remove unused volumes
  • networks: Remove unused networks
  • all: Remove all unused resources
  • temp: Clean up temporary files

 dockero system install [location]
  • Install Dockero to system location (default: /usr/local/bin)

EOF
}

help-learn() {
  cat <<EOF

🎓 Dockero Learning System

Usage:

 dockero learn start | dockero learn basic
  • Interactive Docker learning for beginners.
  • Covers containers, images, volumes, and basic operations.

 dockero learn basic <topic>
  • Learn fundamental Docker concepts.
  • Topics: containers, images, volumes

 dockero learn intermediate <topic>  
  • Learn more advanced Docker concepts.
  • Topics: networks, environment

📋 Intermediate Concepts:
  • Container networking and communication
  • Environment variables and configuration
  • Multi-container applications

 dockero learn advanced <topic>
  • Advanced Docker practices and patterns.
  • Topics: security

📋 Advanced Topics:
  • Security best practices
  • Resource management
  • Production considerations

 dockero learn concepts [topic]
  • Comprehensive guide to Docker concepts.
  • Topics: multi-container, lifecycle

📋 Core Concepts:
  • Container lifecycle management
  • Multi-container application patterns
  • Service dependencies

 dockero learn docker [topic]
  • Learn Docker architecture and fundamentals.
  • Understanding the underlying technology.

 dockero learn examples [topic]
  • Practical examples and use cases.
  • Topics: web-app, database

EOF
}

help-explain() {
  cat <<EOF

🔍 Command Explanation System

Usage:

 dockero explain <command>
  • Shows detailed explanation of what a Dockero command does.
  • Includes equivalent Docker commands and purpose.

📋 Available Explanations:
  • dockero explain run     → How dockero run works
  • dockero explain setup   → How dockero setup works  
  • dockero explain compose → How dockero compose works

💡 This command helps you understand not just what to do,
   but why Dockero does what it does and how it relates 
   to standard Docker commands.

EOF
}

help-show() {
  cat <<EOF

📊 Visual Command Dashboard

Usage:

 dockero show dashboard
  • Visual overview of Dockero system status and commands.
  • Quick access to common operations and status information.

📋 Dashboard Information:
  • Docker daemon status
  • Container counts and states  
  • Getting started commands
  • Popular command shortcuts

 dockero show commands [category]
  • Visual command reference organized by category.
  • Short descriptions and quick usage examples.

📋 Command Categories:
  • Quick Start: run, list, start, stop
  • Container Management: setup, create, remove
  • Networking: net, compose  
  • Sync & Data: sync, export, import
  • Environment: env, system
  • Learning: learn, explain, validate

 dockero show demo <command>
  • Interactive demonstration of how commands work.
  • Visual scenario walkthroughs.

📋 Available Demos:
  • dockero show demo run      → Container operations
  • dockero show demo setup    → Project setup process  
  • dockero show demo sync     → File synchronization

 dockero show visual <element>
  • Visual representations of Docker concepts.
  • Container structure, networking, and setup process.

📋 Visual Elements:
  • container  → Container architecture
  • network    → Networking visualization  
  • setup      → Setup process flow

 dockero show containers
  • Visual dashboard of all containers with status.

 dockero show status
  • Comprehensive system status overview.

🎨 The 'show' command provides visual, intuitive access to 
   Dockero functionality with educational visualizations.

EOF
}

help-net() {
  echo "
 dockero net new <network>
  🔹 Create a new Docker network with the specified <network> name.

 dockero net delete <network>
  🔹 Remove the specified Docker network.
  🔹 Containers connected to the network will be disconnected automatically.

 dockero net add <container> <network>
  🔹 Connect an existing container to the specified Docker network.

 dockero net remove <container> <network>
  🔹 Disconnect a container from the specified Docker network.

 dockero net rename <network> <new_name>
  🔹 Rename an existing Docker network.
  🔹 This is achieved by creating a new network and reconnecting all containers from the old network.

 dockero net list
  🔹 Display all Docker networks along with their connected containers.
"
  exit 0
}

help-heal() {
  cat <<EOF

🤖 Self-Healing Automation System

Usage:

 dockero heal check [target]
  • Perform comprehensive health check on system components.
  • Targets: system (default), containers, networks, all

📋 Health Check Items:
  • Docker daemon status
  • Disk space usage for Docker
  • Container health and status
  • Unused resources (images, volumes, networks)
  • Network connectivity

 dockero heal fix <target> [item]
  • Automatically fix identified issues.
  • Targets: containers, images, volumes, system, all
  • Item: specific container name (for containers target)

 dockero heal auto
  • Run automatic health check and apply fixes.
  • Designed for scheduled maintenance tasks.

 dockero heal diagnose <issue-type>
  • Deep diagnosis for specific issues.
  • Issue types: startup, network, performance, all

 dockero heal cleanup [target]
  • Proactive cleanup of unused resources.
  • Targets: all (default), unused, logs

 dockero heal restore <target>
  • Restore environment to expected configuration state.
  • Targets: config, workspace, containers, all

 dockero heal watch <target>
  • Real-time monitoring of system components.
  • Targets: containers, resources, config, all

 dockero heal policy <action> [policy-type]
  • Manage health policies and automated rules.
  • Actions: list, get, set; Policy types: restart, cleanup, monitor

💡 The heal command provides comprehensive self-healing
   capabilities to maintain Dockero system health automatically.

EOF
}