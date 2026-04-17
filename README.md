# Dockero

Dockero is a lightweight Bash-based CLI enhancement layer for Docker. It simplifies container workflows with intuitive commands, structured logging, and autocompletion.

## Installation

```bash
sudo git clone https://github.com/the-abra/dockero.git /usr/local/share/dockero && sudo ln -sf /usr/local/share/dockero/core/dockero /usr/local/bin/dockero
```

## Quick Start

```bash
dockero create webserver nginx   # Create and start a container
dockero list                     # List running containers
dockero stop webserver           # Stop a container
dockero explain create           # Show help for any command
```

## Commands

| Category | Commands |
|---|---|
| Containers | `create`, `start`, `stop`, `remove`, `rename`, `list` |
| Images | `export`, `import`, `registry` |
| Volumes | `volume` |
| Networking | `net` |
| Projects | `setup`, `compose`, `env`, `validate` |
| Sync | `sync` |
| Monitoring | `monitor`, `dashboard`, `heal` |
| Secrets | `secrets` |
| System | `system` |
| Learning | `learn`, `explain`, `show`, `wizard` |

Run `dockero explain <command>` for detailed help on any command.

## Configuration

Dockero can be configured by creating `~/.dockero/config`:

```bash
mkdir -p ~/.dockero
cat > ~/.dockero/config << 'EOF'
# Docker-compatible runtime (docker or podman)
DOCKERO_RUNTIME=docker

# Default restart policy
DOCKERO_RESTART_POLICY=unless-stopped

# Default port
DOCKERO_DEFAULT_PORT=80

# Show timestamps in log output
DOCKERO_LOG_TIMESTAMPS=true

# Auto-detect and use NVIDIA GPU
DOCKERO_AUTO_GPU_ENABLED=true
EOF
```

All settings are optional — defaults are used if not set.

## Plugins

You can add custom commands by placing shell scripts in `~/.dockero/commands/`. Dockero will load them automatically, and they work exactly like built-in commands.

**Example — create `~/.dockero/commands/backup.sh`:**

```bash
mkdir -p ~/.dockero/commands
cat > ~/.dockero/commands/backup.sh << 'EOF'
#!/usr/bin/env bash

backup_help() {
cat << HELP
🔹 dockero backup <container>
   • Purpose: Backup a container as a .tar file in ~/backups/
HELP
}

backup() {
    local container="${args[1]:-}"
    [[ -z "$container" ]] && log.error "Container name required." && return 1

    mkdir -p ~/backups
    ${DOCKERO_RUNTIME:-docker} commit "$container" "backup-$container"
    ${DOCKERO_RUNTIME:-docker} save -o ~/backups/"$container-$(date +%F).tar" "backup-$container"
    log.done "Saved to ~/backups/$container-$(date +%F).tar"
}
EOF
```

Then use it like any built-in command:

```bash
dockero backup mycontainer
dockero explain backup
```

**Plugin conventions:**
- File name = command name (e.g. `backup.sh` → `dockero backup`)
- Define a `<name>_help()` function for `dockero explain <name>` support
- Use `${DOCKERO_RUNTIME:-docker}` instead of `docker` directly
- Access arguments via `${args[1]}`, `${args[2]}`, etc.
- Access flags via `${params[flag]}`

## Autocompletion

```bash
echo 'source /usr/local/share/dockero/core/autocompletion/dockero.bash-completion.sh' >> ~/.bashrc
source ~/.bashrc
```

## Podman Support

Set `DOCKERO_RUNTIME=podman` in `~/.dockero/config` to use Podman instead of Docker.

## License

MIT License
