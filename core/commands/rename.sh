#!/usr/bin/env bash

rename() {
    local current_name="${args[1]:-}"
    local new_name="${args[2]:-}"

    if [[ -z "$current_name" || -z "$new_name" ]]; then
        log.hint "Usage: ${BOLD_YELLOW}dockero rename <current-name> <new-name> [-img]${RESET_COLOR}"
        log.sub "  ${BOLD_CYAN}-img${RESET_COLOR}: Rename/retag an image instead of a container."
        return 1
    fi

    if [[ -n "${params[img]+set}" ]]; then
        image_renaming "$current_name" "$new_name"
    else
        container_renaming "$current_name" "$new_name"
    fi
}

container_renaming() {
    local current_name="$1"
    local new_name="$2"

    log.setline "${BOLD_CYAN}🔄 Renaming Container${RESET_COLOR}"

    # --- Input Validation ---
    if ! validate_container_name "$current_name"; then log.error "Invalid current container name: ${RED}$current_name${RESET_COLOR}."; return 1; fi
    if ! validate_container_name "$new_name"; then log.error "Invalid new container name: ${RED}$new_name${RESET_COLOR}."; return 1; fi

    # Check if new_name already exists as a container
    if docker ps -a --format '{{.Names}}' | grep -q "^$new_name$"; then
        log.error "A container with the name '${RED}$new_name${RESET_COLOR}' already exists."
        return 1
    fi

    # Check if current_name exists as a container
    if docker ps -a --format '{{.Names}}' | grep -q "^$current_name$"; then
        log.info "Renaming container '${BOLD_YELLOW}$current_name${RESET_COLOR}' to '${BOLD_YELLOW}$new_name${RESET_COLOR}'."
        if docker rename "$current_name" "$new_name"; then # Names are validated
            log.done "Container '${BOLD_GREEN}$current_name${RESET_COLOR}' renamed to '${BOLD_GREEN}$new_name${RESET_COLOR}' successfully."
            return 0
        else
            log.error "Failed to rename container '${RED}$current_name${RESET_COLOR}'."
            return 1
        fi
    else
        log.error "Container '${RED}$current_name${RESET_COLOR}' does not exist."
        return 1
    fi
}

image_renaming() {
    local current_image_tag="$1"
    local new_image_tag="$2"

    log.setline "${BOLD_CYAN}🔄 Retagging Image${RESET_COLOR}"
    log.info "Note: This operation retags the image. The old tag '${BOLD_YELLOW}$current_image_tag${RESET_COLOR}' will still exist unless you remove it manually."

    # --- Input Validation ---
    if ! validate_image_name "$current_image_tag"; then log.error "Invalid current image tag: ${RED}$current_image_tag${RESET_COLOR}."; return 1; fi
    if ! validate_image_name "$new_image_tag"; then log.error "Invalid new image tag: ${RED}$new_image_tag${RESET_COLOR}."; return 1; fi

    # Check if new_image_tag already exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$new_image_tag$"; then # new_image_tag is validated
        log.error "An image with the tag '${RED}$new_image_tag${RESET_COLOR}' already exists."
        return 1
    fi

    # Check if current_image_tag exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$current_image_tag$"; then # current_image_tag is validated
        log.info "Retagging image '${BOLD_YELLOW}$current_image_tag${RESET_COLOR}' as '${BOLD_YELLOW}$new_image_tag${RESET_COLOR}'."
        if docker tag "$current_image_tag" "$new_image_tag"; then # Tags are validated
            log.done "Image '${BOLD_GREEN}$current_image_tag${RESET_COLOR}' retagged as '${BOLD_GREEN}$new_image_tag${RESET_COLOR}' successfully."
            log.hint "To remove the old tag, use: ${BOLD_YELLOW}dockero remove '$current_image_tag' -img${RESET_COLOR}"
            return 0
        else
            log.error "Failed to tag image '${RED}$current_image_tag${RESET_COLOR}'."
            return 1
        fi
    else
        log.error "Image '${RED}$current_image_tag${RESET_COLOR}' does not exist."
        return 1
    fi
}