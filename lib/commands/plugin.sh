#!/usr/bin/env bash

plugin_help() {
cat << EOF
${BOLD_CYAN}🔹 dockero plugin ${GREEN}<subcommand> [args]${RESET_COLOR}
   ${BOLD_WHITE}• Purpose:${RESET_COLOR} Manage custom subcommands/plugins.
   ${BOLD_WHITE}• Subcommands:${RESET_COLOR}
     - ${GREEN}list${RESET_COLOR}                       List all installed user plugins.
     - ${GREEN}install <name> <url>${RESET_COLOR}     Download and install a plugin from a raw URL.
     - ${GREEN}remove/delete <name>${RESET_COLOR}    Uninstall a plugin.
   ${BOLD_WHITE}• Usage:${RESET_COLOR}
     dockero plugin install mycmd https://raw.githubusercontent.com/user/repo/main/mycmd.sh
EOF
}

plugin() {
    local subcmd="${args[1]:-}"
    local name="${args[2]:-}"
    local url="${args[3]:-}"

    local plugin_dir="${HOME}/.dockero/commands"

    case "$subcmd" in
        list)
            log.setline "${BOLD_CYAN}🔌 Installed Plugins${RESET_COLOR}"
            mkdir -p "$plugin_dir"
            local found=0
            for file in "$plugin_dir"/*.sh; do
                if [[ -f "$file" ]]; then
                    local plugin_name
                    plugin_name=$(basename "$file" .sh)
                    echo -e "  • ${BOLD_GREEN}${plugin_name}${RESET_COLOR}"
                    # Check if a help function is defined by sourcing in a subshell
                    local help_desc=""
                    if help_desc=$( (source "$file" && declare -f "${plugin_name}_help" >/dev/null && "${plugin_name}_help" | head -n 1) 2>/dev/null ); then
                        if [[ -n "$help_desc" ]]; then
                            echo -e "    ${help_desc}"
                        fi
                    fi
                    found=1
                fi
            done
            if [[ $found -eq 0 ]]; then
                log.info "No plugins installed yet."
                log.hint "Install one using: ${BOLD_YELLOW}dockero plugin install <name> <url>${RESET_COLOR}"
            fi
            ;;
        install)
            if [[ -z "$name" || -z "$url" ]]; then
                log.error "Missing plugin name or URL."
                log.hint "Usage: ${BOLD_YELLOW}dockero plugin install <name> <url>${RESET_COLOR}"
                return 1
            fi
            if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                log.error "Invalid plugin name. Only alphanumeric characters, hyphens, and underscores are allowed."
                return 1
            fi
            
            mkdir -p "$plugin_dir"
            local dest_file="${plugin_dir}/${name}.sh"

            log.info "Downloading plugin '${BOLD_YELLOW}${name}${RESET_COLOR}' from URL..."
            
            local download_success=false
            if command -v curl &>/dev/null; then
                if curl -fsSL -o "$dest_file" "$url"; then
                    download_success=true
                fi
            elif command -v wget &>/dev/null; then
                if wget -q -O "$dest_file" "$url"; then
                    download_success=true
                fi
            else
                log.error "Neither curl nor wget is installed on this system. Cannot download plugin."
                return 1
            fi

            if [[ "$download_success" == "true" ]]; then
                chmod +x "$dest_file"
                log.done "Plugin '${BOLD_GREEN}${name}${RESET_COLOR}' successfully installed!"
                log.hint "Run it using: ${BOLD_YELLOW}dockero ${name}${RESET_COLOR}"
            else
                log.error "Failed to download plugin from ${RED}${url}${RESET_COLOR}."
                rm -f "$dest_file"
                return 1
            fi
            ;;
        remove|delete)
            if [[ -z "$name" ]]; then
                log.error "Missing plugin name to remove."
                log.hint "Usage: ${BOLD_YELLOW}dockero plugin remove <name>${RESET_COLOR}"
                return 1
            fi
            local dest_file="${plugin_dir}/${name}.sh"
            if [[ -f "$dest_file" ]]; then
                rm -f "$dest_file"
                log.done "Plugin '${BOLD_GREEN}${name}${RESET_COLOR}' successfully removed."
            else
                log.error "Plugin '${RED}${name}${RESET_COLOR}' is not installed."
                return 1
            fi
            ;;
        *)
            log.error "Unknown plugin subcommand: ${BOLD_RED}${subcmd:-None}${RESET_COLOR}"
            log.hint "Usage: ${BOLD_YELLOW}dockero plugin [list|install|remove] [args]${RESET_COLOR}"
            return 1
            ;;
    esac
}
