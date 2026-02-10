#!/bin/bash
# shellcheck disable=SC2034
# log.lib - A Bash library for logging better.

# Color definitions (using tput for portability if available, otherwise ANSI)
RESET_COLOR=""
BOLD=""
COLOR_DATE=""
COLOR_INFO=""
COLOR_WARN=""
COLOR_ERROR=""
COLOR_DONE=""
COLOR_SUB=""
COLOR_HINT=""
COLOR_GENERIC="" # For section headers

if command -v tput &> /dev/null; then
    if (( $(tput colors 2>/dev/null || echo 0) >= 8 )); then
        _DOCKERO_HAS_COLORS="true"
        RESET_COLOR=$(tput sgr0)
        BOLD=$(tput bold)
        COLOR_DATE=$(tput setaf 8)      # Gray
        COLOR_INFO=$(tput setaf 4)      # Blue
        COLOR_WARN=$(tput setaf 3)      # Yellow
        COLOR_ERROR=$(tput setaf 1)     # Red
        COLOR_DONE=$(tput setaf 2)      # Green
        COLOR_SUB=$(tput setaf 7)       # White/Light Gray
        COLOR_HINT=$(tput setaf 5)      # Magenta
        COLOR_GENERIC=$(tput setaf 6)   # Cyan
    else
        _DOCKERO_HAS_COLORS="false"
    fi
else
    # Fallback to ANSI if tput is not available or no colors
    _DOCKERO_HAS_COLORS="true" # Assume ANSI is supported, but no tput control
    RESET_COLOR="\033[0m"
    BOLD="\033[1m"
    COLOR_DATE="\033[38;5;240m" # Darker gray
    COLOR_INFO="\033[34m"   # Blue
    COLOR_WARN="\033[33m"   # Yellow
    COLOR_ERROR="\033[31m"  # Red
    COLOR_DONE="\033[32m"   # Green
    COLOR_SUB="\033[37m"    # White
    COLOR_HINT="\033[35m"   # Magenta
    COLOR_GENERIC="\033[36m" # Cyan
    if [[ "$TERM" == "dumb" ]]; then # If terminal is dumb, disable colors
        _DOCKERO_HAS_COLORS="false"
        RESET_COLOR=""
        BOLD=""
        COLOR_DATE=""
        COLOR_INFO=""
        COLOR_WARN=""
        COLOR_ERROR=""
        COLOR_DONE=""
        COLOR_SUB=""
        COLOR_HINT=""
        COLOR_GENERIC=""
    fi
fi

# Try multiple methods to get terminal width
columns=$(tput cols 2>/dev/null || echo "$COLUMNS" || resize 2>/dev/null | awk '{print $3}' || echo 0)
# Default to 80 if not detectable
[[ "$columns" -eq 0 ]] && columns=80

_log_prefix() {
    local level_text="$1"
    local level_color="$2"
    local show_timestamp="${DOCKERO_LOG_TIMESTAMPS:-true}" # Default to true
    local timestamp_str=""

    if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
        if [[ "$show_timestamp" == "true" ]]; then
            timestamp_str="${COLOR_DATE}$(date +%H:%M:%S)${RESET_COLOR} "
        fi
        echo -e "${timestamp_str}${level_color}${BOLD}[${level_text}]${RESET_COLOR}"
    else
        if [[ "$show_timestamp" == "true" ]]; then
            timestamp_str="$(date +%H:%M:%S) "
        fi
        echo -e "${timestamp_str}[${level_text}]"
    fi
}

# Main logging function
function log() {
    local level="$1"
    local message="$2"
    local prefix_color="$3"
    local message_color="$4"
    local indent="$5"

    local prefix="$(_log_prefix "$level" "$prefix_color")"
    if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
        echo -e "${indent}${prefix} ${message_color}${message}${RESET_COLOR}"
    else
        echo -e "${indent}${prefix} ${message}"
    fi
}

# Log levels
function log.info() {
    log "INFO " "$1" "$COLOR_INFO" "$RESET_COLOR" ""
}

function log.warn() {
    log "WARN " "$1" "$COLOR_WARN" "$COLOR_WARN" ""
}

function log.error() {
    log "ERROR" "$1" "$COLOR_ERROR" "$COLOR_ERROR" ""
    return 1 # Error logs should indicate a failure
}

function log.done() {
    log "DONE " "$1" "$COLOR_DONE" "$RESET_COLOR" ""
}

function log.sub() {
    log "SUB  " "$1" "$COLOR_SUB" "$COLOR_SUB" "  " # Indented
}

function log.hint() {
    log "HINT " "$1" "$COLOR_HINT" "$COLOR_HINT" "  " # Indented
}

function log.setline() {
    local title="$1"
    local line_char="-"
    local padding_char=" "
    local total_length="${columns}"
    local line=""

    if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
        title="${COLOR_GENERIC}${BOLD}${title}${RESET_COLOR}"
    fi

    if [[ -n "$title" ]]; then
        # Calculate available space for the line characters
        local text_length=$(( $(echo "$title" | sed 's/\x1b\[[0-9;]*m//g' | wc -c) - 1 + 2 * ${#padding_char} )) # strip ANSI codes for length
        local line_length=$(( (total_length - text_length) / 2 ))
        
        # Build the line
        for ((i=0; i<line_length; i++)); do line+="${line_char}"; done
        line="${line}${padding_char}${title}${padding_char}"
        for ((i=0; i<line_length; i++)); do line+="${line_char}"; done

        # If length is odd and terminal is even, add one more char
        if (( ${#line} < total_length )); then
            line+="${line_char}"
        fi
    else
        for ((i=0; i<total_length; i++)); do line+="${line_char}"; fi
    fi
    echo -e "${line}"
}

function log.endline() {
    # For now, endline will just print an empty line for visual separation
    # Or could be identical to setline without a title
    echo ""
}
