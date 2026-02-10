#!/bin/bash
# shellcheck disable=SC2034

if [[ "${_DOCKERO_HAS_COLORS:-"false"}" == "true" ]]; then
    # COLOR
    BLACK=$'\e[0;30m'
    RED=$'\e[0;31m'
    GREEN=$'\e[0;32m'
    YELLOW=$'\e[0;33m'
    BLUE=$'\e[0;34m'
    MAGENTA=$'\e[0;35m'
    CYAN=$'\e[0;36m'
    WHITE=$'\e[0;37m'

    # BOLD
    BOLD_BLACK=$'\e[1;30m'
    BOLD_RED=$'\e[1;31m'
    BOLD_GREEN=$'\e[1;32m'
    BOLD_YELLOW=$'\e[1;33m'
    BOLD_BLUE=$'\e[1;34m'
    BOLD_MAGENTA=$'\e[1;35m'
    BOLD_CYAN=$'\e[1;36m'
    BOLD_WHITE=$'\e[1;37m'

    # BACKGROUND
    BG_BLACK=$'\e[40m'
    BG_RED=$'\e[41m'
    BG_GREEN=$'\e[42m'
    BG_YELLOW=$'\e[43m'
    BG_BLUE=$'\e[44m'
    BG_MAGENTA=$'\e[45m'
    BG_CYAN=$'\e[46m'
    BG_WHITE=$'\e[47m'

    # EFFECTS
    UNDERLINE=$'\e[4m'
    BLINK=$'\e[5m'
    REVERSE=$'\e[7m'
    HIDDEN=$'\e[8m'
    RESET_COLOR=$'\e[0m'
else
    # COLOR
    BLACK=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""

    # BOLD
    BOLD_BLACK=""
    BOLD_RED=""
    BOLD_GREEN=""
    BOLD_YELLOW=""
    BOLD_BLUE=""
    BOLD_MAGENTA=""
    BOLD_CYAN=""
    BOLD_WHITE=""

    # BACKGROUND
    BG_BLACK=""
    BG_RED=""
    BG_GREEN=""
    BG_YELLOW=""
    BG_BLUE=""
    BG_MAGENTA=""
    BG_CYAN=""
    BG_WHITE=""

    # EFFECTS
    UNDERLINE=""
    BLINK=""
    REVERSE=""
    HIDDEN=""
    RESET_COLOR=""
fi