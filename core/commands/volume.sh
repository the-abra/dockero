#!/usr/bin/env bash

volume() {
  local subcmd="${args[1]:-}"

  case "$subcmd" in
    list|ls)
      log.setline "📦 Volumes"
      docker volume ls
      log.endline ""
      ;;
    create)
      local vol_name="${args[2]:-}"
      if [[ -z "$vol_name" ]]; then
        log.error "Volume name is required."
        log.hint "Usage: dockero volume create <name>"
        return 1
      fi
      log.setline "📦 Create Volume: $vol_name"
      docker volume create "$vol_name"
      log.done "Volume '${BOLD}$vol_name${RESET_COLOR}' created."
      log.endline ""
      ;;
    remove|rm)
      local vol_name="${args[2]:-}"
      if [[ -z "$vol_name" ]]; then
        log.error "Volume name is required."
        log.hint "Usage: dockero volume remove <name>"
        return 1
      fi
      log.setline "📦 Remove Volume: $vol_name"
      docker volume rm "$vol_name"
      log.done "Volume '${BOLD}$vol_name${RESET_COLOR}' removed."
      log.endline ""
      ;;
    inspect)
      local vol_name="${args[2]:-}"
      if [[ -z "$vol_name" ]]; then
        log.error "Volume name is required."
        log.hint "Usage: dockero volume inspect <name>"
        return 1
      fi
      docker volume inspect "$vol_name"
      ;;
    attach)
      # Attach a volume to a running container
      local container_name="${args[2]:-}"
      local vol_spec="${args[3]:-}"  # host_path:container_path or volume_name:container_path
      if [[ -z "$container_name" || -z "$vol_spec" ]]; then
        log.error "Container name and volume spec are required."
        log.hint "Usage: dockero volume attach <container> <host_path:container_path>"
        log.hint "Note: Volume attachment requires container recreation."
        return 1
      fi
      log.warn "Docker does not support live volume attachment. To add a volume, recreate the container with:"
      log.hint "  dockero create $container_name --volume $vol_spec"
      ;;
    prune)
      log.setline "📦 Prune Unused Volumes"
      log.warn "This will remove all unused volumes."
      docker volume prune -f
      log.done "Unused volumes pruned."
      log.endline ""
      ;;
    *)
      log.error "Unknown volume subcommand: '${BOLD_RED}${subcmd}${RESET_COLOR}'."
      log.hint "Usage: dockero volume <list|create|remove|inspect|attach|prune>"
      return 1
      ;;
  esac
}
