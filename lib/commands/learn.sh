#!/usr/bin/env bash

# dockero learn - A new interactive learning system for Docker.

learn_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero learn ${GREEN}<start|basic|intermediate|advanced|docker|concepts|examples> [topic]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Interactive Docker learning system with structured lessons.
   ${BOLD_WHITE}• Topics:${RESET_COLOR} basics, intermediate (networks, env), advanced (security), concepts, examples.
EOF
}

learn() {
    local learn_main_script="${CORE_DIR}/learn/main.sh"

    if [[ -f "$learn_main_script" ]]; then
        # shellcheck disable=SC1090
        source "$learn_main_script"
        # shellcheck disable=SC2154
        _learn_main "${args[@]:1}"
    else
        log.error "Learn system not found. Please reinstall dockero."
        return 1
    fi
}
