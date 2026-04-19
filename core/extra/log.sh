#!/bin/bash
# shellcheck disable=SC2034
# log.sh - Centralized logging for Dockero

# ── Color setup ───────────────────────────────────────────────────────────────
RESET_COLOR="" BOLD="" DIM=""
COLOR_DATE="" COLOR_INFO="" COLOR_WARN="" COLOR_ERROR=""
COLOR_DONE="" COLOR_SUB="" COLOR_HINT="" COLOR_GENERIC=""
# Message body colors (distinct from prefix)
COLOR_MSG_INFO="" COLOR_MSG_WARN="" COLOR_MSG_ERROR=""
COLOR_MSG_DONE="" COLOR_MSG_SUB="" COLOR_MSG_HINT=""

if [[ "$TERM" != "dumb" ]] && command -v tput &>/dev/null && (( $(tput colors 2>/dev/null || echo 0) >= 8 )); then
    _DOCKERO_HAS_COLORS="true"
    RESET_COLOR=$(tput sgr0)
    BOLD=$(tput bold)
    DIM=$(tput dim 2>/dev/null || printf '\e[2m')

    # Prefix bracket colors (256-color where available, fallback to 8-color)
    COLOR_DATE=$(    printf '\e[38;5;240m')   # dark gray
    COLOR_INFO=$(    printf '\e[38;5;75m' )   # sky blue
    COLOR_WARN=$(    printf '\e[38;5;214m')   # orange
    COLOR_ERROR=$(   printf '\e[38;5;196m')   # bright red
    COLOR_DONE=$(    printf '\e[38;5;82m' )   # bright green
    COLOR_SUB=$(     printf '\e[38;5;245m')   # medium gray
    COLOR_HINT=$(    printf '\e[38;5;177m')   # soft purple
    COLOR_GENERIC=$( printf '\e[38;5;87m' )   # bright cyan

    # Message body colors
    COLOR_MSG_INFO=$( printf '\e[0;97m'    )  # bright white
    COLOR_MSG_WARN=$( printf '\e[38;5;229m')  # light yellow
    COLOR_MSG_ERROR=$(printf '\e[38;5;203m')  # salmon red
    COLOR_MSG_DONE=$( printf '\e[38;5;157m')  # light green
    COLOR_MSG_SUB=$(  printf '\e[38;5;250m')  # light gray
    COLOR_MSG_HINT=$( printf '\e[38;5;219m')  # light pink/purple
else
    _DOCKERO_HAS_COLORS="false"
fi

# ── Terminal width ────────────────────────────────────────────────────────────
columns=$(tput cols 2>/dev/null || echo "${COLUMNS:-80}")
[[ "$columns" -le 0 ]] && columns=80

# ── Internal prefix builder ───────────────────────────────────────────────────
_log_prefix() {
    local level_text="$1"
    local level_color="$2"
    local timestamp_str=""

    if [[ "${DOCKERO_LOG_TIMESTAMPS:-true}" == "true" ]]; then
        timestamp_str="${DIM}${COLOR_DATE}$(date +%H:%M:%S)${RESET_COLOR} "
    fi

    if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
        printf '%s%s%s%s%s%s' \
            "$timestamp_str" \
            "${DIM}${COLOR_SUB}[${RESET_COLOR}" \
            "${BOLD}${level_color}${level_text}${RESET_COLOR}" \
            "${DIM}${COLOR_SUB}]${RESET_COLOR}"
    else
        printf '%s[%s]' "$timestamp_str" "$level_text"
    fi
}

# ── Core log function ─────────────────────────────────────────────────────────
function log() {
    local level="$1" message="$2" prefix_color="$3" msg_color="$4" indent="$5"
    local prefix
    prefix="$(_log_prefix "$level" "$prefix_color")"
    if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
        echo -e "${indent}${prefix} ${msg_color}${message}${RESET_COLOR}"
    else
        echo -e "${indent}${prefix} ${message}"
    fi
}

# ── Log levels ────────────────────────────────────────────────────────────────
function log.info()  { log "INFO" "$1" "$COLOR_INFO"  "$COLOR_MSG_INFO"  "";    }
function log.warn()  { log "WARN" "$1" "$COLOR_WARN"  "$COLOR_MSG_WARN"  "";    }
function log.error() { log "FAIL" "$1" "$COLOR_ERROR" "$COLOR_MSG_ERROR" ""; return 1; }
function log.done()  { log "DONE" "$1" "$COLOR_DONE"  "$COLOR_MSG_DONE"  "";    }
function log.sub() {
    if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
        echo -e "              ${COLOR_SUB}›${RESET_COLOR} ${COLOR_MSG_SUB}${1}${RESET_COLOR}"
    else
        echo -e "               › ${1}"
    fi
}
function log.hint()  { log "HINT" "$1" "$COLOR_HINT"  "$COLOR_MSG_HINT"  ""; }

# ── Section line ──────────────────────────────────────────────────────────────
function log.setline() {
    local title="$1"
    local line_char="─"
    local total=$columns
    local line=""

    if [[ -n "$title" ]]; then
        local colored_title="${BOLD}${COLOR_GENERIC} ${title} ${RESET_COLOR}"
        local plain_len=$(( ${#title} + 2 ))  # +2 for spaces
        local side=$(( (total - plain_len) / 2 ))
        [[ $side -lt 1 ]] && side=1

        local left="" right=""
        for ((i=0; i<side; i++));       do left+="$line_char";  done
        for ((i=0; i<side; i++));       do right+="$line_char"; done
        # pad right by 1 if total is odd
        (( (side * 2 + plain_len) < total )) && right+="$line_char"

        if [[ "$_DOCKERO_HAS_COLORS" == "true" ]]; then
            line="${DIM}${COLOR_GENERIC}${left}${RESET_COLOR}${colored_title}${DIM}${COLOR_GENERIC}${right}${RESET_COLOR}"
        else
            line="${left} ${title} ${right}"
        fi
    else
        for ((i=0; i<total; i++)); do line+="$line_char"; done
        [[ "$_DOCKERO_HAS_COLORS" == "true" ]] && line="${DIM}${COLOR_GENERIC}${line}${RESET_COLOR}"
    fi

    echo -e "$line"
}

function log.endline() { echo ""; }
