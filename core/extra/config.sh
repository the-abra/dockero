#!/bin/bash
# Default configuration for Dockero
# This file can be overridden by user's ~/.dockero/config file

# Default Docker runtime (docker, podman)
: "${DOCKERO_RUNTIME:=docker}"

# Default restart policy for containers
: "${DOCKERO_RESTART_POLICY:=unless-stopped}"

# Default port mapping behavior
: "${DOCKERO_DEFAULT_PORT:=80}"

# Cache TTL in seconds for autocompletion
: "${DOCKERO_CACHE_TTL:=2}"

# Enable/Disable color output
: "${DOCKERO_COLOR_OUTPUT:=true}"

# Default timeout for docker operations
: "${DOCKERO_TIMEOUT:=300}"

# Enable/Disable automatic GPU detection
: "${DOCKERO_AUTO_GPU_ENABLED:=true}"