#!/usr/bin/env bash

help_help() {
cat << EOF
${BOLD_CYAN}dockero help ${GREEN}[command]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Show usage information and command list.
   ${BOLD_WHITE}• Usage:${RESET_COLOR} dockero help [command] - shows general help or specific command help
EOF
}

_show_general_help() { # Renamed to a private helper
  log.setline "Dockero - V$DOCKERO_VERSION"
  log.info "Dockero - Simplified Docker CLI"
  echo -e "
${BOLD_CYAN}Usage:${RESET_COLOR}

${BOLD_GREEN}Container Management:${RESET_COLOR}
  dockero create <name> [<image>] [-d] [--volume <host:container>] [--no-volume] [-p <port>]
  dockero volume <list|create|remove|inspect|prune>
  dockero start <container> [-c <command>]
  dockero stop <container> [--timeout <seconds>]
  dockero exec <command> [args...] <container>
  dockero list [img]
  dockero remove <container|image>[:tag]
  dockero rename <old-name>[:tag] <new-name>[:tag] [-img]
  dockero export <container-name>
  dockero import </path/to/archive.tar>

${BOLD_GREEN}Project & Environment Setup:${RESET_COLOR}
  dockero setup <project-path>
  dockero env <list|use|show|create|delete>
  dockero compose <up|down|start|stop|restart|ps|logs>

${BOLD_GREEN}Networking & Storage:${RESET_COLOR}
  dockero net <create|delete|connect|disconnect|inspect|list|prune>
  dockero volume <list|create|remove|inspect|attach|prune>

${BOLD_GREEN}Monitoring & Management:${RESET_COLOR}
  dockero monitor <top|stats|health|logs|watch>
  dockero registry <login|push|pull|list|search|logout>
  dockero secrets <create|list|show|remove>
  dockero system <service|config|info|cleanup|install>
  dockero heal <check|fix|auto|diagnose|cleanup>
  dockero validate [path] [config-file]
  dockero plugin <list|install|remove>

${BOLD_GREEN}Learning & Help:${RESET_COLOR}
  dockero explain <command>
  dockero show <commands|dashboard|demo|visual>
  dockero learn <basic|intermediate|advanced|examples>
  dockero wizard [start|setup|init]
"
  log.hint "For detailed explanations of any command, use '${BOLD_YELLOW}dockero explain <command>${RESET_COLOR}'."
  log.endline ""
  exit 0
}

help() {
  # This function is now only explicitly called as `dockero help <command>`
  # The global -h flag is handled in dockero directly calling explain.

  local target_command="${args[1]:-}" # Check for `dockero help <command>` format

  if [[ -z "$target_command" ]]; then
      _show_general_help # No specific command given, show general help
  else
      # We have a specific command. Redirect to explain directly.
      explain "$target_command" "${args[@]:2}" # Pass the target command and any further args
  fi
  exit 0
}
