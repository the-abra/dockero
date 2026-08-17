#!/usr/bin/env bash

explain_help() {
cat << EOF
${BOLD_CYAN}dockero explain ${GREEN}<command>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Show what a Dockero command does and its equivalent Docker commands.
   ${BOLD_WHITE}• Usage:${RESET_COLOR} dockero explain <command>
EOF
}

explain() {
    local command_to_explain="${1:-}"

    if [[ -z "$command_to_explain" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}explain <command>${RESET_COLOR}"
        log.sub "Shows what a Dockero command does and the equivalent Docker commands."
        
        # Hardcoded list of built-in subcommands plus dynamic user plugins
        local builtins="compose,create,dashboard,env,exec,explain,export,heal,help,import,learn,list,monitor,net,plugin,registry,remove,rename,secrets,setup,show,start,stop,system,validate,volume,wizard"
        local user_plugins=""
        if [[ -d "${HOME}/.dockero/commands" ]]; then
            user_plugins=$(find "${HOME}/.dockero/commands" -maxdepth 1 -name "*.sh" 2>/dev/null | sed 's|.*/||; s|\.sh$||' | sort | tr '\n' ',' | sed 's/,$//' || true)
        fi
        
        if [[ -n "$user_plugins" ]]; then
            log.sub "Available commands: ${BOLD_GREEN}${builtins},${user_plugins}${RESET_COLOR}"
        else
            log.sub "Available commands: ${BOLD_GREEN}${builtins}${RESET_COLOR}"
        fi
        return 0
    fi

    # Validate command name to prevent path traversal
    if [[ ! "$command_to_explain" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log.error "Invalid command name: '${BOLD_RED}$command_to_explain${RESET_COLOR}'"
        return 1
    fi

    log.setline "${BOLD_CYAN}Command Explanation: ${YELLOW}$command_to_explain${RESET_COLOR}"

    local help_fn="${command_to_explain}_help"
    case "$command_to_explain" in
        "run") help_fn="create_help" ;;
        "ps"|"ls") help_fn="list_help" ;;
        "rm"|"rmi") help_fn="remove_help" ;;
        "logs") help_fn="monitor_help" ;;
        "inspect") help_fn="show_help" ;;
    esac

    # 1. If help function is already declared (built-ins in compiled script)
    if declare -f "$help_fn" >/dev/null 2>&1; then
        "$help_fn"
        return 0
    fi

    # 2. Check for user plugins
    local user_cmd_file="${HOME}/.dockero/commands/${command_to_explain}.sh"
    if [[ -f "$user_cmd_file" ]]; then
        # shellcheck disable=SC1090
        source "$user_cmd_file"
        if declare -f "$help_fn" >/dev/null 2>&1; then
            "$help_fn"
            return 0
        fi
    fi

    log.warn "No command or help found for '${BOLD_YELLOW}$command_to_explain${RESET_COLOR}'."
    return 1
}
