#!/usr/bin/env bash

_dockero_autocomplete() {
  local cur prev opts containers tar_files
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  opts="run list stop start export import rename setup remove net --help --version"

  case $COMP_CWORD in
  1)
    COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
    ;;
  *)
    case "$prev" in
    run | rename | start | export | remove)
      containers=$(docker ps -as --format "{{.Names}}" 2>/dev/null)
      COMPREPLY=($(compgen -W "${containers}" -- "${cur}"))
      ;;
    stop)
      containers=$(docker ps --filter "status=running" --format "{{.Names}}" 2>/dev/null)
      COMPREPLY=($(compgen -W "${containers}" -- "${cur}"))
      ;;
    import)
      tar_files=$(find . -maxdepth 1 -type f -name "*.tar" -printf "%f\n" 2>/dev/null)
      COMPREPLY=($(compgen -W "${tar_files}" -- "${cur}"))
      ;;
    list)
      COMPREPLY=($(compgen -W "img" -- "${cur}"))
      ;;
    net)
      COMPREPLY=($(compgen -W "new delete add remove rename list"))
      ;;
    esac
    ;;
  esac
}

complete -F _dockero_autocomplete dockero
