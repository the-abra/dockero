#!/bin/bash
# shellcheck disable=SC2034

declare -A params  # Named parameters: --key value
args=()            # Positional arguments
full_arr=("$@")

parameter-indexing() {
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|--help) # Boolean TRUE flags
      key="${1##--}"
      params["$key"]="true"
      shift
      ;;
    --*) # Long named params: --key value
      key="${1##--}"
      if [[ -n "${2:-}" && "${2}" != -* ]]; then
        params["$key"]="$2"
        shift 2
      else
        # Treat as boolean if no value follows
        params["$key"]="true"
        shift
      fi
      ;;
    -*) # Short flags: -f value or -f (boolean)
      key="${1##-}"
      if [[ ${#key} -eq 1 && -n "${2:-}" && "${2}" != -* ]]; then
        # Single-char flag followed by a non-flag value → treat as key=value
        params["$key"]="$2"
        shift 2
      else
        params["$key"]="true"
        shift
      fi
      ;;
    *)   # Positional argument
      args+=("$1")
      shift
      ;;
  esac
done
}

# 🔹 Access named parameters
# echo "Name param: ${params[name]}"
# echo "Env param: ${params[env]}"

# 🔹 Access by index
# echo "First positional arg: ${args[0]}"
# echo "Second positional arg: ${args[1]}"
