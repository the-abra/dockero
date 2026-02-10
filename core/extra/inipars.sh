#!/usr/bin/env bash

# Usage:
#   inipars.get <section> <key> [file]
#   inipars.section <section> [file]
#   inipars.set <section> <key> <value> [file]
#   $CONF_FILE if setted, you dont need to set [file] again

# Helper function to escape regex metacharacters for sed/awk
_inipars_escape_regex() {
  echo "$1" | sed -e 's/[^^$.*+?|()\[{]/\\&/g'
}

inipars.get() {
  local section="$1"
  local key="$2"
  local file="${3:-$CONF_FILE}"

  local escaped_key=$(_inipars_escape_regex "$key")
  local escaped_section=$(_inipars_escape_regex "$section")

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

  local escaped_section=$(_inipars_escape_regex "$section")

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
  local escaped_section=$(_inipars_escape_regex "$section")
  local escaped_key=$(_inipars_escape_regex "$key")

  # Ensure the file exists
  if [[ ! -f "$file" ]]; then
    echo "[$section]" > "$file"
    echo "$key = $value" >> "$file"
    return 0
  fi

  # Check if the section exists
  if grep -q "^\[$escaped_section\]$" "$file"; then # Use escaped_section
    # Section exists, check if key exists within the section
    local -r SECTION_START_LINE=$(grep -n "^\[$escaped_section\]$" "$file" | cut -d: -f1) # Use escaped_section
    local -r NEXT_SECTION_LINE=$(grep -n "^\[.*\]$" "$file" | awk -v start_line="$SECTION_START_LINE" '$1 > start_line {print $1; exit}')

    if [[ -z "$NEXT_SECTION_LINE" ]]; then
      # Section is the last one or there are no other sections
      # Check if key exists from section start to EOF
      if awk -v start="$SECTION_START_LINE" -v k="$escaped_key" 'NR > start && $0 ~ "^[ \t]*"k"[ \t]*=" {exit 0} END {exit 1}' "$file"; then # Use escaped_key
        # Key exists in this section, update its value
        sed -i.bak -E "/^\[$escaped_section\]$/,/^\[.*\]$/ { s/^[ \t]*$escaped_key[ \t]*=.*/$key = $value/ }" "$file" # Use escaped_section and escaped_key
        rm -f "$file.bak"
      else
        # Key does not exist in this section, append it
        sed -i.bak -E "/^\[$escaped_section\]$/a\\$key = $value" "$file" # Use escaped_section
        rm -f "$file.bak"
      fi
    else
      # Section is not the last one
      # Check if key exists within this section (between SECTION_START_LINE and NEXT_SECTION_LINE)
      if awk -v start="$SECTION_START_LINE" -v end="$NEXT_SECTION_LINE" -v k="$escaped_key" 'NR > start && NR < end && $0 ~ "^[ \t]*"k"[ \t]*=" {exit 0} END {exit 1}' "$file"; then # Use escaped_key
        # Key exists in this section, update its value
        sed -i.bak -E "/^\[$escaped_section\]$/,/^\[.*\]$/ { /$escaped_key[ \t]*=/{s/^[ \t]*$escaped_key[ \t]*=.*/$key = $value/;q} }" "$file" # Use escaped_section and escaped_key
        rm -f "$file.bak"
      else
        # Key does not exist in this section, insert it before the next section
        sed -i.bak -E "$(($NEXT_SECTION_LINE - 1))a\\$key = $value" "$file"
        rm -f "$file.bak"
      fi
    fi
  else
    # Section does not exist, append section and key/value to the end of the file
    echo "" >> "$file" # Add a newline for separation if file is not empty
    echo "[$section]" >> "$file"
    echo "$key = $value" >> "$file"
  fi
}