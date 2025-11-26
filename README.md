<p align="center">
  <img width="96" src="https://the-abra.github.io/images/dockero.png" alt="Dockero Icon">
</p>

<h1 align="center">🚀 Dockero – Simplified Docker CLI with Autocompletion</h1>

<p align="center">
  <strong>Dockero</strong> is a lightweight, Bash-based CLI enhancement layer for Docker. It streamlines container workflows with memorable commands, rich logging, autocompletion, and project configuration support — built by developers, for developers.
</p>

<br>

## ✨ Key Features

- 🔧 **Simplified CLI Commands** - Human-readable, easy-to-type aliases for common Docker operations
- 📋 **Structured Logging** - Color-coded success, error, and warning logs for better CLI UX
- ⚙️ **Configuration Support** - Define project-wide Docker behaviors via `.dockero` files
- 🔄 **Smart Autocompletion** - Intelligent Bash autocompletion for commands, images, and containers
- 📊 **Advanced Monitoring** - Real-time container metrics, logs, and health checks
- 🔐 **Secrets Management** - Secure handling of sensitive data
- 📦 **Registry Integration** - Push/pull operations with container registries
- 🎯 **Interactive Wizard** - Beginner-friendly setup assistant
- 🧩 **Modular Architecture** - Easy to extend and contribute

---

## 🚀 Quick Start

### Prerequisites

- Docker installed and running
- Bash (>=4.x)
- Unix-like environment (Linux/macOS)

### Installation Options

#### Option 1: Quick Install (Recommended)
```bash
# Clone the repository
git clone https://github.com/the-abra/dockero.git
cd dockero

# Run the installation script
./install.sh
```

#### Option 2: Manual Install
```bash
# Clone and make executable
git clone https://github.com/the-abra/dockero.git
cd dockero
chmod +x core/dockero.sh

# Install to system
sudo ln -s "$PWD/core/dockero.sh" /usr/local/bin/dockero
```

#### Option 3: Container Install (Docker required)
```bash
# Build Dockero container
docker build -t dockero .
docker run -it --rm --name dockero -v /var/run/docker.sock:/var/run/docker.sock dockero
```

### Setup Autocompletion

```bash
# Temporary (current session)
source $PWD/core/autocompletion/dockero.bash-completion.sh

# Permanent (add to shell config)
echo "source $PWD/core/autocompletion/dockero.bash-completion.sh" >> ~/.bashrc
```

---

## 📖 Common Commands

| Command | Description | Example |
|---------|-------------|---------|
| `dockero run` | Run/create containers | `dockero run myapp nginx` |
| `dockero list` | List containers/images | `dockero list` or `dockero list -img` |
| `dockero start` | Start containers | `dockero start myapp` |
| `dockero stop` | Stop containers | `dockero stop myapp` |
| `dockero setup` | Project setup | `dockero setup ./my-project` |
| `dockero compose` | Multi-container apps | `dockero compose up` |
| `dockero help` | Show help | `dockero help` or `dockero <command> -h` |

### Getting Started Examples

```bash
# Run a container
dockero run webserver nginx

# List running containers
dockero list

# Stop a container
dockero stop webserver

# Get help on a command
dockero run -h
```

---

## ⚙️ Configuration

Dockero supports both system-wide and user-specific configuration:

### User Configuration
Create `~/.dockero/config`:
```bash
# Example user config
DOCKERO_DEFAULT_PORT=3000
DOCKERO_RESTART_POLICY=always
DOCKERO_TIMEOUT=600
```

### Available Configuration Options
- `DOCKERO_RUNTIME` - Docker runtime (docker, podman) [default: docker]
- `DOCKERO_RESTART_POLICY` - Default restart policy [default: unless-stopped]
- `DOCKERO_DEFAULT_PORT` - Default port mapping [default: 80]
- `DOCKERO_CACHE_TTL` - Autocompletion cache time-to-live [default: 2]
- `DOCKERO_COLOR_OUTPUT` - Enable color output [default: true]
- `DOCKERO_TIMEOUT` - Operation timeout in seconds [default: 300]

---

## 🧪 Testing

Run the test suite:
```bash
./test_commands.sh
```

For development, you can test individual commands:
```bash
./core/dockero.sh -h  # Show help
./core/dockero.sh version  # Show version
```

## 🎨 Enhanced User Experience

### Interactive Dashboard
Dockero now includes an enhanced interactive dashboard powered by Python:

```bash
# Install Python dependencies first
./install-python-deps.sh

# Launch interactive dashboard
dockero tui
```

### Interactive Container Creation
Create containers with an interactive wizard:
```bash
dockero create-interactive
```

### Enhanced Progress Indicators
For operations that support it, Dockero can show detailed progress indicators:
- Image pulls with progress bars
- Container start/stop with status updates
- Build operations with progress tracking

## 🐍 Python Dependencies

For enhanced UX features, install Python dependencies:

```bash
# Install required Python packages
./install-python-deps.sh

# Or manually:
pip3 install rich npyscreen textual docker
```

The enhanced features require:
- **rich**: For beautiful terminal formatting and progress bars
- **npyscreen**: For interactive terminal user interfaces
- **textual**: For the modern TUI dashboard
- **docker**: For Docker client integration

---

## 🤝 Contributing

We welcome contributors! See our [CONTRIBUTING.md](docs/CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes (`./test_commands.sh`)
5. Commit with conventional commits format (`git commit -m "feat: add new command"`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Code Quality
- Run shellcheck to ensure code quality: `shellcheck core/**/*.sh`
- Follow the style guide in CONTRIBUTING.md
- Write clear, descriptive commit messages

---

## 📚 Documentation

- [CONTRIBUTING.md](docs/CONTRIBUTING.md) - Contribution guidelines
- Command help: `dockero help` or `dockero <command> -h`
- Project Wiki (coming soon)

---

## 🐛 Issues & Support

- Check the [Issues](https://github.com/the-abra/dockero/issues) page for existing problems
- Create a new issue with detailed information about the problem
- Join our [Discord Server](https://discord.gg/PXQQdpKNdc) for real-time support

---

## 📄 License

MIT License © 2025

---

## 🙏 Acknowledgments

- Inspired by the need to simplify Docker workflows
- Thanks to all contributors who help make Dockero better
- Built with ❤️ for the developer community
