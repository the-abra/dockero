#!/usr/bin/env bash

dashboard() {
  log.setline "Dockero Dashboard"
  
  echo -e "${BOLD_CYAN}┌─────────────────────────────────────────────────────────┐${RESET_COLOR}"
  echo -e "${BOLD_CYAN}│${RESET_COLOR}                    ${BOLD_YELLOW}Docker Dashboard${RESET_COLOR}                     ${BOLD_CYAN}│${RESET_COLOR}"
  echo -e "${BOLD_CYAN}└─────────────────────────────────────────────────────────┘${RESET_COLOR}"
  
  # Check Docker status
  if command -v docker &> /dev/null && docker ps -q &>/dev/null; then
    echo -e "${BOLD_GREEN}✅ Docker Daemon${RESET_COLOR} ${GREEN}Active${RESET_COLOR}"
  else
    echo -e "${BOLD_RED}❌ Docker Daemon${RESET_COLOR} ${RED}Inactive${RESET_COLOR}"
    echo -e "   Please start Docker before using Dockero"
    log.endline "Dockero Dashboard"
    return 1
  fi
  
  # Get container stats
  local running_containers
  local all_containers
  local all_images
  running_containers=$(docker ps -q | wc -l 2>/dev/null || echo 0)
  all_containers=$(docker ps -a -q | wc -l 2>/dev/null || echo 0)
  all_images=$(docker images -q | wc -l 2>/dev/null || echo 0)
  
  echo ""
  echo -e "${BOLD_WHITE}📊 CONTAINER STATS${RESET_COLOR}"
  echo -e "   ${BOLD_CYAN}Running:${RESET_COLOR} ${BOLD_GREEN}$running_containers${RESET_COLOR}"
  echo -e "   ${BOLD_CYAN}Total:${RESET_COLOR}   ${BOLD_GREEN}$all_containers${RESET_COLOR}"
  echo -e "   ${BOLD_CYAN}Images:${RESET_COLOR}  ${BOLD_GREEN}$all_images${RESET_COLOR}"
  
  # Show running containers with status
  if [ "$running_containers" -gt 0 ]; then
    echo ""
    echo -e "${BOLD_WHITE}📦 RUNNING CONTAINERS${RESET_COLOR}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" | sed 's/.*/  &/'
  else
    echo ""
    echo -e "${BOLD_WHITE}📦 RUNNING CONTAINERS${RESET_COLOR}"
    echo -e "  ${YELLOW}No containers running${RESET_COLOR}"
  fi
  
  # Quick actions
  echo ""
  echo -e "${BOLD_WHITE}⚡ QUICK ACTIONS${RESET_COLOR}"
  echo -e "  ${BOLD_GREEN}dockero run${RESET_COLOR} <name> [image]   - Create/start a container"
  echo -e "  ${BOLD_GREEN}dockero list${RESET_COLOR}                 - List all containers"
  echo -e "  ${BOLD_GREEN}dockero setup${RESET_COLOR} <path>          - Set up a project"
  echo -e "  ${BOLD_GREEN}dockero help${RESET_COLOR}                  - Show all commands"
  
  # Dockero info
  echo ""
  echo -e "${BOLD_WHITE}⚙️  DOCKERO INFO${RESET_COLOR}"
  echo -e "  ${BOLD_CYAN}Version:${RESET_COLOR} $DOCKERO_VERSION"
  echo -e "  ${BOLD_CYAN}Runtime:${RESET_COLOR} ${DOCKERO_RUNTIME:-docker}"
  echo -e "  ${BOLD_CYAN}Config:${RESET_COLOR}  ${HOME}/.dockero/config"
  
  log.endline "Dockero Dashboard"
}
