#!/usr/bin/env bash

dashboard_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero dashboard${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Quick overview of Docker system status, running containers, and suggested actions.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker ps -a${RESET_COLOR} + ${YELLOW}docker images${RESET_COLOR} + ${YELLOW}docker info${RESET_COLOR}
EOF
}

dashboard() {
  log.setline "Dockero Dashboard"
  
  log.setline "Docker Dashboard"
  
  # Check Docker status
  if command -v docker &> /dev/null && ${DOCKERO_RUNTIME:-docker} ps -q &>/dev/null; then
    log.done "Docker Daemon: Active"
  else
    log.error "Docker Daemon: Inactive"
    log.hint "Please start Docker before using Dockero"
    log.endline "Dockero Dashboard"
    return 1
  fi
  
  # Get container stats
  local running_containers
  local all_containers
  local all_images
  running_containers=$(${DOCKERO_RUNTIME:-docker} ps -q | wc -l 2>/dev/null || echo 0)
  all_containers=$(${DOCKERO_RUNTIME:-docker} ps -a -q | wc -l 2>/dev/null || echo 0)
  all_images=$(${DOCKERO_RUNTIME:-docker} images -q | wc -l 2>/dev/null || echo 0)
  
  echo ""
  log.info "📊 Container Stats:"
  log.sub "Running: ${BOLD}$running_containers${RESET_COLOR}"
  log.sub "Total:   ${BOLD}$all_containers${RESET_COLOR}"
  log.sub "Images:  ${BOLD}$all_images${RESET_COLOR}"
  
  # Show running containers with status
  if [ "$running_containers" -gt 0 ]; then
    echo ""
    log.info "📦 Running Containers:"
    ${DOCKERO_RUNTIME:-docker} ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | sed 's/.*/  &/'
  else
    echo ""
    log.info "📦 Running Containers:"
    log.sub "No containers running."
  fi
  
  # Quick actions
  echo ""
  log.info "⚡ Quick Actions:"
  log.sub "${BOLD}dockero create${RESET_COLOR} <name> [image] - Create a container"
  log.sub "${BOLD}dockero list${RESET_COLOR}                 - List all containers"
  log.sub "${BOLD}dockero setup${RESET_COLOR} <path>          - Set up a project"
  log.sub "${BOLD}dockero help${RESET_COLOR}                  - Show all commands"
  
  # Dockero info
  echo ""
  log.info "⚙️  Dockero Info:"
  log.sub "Version: ${BOLD}$DOCKERO_VERSION${RESET_COLOR}"
  log.sub "Runtime: ${BOLD}${DOCKERO_RUNTIME:-docker}${RESET_COLOR}"
  log.sub "Config:  ${HOME}/.dockero/config"
  
  log.endline "Dockero Dashboard"
}
