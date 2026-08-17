#!/usr/bin/env bash

import_help() {
cat << EOF
${BOLD_CYAN}dockero import ${GREEN}</path/to/archive.tar>${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Import a .tar archive as a Docker image.
   ${BOLD_WHITE}• Equivalent Docker:${RESET_COLOR}
     ${YELLOW}docker load -i /path/to/archive.tar${RESET_COLOR}
EOF
}

import() {
    local tar_file="${1:-${args[1]:-}}"

    if [[ -z "$tar_file" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero import </path/to/archive.tar>${RESET_COLOR}"
        return 1
    fi

    if [[ ! -f "$tar_file" ]]; then
        log.error "File not found or is not a regular file: ${RED}$tar_file${RESET_COLOR}."
        return 1
    fi

    log.setline "${BOLD_CYAN}📥 Importing Image${RESET_COLOR}"
    log.info "Loading Docker image from archive: ${BOLD_YELLOW}$tar_file${RESET_COLOR}..."

    if ${DOCKERO_RUNTIME:-docker} load -i "$tar_file"; then
        log.done "Image loaded successfully from ${BOLD_GREEN}$tar_file${RESET_COLOR}."
        return 0
    else
        log.error "Failed to load image from ${RED}$tar_file${RESET_COLOR}."
        return 1
    fi
}