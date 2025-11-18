#!/usr/bin/env bash

# Usage:
#   inipars.get <section> <key> [file]
#   inipars.section <section> [file]
#   inipars.set <section> <key> <value> [file]
#   $CONF_FILE if setted, you dont need to set [file] again

inipars.get() {
  local section="$1"
  local key="$2"
  local file="${3:-$CONF_FILE}"

  awk -F '=' -v section="$section" -v key="$key" '
    /^\[.*\]$/ {
      current_section = gensub(/\[|\]/, "", "g", $0)
    }
    current_section == section && $1 ~ "^"key"[ \t]*$" {
      gsub(/^[ \t]+|[ \t]+$/, "", $2)
      print $2
      exit
    }
  ' "$file"
}

inipars.section() {
  local section="$1"
  local file="${2:-$CONF_FILE}"

  awk -F '=' -v section="$section" '
    /^\[.*\]$/ {
      current_section = gensub(/\[|\]/, "", "g", $0)
      next
    }
    current_section == section && $1 !~ /^[#;]/ {
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

  [[ ! -f "$file" ]] && touch "$file"

  awk -v section="$section" -v key="$key" -v value="$value" '
    BEGIN {
      in_section = 0
      updated = 0
    }
    {
      if ($0 ~ "^[[][^]]+[]]$") {
        if (in_section && !updated) {
          print key " = " value
          updated = 1
        }
        in_section = ($0 == "[" section "]")
        print
        next
      }

      if (in_section && $1 == key) {
        print key " = " value
        updated = 1
        next
      }

      print
    }
    END {
      if (!updated) {
        if (!in_section) {
          print "[" section "]"
        }
        print key " = " value
      }
    }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}