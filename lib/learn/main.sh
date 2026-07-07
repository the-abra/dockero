#!/usr/bin/env bash

# core/learn/main.sh - The main entry point for the interactive learning system.

# shellcheck disable=SC1090
# shellcheck disable=SC1091
source "${CORE_DIR}/learn/helpers.sh"


_learn_main() {
    local level="${1:-}"
    local topic_num="${2:-}"

    if [[ -z "$level" ]]; then
        _learn_show_levels
        return 0
    fi

    case "$level" in
        "basics") _learn_show_topics "1_basics" ;;
        "intermediate") _learn_show_topics "2_intermediate" ;;
        "advanced") _learn_show_topics "3_advanced" ;;
        "examples") _learn_show_topics "4_examples" ;;
        *)
            log.error "Unknown level: ${BOLD_RED}$level${RESET_COLOR}"
            _learn_show_levels
            return 1
            ;;
    esac

    if [[ -n "$topic_num" ]]; then
        _learn_run_topic "$level" "$topic_num"
    fi
}

_learn_show_levels() {
    log.setline "${BOLD_CYAN}📚 Dockero Interactive Learning${RESET_COLOR}"
    log.info "Welcome to the interactive learning system for Docker and Dockero."
    echo ""
    log.info "Please choose a level to start:"
    log.sub "${BOLD_GREEN}dockero learn basics${RESET_COLOR}       - Start with the fundamentals."
    log.sub "${BOLD_GREEN}dockero learn intermediate${RESET_COLOR} - For those with some Docker experience."
    log.sub "${BOLD_GREEN}dockero learn advanced${RESET_COLOR}     - Dive into advanced topics."
    log.sub "${BOLD_GREEN}dockero learn examples${RESET_COLOR}     - Learn from real-world examples."
    echo ""
}

_learn_get_topic_title() {
    local topic_file="$1"
    # Extract the title from the topic file. Assumes a convention for titles.
    grep -m 1 "^# title:" "$topic_file" | sed 's/^# title: //'
}

_learn_show_topics() {
    local level_dir="$1"
    local level_name="${level_dir#*_}"
    log.setline "${BOLD_CYAN}📚 Dockero Learn - ${level_name^}${RESET_COLOR}"
    log.info "Please choose a topic to learn about:"
    
    local topic_files=("${CORE_DIR}/learn/topics/${level_dir}"/*.sh)
    for i in "${!topic_files[@]}"; do
        local topic_file="${topic_files[$i]}"
        local topic_title
        topic_title=$(_learn_get_topic_title "$topic_file")
        log.sub "${BOLD_GREEN}dockero learn $level_name $((i+1))${RESET_COLOR} - $topic_title"
    done
    echo ""
}

_learn_run_topic() {
    local level="$1"
    local topic_num="$2"
    local level_dir
    
    case "$level" in
        "basics") level_dir="1_basics" ;;
        "intermediate") level_dir="2_intermediate" ;;
        "advanced") level_dir="3_advanced" ;;
        "examples") level_dir="4_examples" ;;
        *) return 1 ;;
    esac

    local topic_files=("${CORE_DIR}/learn/topics/${level_dir}"/*.sh)
    local num_topics="${#topic_files[@]}"

    # Validate topic_num is a positive integer
    if ! [[ "$topic_num" =~ ^[1-9][0-9]*$ ]]; then
        log.error "Invalid topic number: ${BOLD_RED}$topic_num${RESET_COLOR}. Please provide a positive integer."
        _learn_show_topics "$level_dir"
        return 1
    fi

    local topic_index=$((topic_num - 1))

    # Validate topic_index is within bounds
    if (( topic_index < 0 || topic_index >= num_topics )); then
        log.error "Topic ${BOLD_RED}$topic_num${RESET_COLOR} not found for ${level_name^} level."
        _learn_show_topics "$level_dir"
        return 1
    fi

    if [[ -f "${topic_files[$topic_index]}" ]]; then
        # shellcheck disable=SC1090
        source "${topic_files[$topic_index]}"
        run_lesson
    else
        log.error "Invalid topic number: $topic_num"
        _learn_show_topics "$level_dir"
    fi
}
