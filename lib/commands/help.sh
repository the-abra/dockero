#!/usr/bin/env bash

help_help() {
cat << EOF
${BOLD_CYAN}dockero help ${GREEN}[command]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Show usage information and command list.
   ${BOLD_WHITE}• Usage:${RESET_COLOR} dockero help [command] - shows general help or specific command help
EOF
}

_show_general_help() {
  log.setline "Dockero - v$DOCKERO_VERSION"
  log.info "Dockero - Simplified Linux Docker & Podman CLI"
  echo -e "
${BOLD_CYAN}Usage:${RESET_COLOR}
  dockero <command> [options] [arguments]

${BOLD_GREEN}Container Lifecycle:${RESET_COLOR}
  dockero run <name> [image] [-d] [-p <port>] [-e <VAR=val>] [--env-file <file>]
  dockero create <name> [image] [-d] [-p <port>] [--volume <host:container>]
  dockero start <container> [-c <command>]
  dockero stop <container> [-t <seconds>]
  dockero exec <command> [args...] <container>
  dockero list [img] (aliases: ps, ls)
  dockero remove <container|image>[:tag] (alias: rm)
  dockero rename <old-name>[:tag] <new-name>[:tag] [-img]
  dockero inspect <container|image|volume|network>
  dockero export <container-name> [-o <path.tar>]
  dockero import </path/to/archive.tar>

${BOLD_GREEN}Project & Multi-Container Setup:${RESET_COLOR}
  dockero setup <init|run|update|teardown> [path] [--preset <name>]
  dockero compose <up|down|start|stop|restart|ps|logs>
  dockero validate [path] [config-file]

${BOLD_GREEN}Storage & Networking:${RESET_COLOR}
  dockero volume <list|create|remove|inspect|attach|prune>
  dockero net <create|delete|connect|disconnect|inspect|list|prune>
  dockero registry <login|push|pull|list|search|logout>

${BOLD_GREEN}Linux System, Monitoring & Healing:${RESET_COLOR}
  dockero dashboard (quick overview)
  dockero monitor <top|stats|health|logs|watch>
  dockero system <service|config|info|cleanup|install|dev>
  dockero heal <check|fix|auto|diagnose|cleanup|restore>
  dockero plugin <list|install|remove>

${BOLD_GREEN}Documentation & Help:${RESET_COLOR}
  dockero explain <command> (or dockero <command> -h)
  dockero version
"
  log.hint "For detailed explanations of any command, use '${BOLD_YELLOW}dockero explain <command>${RESET_COLOR}'."
  log.endline ""
  exit 0
}

help() {
  local target_command="${args[1]:-}"

  if [[ -z "$target_command" ]]; then
      _show_general_help
  else
      explain "$target_command" "${args[@]:2}"
  fi
  exit 0
}
