#!/usr/bin/env bash

# Usage:
#   inipars.get <section> <key> [file]
#   inipars.section <section> [file]
#   inipars.set <section> <key> <value> [file]
#   $CONF_FILE if setted, you dont need to set [file] again

# Helper function to escape regex metacharacters for sed/awk
_inipars_escape_regex() {
  printf '%s\n' "${1:-}" | sed -e 's/[][\\.^$*+?|(){}]/\\&/g'
}

# Helper: Ensure file exists; if not, create it with the initial section and key/value
_inipars_ensure_file_exists() {
  local file="${1:-}"
  local section="${2:-}"
  local key="${3:-}"
  local value="${4:-}"

  if [[ ! -f "$file" ]]; then
    log.info "Creating new INI file: ${BOLD_YELLOW}$file${RESET_COLOR}"
    echo "[$section]" > "$file"
    echo "$key = $value" >> "$file"
    return 0 # File created and initial content added
  fi
  return 1 # File already exists
}

# Helper: Check if a section exists in the file
_inipars_section_exists() {
  local file="${1:-}"
  local escaped_section="${2:-}"
  grep -q "^\[$escaped_section\]$" "$file" 2>/dev/null
}

# Helper: Check if a key exists within a specific section
_inipars_key_exists_in_section() {
  local file="${1:-}"
  local escaped_section="${2:-}"
  local escaped_key="${3:-}"

  awk -v sec="[$escaped_section]" -v k="^[ \t]*${escaped_key}[ \t]*=" '
    BEGIN { in_sec = 0; found = 0 }
    $0 == sec { in_sec = 1; next }
    in_sec && /^\[.*\]$/ { in_sec = 0; next }
    in_sec && $0 ~ k { found = 1; exit }
    END { exit !found }
  ' "$file" 2>/dev/null
}

# Helper: Update an existing key's value within a section
_inipars_update_key_in_file() {
  local file="${1:-}"
  local escaped_section="${2:-}"
  local escaped_key="${3:-}"
  local key="${4:-}"
  local value="${5:-}"

  awk -v target_section="[$escaped_section]" \
      -v target_key_pattern="^[ \t]*${escaped_key}[ \t]*=" \
      -v new_line="${key} = ${value}" \
      'BEGIN { in_target_section = 0 }
       $0 == target_section {
           in_target_section = 1
           print
           next
       }
       /^\[.*\]$/ {
           in_target_section = 0
           print
           next
       }
       in_target_section && $0 ~ target_key_pattern {
           print new_line
           next
       }
       { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Helper: Add a new key/value to an existing section
_inipars_add_key_to_section_in_file() {
  local file="${1:-}"
  local escaped_section="${2:-}"
  local key="${3:-}"
  local value="${4:-}"

  awk -v target_section="[$escaped_section]" \
      -v new_line="${key} = ${value}" \
      'BEGIN { in_target = 0; added = 0 }
       $0 == target_section {
         in_target = 1
         print
         next
       }
       in_target && /^\[.*\]$/ {
         if (!added) {
           print new_line
           added = 1
         }
         in_target = 0
         print
         next
       }
       { print }
       END {
         if (in_target && !added) {
           print new_line
         }
       }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

# Helper: Append a new section and key/value to the end of the file
_inipars_add_section_and_key_to_file() {
  local file="${1:-}"
  local section="${2:-}"
  local key="${3:-}"
  local value="${4:-}"

  [[ -s "$file" ]] && echo "" >> "$file"
  echo "[$section]" >> "$file"
  echo "$key = $value" >> "$file"
}

inipars.get() {
  local section="${1:-}"
  local key="${2:-}"
  local file="${3:-${CONF_FILE:-}}"

  [[ -z "$file" || ! -f "$file" ]] && return 1

  local escaped_key
  escaped_key=$(_inipars_escape_regex "$key")
  local escaped_section
  escaped_section=$(_inipars_escape_regex "$section")

  awk -v section_name="$escaped_section" -v key_name="$escaped_key" '
    /^\[.*\]$/ {
      current_section = $0
      gsub(/^\[|\]$/, "", current_section)
      next
    }
    current_section == section_name {
      line = $0
      sub(/^[ \t]+/, "", line)
      if (line ~ "^" key_name "[ \t]*=") {
        sub("^" key_name "[ \t]*=[ \t]*", "", line)
        sub(/[ \t]+$/, "", line)
        print line
        exit
      }
    }
  ' "$file" 2>/dev/null
}

inipars.section() {
  local section="${1:-}"
  local file="${2:-${CONF_FILE:-}}"

  [[ -z "$file" || ! -f "$file" ]] && return 1

  local escaped_section
  escaped_section=$(_inipars_escape_regex "$section")

  awk -v section_name="$escaped_section" '
    /^\[.*\]$/ {
      current_section = $0
      gsub(/^\[|\]$/, "", current_section)
      next
    }
    current_section == section_name && $0 !~ /^[ \t]*[#;]/ {
      line = $0
      sub(/^[ \t]+/, "", line)
      sub(/[ \t]+$/, "", line)
      if (line ~ /=/) {
        print line
      }
    }
  ' "$file" 2>/dev/null
}

inipars.set() {
  local section="${1:-}"
  local key="${2:-}"
  local value="${3:-}"
  local file="${4:-${CONF_FILE:-}}"

  [[ -z "$file" ]] && return 1

  # Escape section and key for regex use
  local escaped_section
  escaped_section=$(_inipars_escape_regex "$section")
  local escaped_key
  escaped_key=$(_inipars_escape_regex "$key")

  # 1. Ensure the file exists, creating it with initial content if necessary
  if _inipars_ensure_file_exists "$file" "$section" "$key" "$value"; then
      return 0
  fi

  # 2. Check if section exists
  if _inipars_section_exists "$file" "$escaped_section"; then
      if _inipars_key_exists_in_section "$file" "$escaped_section" "$escaped_key"; then
          _inipars_update_key_in_file "$file" "$escaped_section" "$escaped_key" "$key" "$value"
      else
          _inipars_add_key_to_section_in_file "$file" "$escaped_section" "$key" "$value"
      fi
  else
      _inipars_add_section_and_key_to_file "$file" "$section" "$key" "$value"
  fi
  return 0
}