#!/usr/bin/env bash

explain_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero explain ${GREEN}<command>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Show what a Dockero command does and its equivalent Docker commands.
   ${BOLD_WHITE}• Usage:${RESET_COLOR} dockero explain <command>
EOF
}

explain() {
    local command_to_explain="${1:-}"

    if [[ -z "$command_to_explain" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}explain <command>${RESET_COLOR}"
        log.sub "Shows what a Dockero command does and the equivalent Docker commands."
        # List available commands by scanning the commands directory
        local available
        available=$(find "${COMMANDS_DIR}" "${HOME}/.dockero/commands" -maxdepth 1 -name "*.sh" 2>/dev/null \
            | sed 's|.*/||; s|\.sh$||' | sort | tr '\n' ',' | sed 's/,$//')
        log.sub "Available commands: ${BOLD_GREEN}${available}${RESET_COLOR}"
        return 0
    fi

    # Validate command name to prevent path traversal
    if [[ ! "$command_to_explain" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log.error "Invalid command name: '${BOLD_RED}$command_to_explain${RESET_COLOR}'"
        return 1
    fi

    log.setline "${BOLD_CYAN}Command Explanation: ${YELLOW}$command_to_explain${RESET_COLOR}"

    # Look for the command script (user plugins first, then built-in)
    local cmd_file="${COMMANDS_DIR}/${command_to_explain}.sh"
    local user_cmd_file="${HOME}/.dockero/commands/${command_to_explain}.sh"
    [[ -f "$user_cmd_file" ]] && cmd_file="$user_cmd_file"

    if [[ ! -f "$cmd_file" ]]; then
        log.warn "No command found for '${BOLD_YELLOW}$command_to_explain${RESET_COLOR}'."
        return 1
    fi

    # Source the command script and call its _help function
    # shellcheck disable=SC1090
    source "$cmd_file"

    local help_fn="${command_to_explain}_help"
    if declare -f "$help_fn" >/dev/null 2>&1; then
        "$help_fn"
    else
        log.warn "No help defined for '${BOLD_YELLOW}$command_to_explain${RESET_COLOR}'."
        log.sub "The command exists but has no _help() function yet."
    fi
}
