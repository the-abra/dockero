#!/usr/bin/env bash

# core/learn/helpers.sh - Helper functions for the interactive learning system.

_press_enter_to_continue() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

_heading() {
    log.setline "${BOLD_CYAN}$1${RESET_COLOR}"
}

_subheading() {
    echo ""
    log.info "${BOLD_WHITE}$1${RESET_COLOR}"
}

_present_code() {
    local code="$1"
    echo -e "  ${BOLD_GREEN}${code}${RESET_COLOR}"
}

_present_command() {
    local cmd="$1"
    local desc="$2"
    echo ""
    log.info "Try this command:"
    _present_code "$cmd"
    log.sub "$desc"
    echo ""
}
