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
  
  if [[ -f "$cache_file" ]]; then
    local age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null) ))
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
    "$@" > "$cache_file.tmp" 2>/dev/null && mv "$cache_file.tmp" "$cache_file"
  ) &
}

# Get all containers (cached)
_dockero_get_containers() {
  if ! _dockero_get_cache "containers"; then
    _dockero_update_cache "containers" docker ps -a --format "{{.Names}}"
  fi
}

# Get running containers only (cached)
_dockero_get_running() {
  if ! _dockero_get_cache "running"; then
    _dockero_update_cache "running" docker ps --filter "status=running" --format "{{.Names}}"
  fi
}

# Get tar files (cached with longer TTL since files change less)
_dockero_get_tars() {
  if ! _dockero_get_cache "tars" 5; then
    # Use printf instead of find for better performance
    _dockero_update_cache "tars" bash -c 'printf "%s\n" *.tar 2>/dev/null | grep -v "^\*\.tar$"'
  fi
}

_dockero_autocomplete() {
  local cur prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # Static options - no need to compute
  local base_opts="run list stop start export import rename setup remove net sync compose env validate system learn explain show heal registry secrets monitor wizard --help --version"

  case $COMP_CWORD in
  1)
    # First argument - complete base commands
    COMPREPLY=($(compgen -W "${base_opts}" -- "${cur}"))
    ;;
  2)
    # Second argument - context-specific completions
    case "$prev" in
    run|rename|start|export|remove)
      # Use cached container list
      local containers
      containers=$(_dockero_get_containers)
      COMPREPLY=($(compgen -W "${containers}" -- "${cur}"))
      ;;
    stop)
      # Use cached running containers
      local running
      running=$(_dockero_get_running)
      COMPREPLY=($(compgen -W "${running}" -- "${cur}"))
      ;;
    import)
      # Use cached tar file list
      local tars
      tars=$(_dockero_get_tars)
      COMPREPLY=($(compgen -W "${tars}" -- "${cur}"))
      ;;
    list)
      COMPREPLY=($(compgen -W "img" -- "${cur}"))
      ;;
    net)
      COMPREPLY=($(compgen -W "new delete add remove rename list" -- "${cur}"))
      ;;
    sync)
      COMPREPLY=($(compgen -W "push pull watch status init" -- "${cur}"))
      ;;
    compose)
      COMPREPLY=($(compgen -W "up down start stop restart ps logs" -- "${cur}"))
      ;;
    env)
      COMPREPLY=($(compgen -W "list use show create delete switch" -- "${cur}"))
      ;;
    system)
      COMPREPLY=($(compgen -W "service config info cleanup install" -- "${cur}"))
      ;;
    learn)
      COMPREPLY=($(compgen -W "start basic intermediate advanced docker concepts examples" -- "${cur}"))
      ;;
    explain)
      # Complete with common dockero commands
      COMPREPLY=($(compgen -W "run setup compose start stop list env sync" -- "${cur}"))
      ;;
    show)
      COMPREPLY=($(compgen -W "dashboard commands demo visual containers status" -- "${cur}"))
      ;;
    heal)
      COMPREPLY=($(compgen -W "check fix auto diagnose cleanup monitor" -- "${cur}"))
      ;;
    registry)
      COMPREPLY=($(compgen -W "login push pull list ls search logout" -- "${cur}"))
      ;;
    secrets)
      COMPREPLY=($(compgen -W "create ls list rm remove show inspect" -- "${cur}"))
      ;;
    monitor)
      COMPREPLY=($(compgen -W "top stats health logs watch" -- "${cur}"))
      ;;
    wizard)
      COMPREPLY=($(compgen -W "start setup init quickstart beginner" -- "${cur}"))
      ;;
    esac
    ;;
  *)
    # Additional arguments for net subcommand
    if [[ "${COMP_WORDS[1]}" == "net" ]]; then
      case "${COMP_WORDS[2]}" in
      add|remove|rename)
        local containers
        containers=$(_dockero_get_containers)
        COMPREPLY=($(compgen -W "${containers}" -- "${cur}"))
        ;;
      delete)
        # Could add network list here if needed
        ;;
      esac
    fi
    ;;
  esac
}

# Cleanup old cache files on shell exit (optional)
_dockero_cleanup() {
  find "$DOCKERO_CACHE_DIR" -type f -mtime +1 -delete 2>/dev/null
}
trap _dockero_cleanup EXIT

complete -F _dockero_autocomplete dockero
