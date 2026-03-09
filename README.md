# Dockero

Dockero is a lightweight Bash-based CLI enhancement layer for Docker. It simplifies container workflows with intuitive commands, structured logging, and autocompletion.

## Installation

To install Dockero, run the following command:

```bash
sudo git clone https://github.com/the-abra/dockero.git /usr/local/share/dockero && sudo ln -sf /usr/local/share/dockero/core/dockero /usr/local/bin/dockero
```

## Quick Start

```bash
# Run a container
dockero run webserver nginx

# List running containers
dockero list

# Stop a container
dockero stop webserver
```

## Commands

- `dockero run`: Run or create containers.
- `dockero list`: List containers and images.
- `dockero start`: Start existing containers.
- `dockero stop`: Stop running containers.
- `dockero setup`: Initialize project configuration.
- `dockero compose`: Manage multi-container applications.
- `dockero heal`: Self-healing and health check system.
- `dockero help`: Show usage information.

## Autocompletion

To enable autocompletion, add the following line to your `~/.bashrc`:

```bash
source /usr/local/share/dockero/core/autocompletion/dockero.bash-completion.sh
```

## License

MIT License
