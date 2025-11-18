#!/bin/bash
# log.lib - A Bash library for logging better.

# Color definitions using ANSI escape codes
RESET_COLOR="\033[0m"
COLOR_GENERIC="\033[35m"   # Magenta for date
COLOR_INFO="\033[34m"   # Blue for info
COLOR_WARN="\033[33m"   # Yellow for warnings
COLOR_ERROR="\033[31m"  # Red for errors
COLOR_DONE="\033[32m"   # Green for done messages

# If tput is available, use it for better portability
if command -v tput &> /dev/null; then
    RESET_COLOR=$(tput sgr0)
    COLOR_DATE=$(tput setaf 13)    # Pink for date
    COLOR_INFO=$(tput setaf 4)     # Blue
    COLOR_WARN=$(tput setaf 3)     # Yellow
    COLOR_ERROR=$(tput setaf 1)$(tput blink)    # Red with blink
    COLOR_DONE=$(tput setaf 2)     # Green
fi


# Try multiple methods to get terminal width
columns=$(tput cols 2>/dev/null || echo "$COLUMNS" || resize 2>/dev/null | awk '{print $3}' || echo 0)

# Function to log with a specific level
function log() {
    local level="$1"
    local color="$2"
    local message="$3"

    echo -e "${color}$level - ${RESET_COLOR} $message"
}

# Log levels
function log.info() {
    log "💠 INFO " "$COLOR_INFO" "$1" 
}

function log.warn() {
    log "⚠️  WARN " "$COLOR_WARN" "$1" 
}

function log.error() {
    log "❌ ERROR" "$COLOR_ERROR" "$1" 
}

function log.done() {
    log "✅ DONE " "$COLOR_DONE" "$1"
}

function log.sub() {
    #echo -e " ${RESET_COLOR}${COLOR_GENERIC}o \e[0;37m$1${RESET_COLOR}"
    echo -e "  ${RESET_COLOR}🔹 \e[0;37m$1${RESET_COLOR}"
}

log.hint() {
    echo -e "\n  ${RESET_COLOR}💡 \e[0;37m$1${RESET_COLOR}\n"
}

function log.setline() {
    # Get the size of the terminal
    local half=""
    local info=""
    [[ -n $1 ]] && info="/${COLOR_GENERIC}$1${RESET_COLOR}\\ ⚜️  "
    for ((i=1; i<=$(( columns - ${#info} )); i++)); do
        half+="-"
    done

    echo -e "$info$half"
}

function log.endline() {
    # Get the size of the terminal
    local half=""
    local info=""
    [[ -n $1 ]] && info="\\\\${COLOR_GENERIC}$1${RESET_COLOR}/ ⚜️  "
    for ((i=1; i<=$(( columns - ${#info} )); i++)); do
        half+="-"
    done

    echo -e "$info$half"
}


# Example usage
# log.info "This is an info message."
# log.warn "This is a warning message."
# log.error "This is an error message."
# log.done "This task is complete."
# log.hint "This is a tip message"
# log.sub "This is a subtask."

# --------------------------------------
# log.setline "Starting task"
# log.sub "This is a subtask."
# log.endline "Task completed"