rename() {
    if [[ -n "${args[1]}" && -n "${args[2]}" ]]; then
        local current_name="${args[1]}"
        local new_name="${args[2]}"

        if [[ -n "${params[img]+set}" ]]; then
            image-renaming
        else
            container-renaming
        fi

    else

        log.hint "Usage: rename <current-name> <new-name> [-img]"
        return 1
    fi
}

container-renaming() {
    # Check if new_name already exists as a container
    if docker ps -a --format '{{.Names}}' | grep -q "^${new_name}$"; then
        log.warn "A container with the name '${new_name}' already exists."
        return 1
    fi

    # Check if current_name exists as a container
    if docker ps -a --format '{{.Names}}' | grep -q "^${current_name}$"; then
        docker rename "${current_name}" "${new_name}"
        if [[ $? -eq 0 ]]; then
            log.done "Container '${current_name}' renamed to '${new_name}'."
            return 0
        else
            log.error "Failed to rename container '${current_name}'."
            return 1
        fi
    else
        log.error "Container '${current_name}' does not exist."
        return 1
    fi
}

image-renaming() {
    # Check if new_name already exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${new_name}$"; then
        log.warn "An image with the tag '${new_name}' already exists."
        return 1
    fi

    # Check if current_name exists
    if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${current_name}$"; then
        docker tag "${current_name}" "${new_name}"
        if [[ $? -eq 0 ]]; then
            log.done "Image '${current_name}' retagged as '${new_name}'."
            return 0
        else
            log.error "Failed to tag image '${current_name}'."
            return 1
        fi
    else
        log.error "Image '${current_name}' does not exist."
        return 1
    fi
}

