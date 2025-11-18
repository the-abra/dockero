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
💠 dockero import </path/to/archive.tar>
  🔹 Import a .tar archive as a new image.
"
}

help-start() {
  echo "
💠 dockero start <container-name>
  🔹 Start an existing container.

💠 dockero start <container-name> -c <command>
  🔹 Start an existing container and execute a specific command.
"
}

help-stop() {
  echo "
💠 dockero stop <container-name>
  🔹 Gracefully stop an existing container.

💠 dockero stop <container-name> --timeout <seconds>
  🔹 Stop a container after a specified delay in seconds.
"
}

help-setup() {
  cat <<EOF

🔧 Dockero Setup Utility

Usage:

💠 dockero setup <project-path>
  ▸ Initializes and provisions a container environment based on the provided project path.
  ▸ Requires a valid \`.dockero\` configuration file located at <project-path>.

📄 .dockero Configuration File Format

🔹 port  
   ▸ Defines the host-to-container port mapping (e.g., 8080:80).  
   ▸ Optional.

🔹 env  
   ▸ Declares volume mappings in the format '<host_path>:<container_path>'.  
   ▸ Defaults to '\$PWD:/workspace' if not explicitly specified.  
   ▸ Optional.

📌 Example Configuration and Usage  
   ▸ Check out the wiki section on the github page for more detailed information.

EOF
}

help-remove() {
  echo "
💠 dockero remove <container-or-image>[:tag]
  🔹 Remove a specified container or image.
"
}

help-net() {
  echo "
💠 dockero net new <network>
  🔹 Create a new Docker network with the specified <network> name.

💠 dockero net delete <network>
  🔹 Remove the specified Docker network.
  🔹 Containers connected to the network will be disconnected automatically.

💠 dockero net add <container> <network>
  🔹 Connect an existing container to the specified Docker network.

💠 dockero net remove <container> <network>
  🔹 Disconnect a container from the specified Docker network.

💠 dockero net rename <network> <new_name>
  🔹 Rename an existing Docker network.
  🔹 This is achieved by creating a new network and reconnecting all containers from the old network.

💠 dockero net list
  🔹 Display all Docker networks along with their connected containers.
"
  exit 0
}
