#!/usr/bin/env bash

# Cache configuration
DOCKERO_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dockero"
DOCKERO_CACHE_TTL=2  # Cache lifetime in seconds

# Ensure cache directory exists
mkdir -p "$DOCKERO_CACHE_DIR" 2>/dev/null

# Fast cache read with TTL check
_dockero_get_cache() {
  local cache_file="$DOCKERO_CACHE_DIR/$1"
  local ttl="${2:-$DOCKERO_CACHE_TTL}"
  local age
  
  if [[ -f "$cache_file" ]]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null) ))
    if (( age < ttl )); then
      cat "$cache_file"
      return 0
    fi
  fi
  return 1
}

# Async cache update (non-blocking)
_dockero_update_cache() {
  local cache_file="$DOCKERO_CACHE_DIR/$1"
  shift
  (
    "$@" > "${cache_file}.tmp" 2>/dev/null && mv "${cache_file}.tmp" "$cache_file"
  ) &
}

# Get all containers (cached)
_dockero_get_containers() {
  local containers
  if ! _dockero_get_cache "containers"; then
    _dockero_update_cache "containers" ${DOCKERO_RUNTIME:-docker} ps -a --format "{{.Names}}"
  fi
}

# Get running containers only (cached)
_dockero_get_running() {
  local running
  if ! _dockero_get_cache "running"; then
    _dockero_update_cache "running" ${DOCKERO_RUNTIME:-docker} ps --filter "status=running" --format "{{.Names}}"
  fi
}

# Get tar files (cached with longer TTL since files change less)
_dockero_get_tars() {
  local tars
  if ! _dockero_get_cache "tars" 5; then
    # Use printf instead of find for better performance
    _dockero_update_cache "tars" bash -c 'printf "%s\n" *.tar 2>/dev/null | grep -v "^\*\.tar$"'
  fi
}

# Get all networks (cached)
_dockero_get_networks() {
  local networks
  if ! _dockero_get_cache "networks"; then
    _dockero_update_cache "networks" ${DOCKERO_RUNTIME:-docker} network ls --format "{{.Name}}"
  fi
}

_dockero_autocomplete() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Static options - no need to compute
  local base_opts="create volume list stop start exec export import rename setup remove net sync compose env validate system learn explain show heal registry secrets monitor wizard --help --version"

  case $COMP_CWORD in
  1)
    # First argument - complete base commands
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "${base_opts}" -- "${cur}"))
    ;;
  2)
    # Second argument - context-specific completions
    case "$prev" in
    create|rename|start|export|remove)
      # Use cached container list
      local containers
      containers=$(_dockero_get_containers)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "${containers}" -- "${cur}"))
      ;;
    exec)
      # For exec, don't complete at position 2 - user needs to type command first
      ;;
    stop)
      # Use cached running containers
      local running
      running=$(_dockero_get_running)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "${running}" -- "${cur}"))
      ;;
    import)
      # Use cached tar file list
      local tars
      tars=$(_dockero_get_tars)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "${tars}" -- "${cur}"))
      ;;
    list)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "img" -- "${cur}"))
      ;;
    net)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "new create delete add connect remove disconnect rename prune list inspect" -- "${cur}"))
      ;;
    sync)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "push pull watch status init" -- "${cur}"))
      ;;
    compose)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "up down start stop restart ps logs" -- "${cur}"))
      ;;
    env)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "list use show create delete switch" -- "${cur}"))
      ;;
    system)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "service config info cleanup install" -- "${cur}"))
      ;;
    learn)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "start basic intermediate advanced docker concepts examples" -- "${cur}"))
      ;;
    explain)
      # Complete with common dockero commands (all top-level commands are explainable)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "$(echo "$base_opts" | sed 's/--help//g' | sed 's/--version//g')" -- "${cur}"))
      ;;
    show)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "dashboard commands demo visual containers status" -- "${cur}"))
      ;;
    heal)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "check fix auto diagnose cleanup monitor" -- "${cur}"))
      ;;
    registry)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "login push pull list ls search logout" -- "${cur}"))
      ;;
    secrets)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "create ls list rm remove show inspect" -- "${cur}"))
      ;;
    monitor)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "top stats health logs watch" -- "${cur}"))
      ;;
    wizard)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "start setup init quickstart beginner" -- "${cur}"))
      ;;
    volume)
      # shellcheck disable=SC2207
      COMPREPLY=($(compgen -W "list ls create remove rm inspect attach prune" -- "${cur}"))
      ;;
    esac
    ;;
  *)
    # Additional arguments for subcommands
    case "${COMP_WORDS[1]}" in
    exec)
      # For exec command, suggest running containers at any position >= 3
      # Format: dockero exec <command> [args...] <container>
      if [[ "$COMP_CWORD" -ge 3 ]]; then
        local running
        running=$(_dockero_get_running)
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "${running}" -- "${cur}"))
      fi
      ;;
    net)
      local subcmd="${COMP_WORDS[2]}"
      local containers
      local networks

      if [[ "$COMP_CWORD" -eq 3 ]]; then
        case "$subcmd" in
        add | remove | connect | disconnect)
          containers=$(_dockero_get_containers)
          # shellcheck disable=SC2207
          COMPREPLY=($(compgen -W "${containers}" -- "${cur}"))
          ;;
        delete | inspect | rename)
          networks=$(_dockero_get_networks)
          # shellcheck disable=SC2207
          COMPREPLY=($(compgen -W "${networks}" -- "${cur}"))
          ;;
        esac
      elif [[ "$COMP_CWORD" -eq 4 ]]; then
        case "$subcmd" in
        add | remove | connect | disconnect | rename)
          networks=$(_dockero_get_networks)
          # shellcheck disable=SC2207
          COMPREPLY=($(compgen -W "${networks}" -- "${cur}"))
          ;;
        esac
      fi
      ;;
    esac
    ;;
  esac
}

# Cleanup old cache files on shell exit (optional)
_dockero_cleanup() {
  find "$DOCKERO_CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null
}
trap _dockero_cleanup EXIT

complete -F _dockero_autocomplete dockero