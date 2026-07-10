# Dockero

[![ShellCheck](https://github.com/the-abra/dockero/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/the-abra/dockero/actions/workflows/shellcheck.yml)
[![Tests](https://github.com/the-abra/dockero/actions/workflows/tests.yml/badge.svg)](https://github.com/the-abra/dockero/actions/workflows/tests.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

Dockero is a lightweight Bash-based CLI enhancement layer for Docker and Podman. It simplifies container workflows with intuitive commands, structured logging, completions, and customizable command plugins.

The source code is modularly structured under the `lib/` directory for developer maintainability and is compiled/bundled into a single standalone executable script under `dist/dockero`.

---

## Installation & Setup

To install Dockero, first clone the repository to the recommended system directory `/usr/local/share/dockero` and build it:

```bash
sudo git clone https://github.com/the-abra/dockero.git /usr/local/share/dockero
cd /usr/local/share/dockero
sudo make build
```

Once built, you can install the executable, man page documentation, and shell completions manually.

### 1. Install the Executable

You can copy the compiled file from `/usr/local/share/dockero/dist/dockero` to your system binaries directory:

```bash
sudo cp /usr/local/share/dockero/dist/dockero /usr/local/bin/dockero
sudo chmod +x /usr/local/bin/dockero
```

### 2. Configure Shell Autocompletions

Dockero comes with full autocomplete scripts for both Bash and Zsh.

#### Bash Completions

Place the completion file in your system completion directory:

```bash
sudo cp completions/bash/dockero /etc/bash_completion.d/dockero
```

*Alternatively, you can source it manually in your `~/.bashrc`:*

```bash
source /usr/local/share/dockero/completions/bash/dockero
```

#### Zsh Completions

Copy the Zsh completion file to a directory in your `$fpath` (e.g., `/usr/local/share/zsh/site-functions`):

```bash
sudo cp completions/zsh/_dockero /usr/local/share/zsh/site-functions/_dockero
```

*Alternatively, add the directory to your `$fpath` in `~/.zshrc` before calling `compinit`:*

```zsh
fpath=(/usr/local/share/dockero/completions/zsh $fpath)
autoload -U compinit && compinit
```

### 3. Install UNIX Man Pages

To read documentation directly from your terminal using `man dockero`:

```bash
# Copy the man page to man1 path
sudo mkdir -p /usr/local/share/man/man1
sudo cp docs/man/dockero.1 /usr/local/share/man/man1/dockero.1

# Rebuild the man database cache
sudo mandb
```

Read the manual anytime with:

```bash
man dockero
```

---

## Quick Start

```bash
dockero create webserver nginx   # Create and start a container
dockero list                     # List running containers
dockero stop webserver           # Stop a container
dockero explain create           # Show help for any command
```

---

## Command Reference

| Category   | Commands                                              |
| ---------- | ----------------------------------------------------- |
| Containers | `create`, `start`, `stop`, `remove`, `rename`, `list` |
| Images     | `export`, `import`, `registry`                        |
| Volumes    | `volume`                                              |
| Networking | `net`                                                 |
| Projects   | `setup`, `compose`, `env`, `validate`                 |
| Sync       | `sync`                                                |
| Monitoring | `monitor`, `dashboard`, `heal`                        |
| Secrets    | `secrets`                                             |
| System     | `system`, `plugin`                                    |
| Learning   | `learn`, `explain`, `show`, `wizard`                  |

Run `dockero explain <command>` for detailed help on any subcommand.

---

## Configuration

Configure custom settings by creating a shell configuration file at `~/.dockero/config`:

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

# Verbose debugging logs
DOCKERO_DEBUG=false
EOF
```

---

## Project Documentation

Check out the dedicated documentation files inside the `docs/` folder:

* [docs/CHANGELOG.md](https://github.com/the-abra/dockero/blob/main/docs/CHANGELOG.md) - Project release history and semver logs.
* [docs/CONTRIBUTING.md](https://github.com/the-abra/dockero/blob/main/docs/CONTRIBUTING.md) - Coding style, subcommand architectures, and pull request processes.
* [docs/IMPROVEMENTS.md](https://github.com/the-abra/dockero/blob/main/docs/IMPROVEMENTS.md) - Technical benchmark records, parsing layouts, and runtime specifications.
* [docs/PLUGINS.md](https://github.com/the-abra/dockero/blob/main/docs/PLUGINS.md) - Guide on creating and managing custom subcommand plugins.
* [docs/LICENSE](https://github.com/the-abra/dockero/blob/main/docs/LICENSE) - Official GNU General Public License v3 terms.

---

## Podman Support

Set `DOCKERO_RUNTIME=podman` in `~/.dockero/config` to use Podman instead of Docker.

## License

GNU General Public License v3
