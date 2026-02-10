#!/usr/bin/env bash

# Usage:
#   inipars.get <section> <key> [file]
#   inipars.section <section> [file]
#   inipars.set <section> <key> <value> [file]
#   $CONF_FILE if setted, you dont need to set [file] again

# Helper function to escape regex metacharacters for sed/awk
# _inipars_escape_regex() {
#   echo "$1" | sed -e 's/[^^$.*+?|()\[{]/\\&/g'
# }
# Helper function to escape regex metacharacters for sed/awk
# shellcheck disable=SC2001
_inipars_escape_regex() {
  echo "$1" | sed -e 's/[^^$.*+?|()\[{]/\\&/g'
}

# Helper: Ensure file exists; if not, create it with the initial section and key/value
_inipars_ensure_file_exists() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"

  if [[ ! -f "$file" ]]; then
    log.info "Creating new INI file: ${BOLD_YELLOW}$file${RESET_COLOR}"
    echo "[$section]" > "$file"
    echo "$key = $value" >> "$file"
    return 0 # File created and initial content added
  fi
  return 1 # File already exists
}

# Helper: Get start and end line numbers for a section
# Sets two variables passed by reference: start_line and end_line
_inipars_get_section_bounds() {
  local file="$1"
  local escaped_section="$2"
  local __start_line_ref="$3" # Variable to store start line
  local __end_line_ref="$4"   # Variable to store end line (next section or EOF)

  local section_start_line
  section_start_line=$(grep -n "^\[$escaped_section\]$" "$file" | cut -d: -f1)
  if [[ -z "$section_start_line" ]]; then
    return 1 # Section not found
  fi

  # Find the line number of the next section, or EOF if this is the last section
  local next_section_line
  next_section_line=$(grep -n "^\[.*\]$" "$file" | awk -v start_line="$section_start_line" '$1 > start_line {print $1; exit}')

  eval "$__start_line_ref='$section_start_line'"
  eval "$__end_line_ref='${next_section_line:-$(wc -l < "$file")}'" # Default to EOF if no next section
  return 0
}

# Helper: Check if a key exists within a specific section range
_inipars_key_exists_in_section_range() {
  local file="$1"
  local start_line="$2"
  local end_line="$3"
  local escaped_key="$4"

  # awk: within the section's lines, check if a line starts with the key followed by =
  awk -v start="$start_line" -v end="$end_line" -v k="$escaped_key" '
    NR > start && (end == 0 || NR < end) && $0 ~ "^[ \t]*"k"[ \t]*=" { found=1; exit }
    END { exit !found } # Exit 0 if found, 1 if not
  ' "$file"
}

# Helper: Update an existing key's value within a section
_inipars_update_key_in_file() {
  local file="$1"
  local escaped_section="$2" # This is used by the section matching in awk
  local escaped_key="$3"     # This is used by the key matching in awk
  local key="$4"             # Original, unescaped key
  local value="$5"           # Original, unescaped value

  # Use awk to update the key's value within its section
  # This approach is more robust for passing variables and avoids sed's string interpolation issues.
  awk -v target_section="[$escaped_section]" \
      -v target_key_pattern="^[ \t]*${escaped_key}[ \t]*=" \
      -v new_line="${key} = ${value}" \
      'BEGIN { in_target_section = 0 }
       $0 == target_section {
           in_target_section = 1
           print
           next
       }
       /^\[.*\]$/ { # New section header
           in_target_section = 0
           print
           next
       }
       in_target_section && $0 ~ target_key_pattern {
           print new_line
           next
       }
       { print }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  return 0
}

# Helper: Add a new key/value to a section
_inipars_add_key_to_section_in_file() {
  local file="$1"
  local escaped_section="$2"
  local key="$3"
  local value="$4"
  local insert_before_line="$5" # Line number before which to insert

  # If insert_before_line is 0 (i.e., this is the last section), append to EOF
  if [[ "$insert_before_line" -eq 0 ]]; then
    sed -i.bak -E "/^\[$escaped_section\]$/a\\$key = $value" "$file"
  else
    # Insert before the specified line (which is the start of the next section)
    sed -i.bak -E "$((insert_before_line - 1))a\\$key = $value" "$file"
  fi
  rm -f "$file.bak"
  return 0
}

# Helper: Append a new section and key/value to the end of the file
_inipars_add_section_and_key_to_file() {
  local file="$1"
  local section="$2"
  local key="$3"
  local value="$4"

  # Add a newline for separation if file is not empty
  [[ -s "$file" ]] && echo "" >> "$file"
  echo "[$section]" >> "$file"
  echo "$key = $value" >> "$file"
  return 0
}

inipars.get() {
  local section="$1"
  local key="$2"
  local file="${3:-$CONF_FILE}"

  local escaped_key
  escaped_key=$(_inipars_escape_regex "$key")
  local escaped_section
  escaped_section=$(_inipars_escape_regex "$section")

  awk -F '=' -v section_name="$escaped_section" -v key_name="$escaped_key" '
    /^\[.*\]$/ {
      current_section = gensub(/\[|\]/, "", "g", $0)
    }
    current_section == section_name && $1 ~ "^"key_name"[ \t]*$" {
      gsub(/^[ \t]+|[ \t]+$/, "", $2)
      print $2
      exit
    }
  ' "$file"
}

inipars.section() {
  local section="$1"
  local file="${2:-$CONF_FILE}"

  local escaped_section
  escaped_section=$(_inipars_escape_regex "$section")

  awk -F '=' -v section_name="$escaped_section" '
    /^\[.*\]$/ {
      current_section = gensub(/\[|\]/, "", "g", $0)
      next
    }
    current_section == section_name && $1 !~ /^[#;]/ {
      gsub(/^[ \t]+|[ \t]+$/, "", $1)
      gsub(/^[ \t]+|[ \t]+$/, "", $2)
      print $1 "=" $2
    }
  ' "$file"
}

inipars.set() {
  local section="$1"
  local key="$2"
  local value="$3"
  local file="${4:-$CONF_FILE}"

  # Escape section and key for regex use
  local escaped_section
  escaped_section=$(_inipars_escape_regex "$section")
  local escaped_key
  escaped_key=$(_inipars_escape_regex "$key")

  # 1. Ensure the file exists, creating it with initial content if necessary
  if _inipars_ensure_file_exists "$file" "$section" "$key" "$value"; then
      return 0 # File was just created and content added
  fi

  # 2. File now exists. Get section bounds or append if section is new.
  local section_start_line=""
  local section_end_line="" # Line number of next section or EOF

  if _inipars_get_section_bounds "$file" "$escaped_section" section_start_line section_end_line; then
      # Section exists. Check if key exists within this section.
      if _inipars_key_exists_in_section_range "$file" "$section_start_line" "$section_end_line" "$escaped_key"; then
          # Key exists, update its value.
          _inipars_update_key_in_file "$file" "$escaped_section" "$escaped_key" "$key" "$value"
      else
          # Key does not exist, add it to the section.
          _inipars_add_key_to_section_in_file "$file" "$escaped_section" "$key" "$value" "$section_end_line"
      fi
  else
      # Section does not exist, append the new section and key/value.
      _inipars_add_section_and_key_to_file "$file" "$section" "$key" "$value"
  fi
  return 0
}