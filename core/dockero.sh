#!/usr/bin/env bash

# === Project Root Detection ===
if [ -L "$0" ] ; then
    CORE_DIR=$(dirname "$(readlink -f "$0")") ;
else
    CORE_DIR=$(dirname "$0") ;
fi ;
COMMANDS_DIR="${CORE_DIR}/commands"

# === Load Configuration ===
DEFAULT_CONFIG="${CORE_DIR}/extra/config.sh"
USER_CONFIG="${HOME}/.dockero/config"

# Source default configuration
if [[ -f "$DEFAULT_CONFIG" ]]; then
    # shellcheck disable=SC1090,SC1091
    source "$DEFAULT_CONFIG"
fi

# Override with user configuration if it exists
if [[ -f "$USER_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$USER_CONFIG"
fi

# === sources ===
# shellcheck disable=SC1091
source "${CORE_DIR}/extra/log.sh"
# shellcheck disable=SC1091
source "${CORE_DIR}/extra/colors.sh"
# shellcheck disable=SC1091
source "${CORE_DIR}/extra/inipars.sh"
# shellcheck disable=SC1091
source "${CORE_DIR}/parameter-indexing.sh"

# === Parameter Indexing ===
parameter-indexing "$@"

# Initialize args array if not already done (defensive programming)
if [[ ${#args[@]} -eq 0 ]]; then
    # Fallback to original arguments if parameter-indexing didn't populate args
    for arg in "$@"; do
        if [[ ! "$arg" =~ ^- ]]; then
            args+=("$arg")
        fi
    done
fi

# === Version Info ===
DOCKERO_VERSION="0.1.1"

# === Validation Functions ===
validate_container_name() {
    local name="$1"
    # Docker container names must match this regex: [a-zA-Z0-9][a-zA-Z0-9_.-]+
    if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]; then
        log.error "Invalid container name: $name"
        log.hint "Container names must start with alphanumeric and contain only [a-zA-Z0-9_.-]"
        return 1
    fi
}

validate_image_name() {
    local name="$1"
    # Basic validation for image names
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+(/[a-zA-Z0-9._-]+)*(:[a-zA-Z0-9._-]+)?$ ]]; then
        log.error "Invalid image name: $name"
        log.hint "Image names should follow format: [registry/]name[:tag]"
        return 1
    fi
}

# === Dynamic Command Loader ===
load_command() {
  local cmd_file="${COMMANDS_DIR}/${1}.sh"
  if [[ -f "$cmd_file" ]]; then
    # shellcheck disable=SC1090
    source "$cmd_file"
    # Validate the command function exists
    if declare -f "$1" >/dev/null 2>&1; then
        "${1}" "${@:2}"
    else
        log.error "Command function '$1' is not defined in $cmd_file"
        exit 1
    fi
  else
    log.error "Unknown command '$1'"
    log.hint "Run '$0 -h' for usage."
    exit 1
  fi
}

# === Version Command Handler ===
show_version() {
  echo -e "${BOLD_CYAN}Dockero CLI${RESET_COLOR} ${BOLD_YELLOW}v$DOCKERO_VERSION${RESET_COLOR}"
  echo -e "Simplified Docker CLI with Autocompletion"
  echo -e "Runtime: ${BOLD_GREEN}${DOCKERO_RUNTIME:-docker}${RESET_COLOR}"
  echo -e "Default Port: ${BOLD_GREEN}${DOCKERO_DEFAULT_PORT:-80}${RESET_COLOR}"
  exit 0
}

# === Entrypoint ===

# Check if first argument is for Python-enhanced commands
if [[ "${args[0]}" == "tui" || "${args[0]}" == "dashboard" ]]; then
  # Try to run the Python TUI if Python is available
  if command -v python3 >/dev/null 2>&1; then
    "${CORE_DIR}/extra/run-python-ux.sh" "${args[0]}"  # Pass the actual command ('tui' or 'dashboard')
  else
    log.warn "Python3 not found. Running basic dashboard instead."
    # shellcheck disable=SC1091
    source "${COMMANDS_DIR}/show.sh"
    show_dashboard
  fi
  exit 0
elif [[ -n "${params[v]+set}" || -n "${params[version]+set}" || "${args[0]}" == 'version' ]]; then
  show_version
elif [[ -n "${params[h]+set}"  || -n "${params[help]+set}" || -z "${args[0]}" ]]; then
   # shellcheck disable=SC1091
   source "${COMMANDS_DIR}/help.sh"
   help-"${args[0]}"
   log.setline
   exit 0
fi

load_command "${args[0]}"

