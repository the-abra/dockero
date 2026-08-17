#!/usr/bin/env bash

inspect_help() {
cat << EOF
${BOLD_CYAN}dockero inspect ${GREEN}<container|image|volume|network> [format]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Display low-level detailed information on Docker objects.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker inspect <target>${RESET_COLOR}
EOF
}

inspect() {
    local target="${args[1]:-}"

    if [[ -z "$target" ]]; then
        log.error "Target object required to inspect."
        log.hint "Usage: ${BOLD_YELLOW}dockero inspect <container|image|volume|network>${RESET_COLOR}"
        return 1
    fi

    log.setline "${BOLD_CYAN}🔍 Inspect: ${BOLD_YELLOW}$target${RESET_COLOR}"

    if command -v jq &>/dev/null; then
        ${DOCKERO_RUNTIME:-docker} inspect "${args[@]:1}" | jq .
    else
        ${DOCKERO_RUNTIME:-docker} inspect "${args[@]:1}"
    fi
}
