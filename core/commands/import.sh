import() {
    [[ -z "${args[1]}" ]] && log.hint "import </path/to/archive.tar>" && return 1
    [[ -n "${params[*]}" ]] && log.warn "import command cannot accept parameters!" && return 1

    local tar_file="${args[1]}"

    if [[ ! -f "$tar_file" ]]; then
        log.error "File not found: $tar_file"
        return 1
    fi

    if docker load -i ${tar_file}; then
        log.done "Image loaded successfully"
    else
        log.error "Failed to load image from $tar_file."
        return 1
    fi
}