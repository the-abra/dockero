<img width="96" align="right" src="https://the-abra.github.io/images/dockero.png" alt="ICON">

# 🚀 Dockero – Simplified Docker CLI with Autocompletion

**Dockero** is a lightweight, Bash-based CLI enhancement layer for Docker. It streamlines container workflows with memorable commands, rich logging, autocompletion, and project configuration support — built by developers, for developers.

---

## 🔧 What Dockero Offers

- ✅ **Simplified CLI Commands**  
  Human-readable, easy-to-type aliases for common Docker operations.

- 📋 **Structured Logging**  
  Color-coded success, error, and warning logs for better CLI UX.

- ⚙️ **.dockero Configuration Format**  
  Define project-wide Docker behaviors via a single file.

- 🤝 **Developer-Centric Design**  
  Tailored for backend and DevOps workflows with minimal overhead.

- 🧩 **Easy Integration & Contribution**  
  Plug into any project or contribute directly with minimal setup.

- 🔄 **Shell Autocompletion**  
  Intelligent Bash autocompletion for commands, images, and containers.

- 💬 **Community & Support**  
  Get real-time help on our [Discord Server](https://discord.gg/PXQQdpKNdc)  
  Contribute and unlock the `@dockero` role.

---

## 🚀 Getting Started

> **Requirements:** Docker, Bash (>=4.x), Unix-like environment (Linux/macOS)

### 1. Clone the Repository

```bash
git clone https://github.com/temelyus/dockero.git
cd dockero
```

### 2. Make It Executable

```bash
chmod +x core/dockero.sh
sudo ln -s "$PWD/core/dockero.sh" /usr/local/bin/dockero
```

### 3. Enable Bash Autocompletion

```bash
source $PWD/core/autocompletion/dockero.bash-completion.sh
```

To make it permanent, add that line to your `~/.bashrc`.

---

## 📦 Project Setup with `.dockero`

Dockero supports declarative setup via `.dockero` file placed in your project root:

```ini
[default]
name = mydebian
image = debian:latest
command = echo hello from debian

[volumes]
data = /opt/mydebian:/workspace
port = 8080:80
```

---

## 🤝 Contributing

We welcome contributors. Fork the repo, make your changes, and open a PR.

- 📄 Read our [CONTRIBUTING.md](docs/CONTRIBUTING.md)
- 📢 Join the discussion on [Discord](https://discord.gg/PXQQdpKNdc)

---

## 📜 License

MIT License © 2025
