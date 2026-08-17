#!/usr/bin/env bash

dashboard_help() {
cat << EOF
${BOLD_CYAN}dockero dashboard${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Quick overview of Docker system status, running containers, and suggested actions.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker ps -a${RESET_COLOR} + ${YELLOW}docker images${RESET_COLOR} + ${YELLOW}docker info${RESET_COLOR}
EOF
}

dashboard() {
  log.setline "${BOLD_CYAN}📊 Dockero Dashboard${RESET_COLOR}"
  
  local runtime="${DOCKERO_RUNTIME:-docker}"

  # Check Docker / Podman status
  if command -v "$runtime" &> /dev/null && "$runtime" ps -q &>/dev/null; then
    log.done "Container Runtime (${BOLD_YELLOW}$runtime${RESET_COLOR}): Active"
  else
    log.error "Container Runtime (${BOLD_YELLOW}$runtime${RESET_COLOR}): Inactive or not installed."
    log.hint "Please ensure $runtime daemon is running before using Dockero."
    log.endline ""
    return 1
  fi
  
  # Get container stats
  local running_containers
  local all_containers
  local all_images
  running_containers=$("$runtime" ps -q 2>/dev/null | wc -l || echo 0)
  all_containers=$("$runtime" ps -a -q 2>/dev/null | wc -l || echo 0)
  all_images=$("$runtime" images -q 2>/dev/null | wc -l || echo 0)
  
  echo ""
  log.info "📊 Container Statistics:"
  log.sub "Running Containers: ${BOLD_GREEN}$running_containers${RESET_COLOR}"
  log.sub "Total Containers:   ${BOLD_YELLOW}$all_containers${RESET_COLOR}"
  log.sub "Available Images:   ${BOLD_CYAN}$all_images${RESET_COLOR}"
  
  # Show running containers with status
  if [[ "$running_containers" -gt 0 ]]; then
    echo ""
    log.info "Active Containers:"
    "$runtime" ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | sed 's/.*/  &/'
  else
    echo ""
    log.info "Active Containers:"
    log.sub "No containers currently running."
  fi
  
  # Quick actions
  echo ""
  log.info "⚡ Quick Actions:"
  log.sub "${BOLD}dockero run${RESET_COLOR} <name> [image]    - Run a container"
  log.sub "${BOLD}dockero list${RESET_COLOR} (or ${BOLD}ps${RESET_COLOR})         - List all containers"
  log.sub "${BOLD}dockero setup${RESET_COLOR} <path>          - Set up a project (.dockero)"
  log.sub "${BOLD}dockero help${RESET_COLOR}                  - Show all commands"
  
  # Dockero info
  echo ""
  log.info "Dockero Environment:"
  log.sub "Version: ${BOLD_GREEN}v${DOCKERO_VERSION:-1.0.0}${RESET_COLOR}"
  log.sub "Runtime: ${BOLD_YELLOW}$runtime${RESET_COLOR}"
  log.sub "Config:  ${HOME}/.dockero/config"
  
  log.endline ""
  return 0
}
