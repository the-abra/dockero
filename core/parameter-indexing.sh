#!/bin/bash

declare -A params  # Named parameters: --key value
args=()            # Positional arguments
full_arr=($@)

parameter-indexing() {
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|--help) # Boolen TRUE sign
      key="${1##--}"
      params["$key"]="true"
      shift
      ;;
    --*) # Dynamic Named
      key="${1##--}"
      [[ -z $2 ]] && log.error "You must set value of --$key" && exit 1
      params["$key"]="$2"
      shift 2
      ;;
    -*) # Dynamic Named
      key="${1##-}"
      params["$key"]="true"
      shift 
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
