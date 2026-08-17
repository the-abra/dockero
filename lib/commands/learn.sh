#!/usr/bin/env bash

# dockero learn - Interactive learning system for Docker.

learn_help() {
cat << EOF
${BOLD_CYAN}dockero learn ${GREEN}<basics|intermediate|advanced|examples> [topic_number]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Interactive Docker learning system with structured lessons.
   ${BOLD_WHITE}• Levels:${RESET_COLOR} basics, intermediate, advanced, examples.
   ${BOLD_WHITE}• Examples:${RESET_COLOR}
     ${YELLOW}dockero learn${RESET_COLOR}
     ${YELLOW}dockero learn basics${RESET_COLOR}
     ${YELLOW}dockero learn basics 1${RESET_COLOR}
EOF
}

learn() {
    local learn_main_script="${CORE_DIR:-/usr/local/share/dockero/lib}/learn/main.sh"
    if [[ ! -f "$learn_main_script" && -f "/usr/local/share/dockero/lib/learn/main.sh" ]]; then
        learn_main_script="/usr/local/share/dockero/lib/learn/main.sh"
    fi

    if [[ -f "$learn_main_script" ]]; then
        CORE_DIR="$(cd "$(dirname "$learn_main_script")/.." && pwd)"
        # shellcheck disable=SC1090
        source "$learn_main_script"
        # shellcheck disable=SC2154
        _learn_main "${args[@]:1}"
    else
        log.error "Learn system not found at $learn_main_script."
        return 1
    fi
}
