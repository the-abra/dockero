#!/usr/bin/env bash

# dockero learn - A new interactive learning system for Docker.

learn() {
    local learn_main_script="${CORE_DIR}/learn/main.sh"

    if [[ -f "$learn_main_script" ]]; then
        # shellcheck disable=SC1090
        source "$learn_main_script"
        _learn_main "${args[@]:1}"
    else
        log.error "Learn system not found. Please reinstall dockero."
        return 1
    fi
}
