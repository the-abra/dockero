remove() {
  local input="${args[1]}"

  if [[ -z "$input" ]]; then
    log.hint "Usage: remove <container|image>[:tag]"
    return 1
  fi

  # Parse target and tag
  local name="${input%%:*}"
  local tag="${input#*:}"
  [[ "$input" == "$tag" ]] && tag="latest"

  local target="$name:$tag"

  # Check for container first
  if docker ps -a --format '{{.Names}}' | grep -q "^$name$" && ! [[ $input =~ ':' ]]; then
    if docker rm -f "$name" > /dev/null 2>&1; then
      log.done "Removed container $name"
    else
      log.warn "Failed to remove container $name"
    fi
    return
  # Check for image next
  elif docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^$target$"; then
    if docker rmi -f "$target" > /dev/null 2>&1; then
      log.done "Removed image $target"
    else
      log.warn "Failed to remove image $target"
    fi
    return
  fi

  log.error "Target not found: $input"
}
