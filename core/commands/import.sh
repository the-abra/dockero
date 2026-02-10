#!/usr/bin/env bash

import() {
    if [[ -z "${args[1]}" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero import </path/to/archive.tar>${RESET_COLOR}"
        return 1
    fi
    # Check for unexpected parameters, as params are not handled here.
    if [[ -n "${params[*]}" ]]; then
        log.warn "The ${BOLD_YELLOW}import${RESET_COLOR} command does not accept additional parameters."
        return 1
    fi

    local tar_file="$1" # Use $1 directly, as args[1] is already available

    # --- Input Validation for tar_file ---
    # Check for path traversal sequences
    if [[ "$tar_file" =~ \.\. ]]; then
        log.error "Invalid file path: '${RED}$tar_file${RESET_COLOR}'. Path traversal sequences (..) are not allowed."
        return 1
    fi
    # Ensure it's a regular file
    if [[ ! -f "$tar_file" ]]; then
        log.error "File not found or is not a regular file: ${RED}$tar_file${RESET_COLOR}."
        return 1
    fi

    log.setline "${BOLD_CYAN}📦 Importing Image${RESET_COLOR}"
    log.info "Attempting to load image from archive: ${BOLD_YELLOW}$tar_file${RESET_COLOR}."

    if docker load -i "$tar_file"; then # $tar_file is now validated
        log.done "Image loaded successfully from ${BOLD_GREEN}$tar_file${RESET_COLOR}."
    else
        log.error "Failed to load image from ${RED}$tar_file${RESET_COLOR}."
        return 1
    fi
    return 0
}