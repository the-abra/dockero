# Dockero Development Roadmap

This document outlines the project roadmap, listing recently implemented architectural improvements and setting the direction for upcoming features.

---

## 🗺️ Future Feature Roadmap

### 1. 🔌 Expanded Subcommand Plugin Manager (`dockero plugin`)
The initial plugin manager is implemented inside [lib/commands/plugin.sh](https://github.com/the-abra/dockero/blob/main/lib/commands/plugin.sh), supporting local list, installation, and removal:
*   **Next Phase**:
    *   Add a local update mechanism (`dockero plugin update <name>`) to fetch the latest changes from the original source URL.
    *   Support GitHub repository paths directly: `dockero plugin install mycmd owner/repo/path/to/script.sh`.
    *   Add sandboxed plugin validation before installation (e.g., verifying syntax and confirming standard headers).

### 2. 🎛️ Profile Environments (dev vs. prod)
Implement support for staging and production profiles:
*   Allow developers to create profile configurations: `.dockero.dev` and `.dockero.prod`.
*   Support passing the profile flags: `dockero setup run --env dev` or `dockero setup run --env prod` to load specific volume mount locations, port mappings, and restart policies automatically.

### 3. 🌐 Real-Time Caching Completion Engine
Improve shell autocompletions for Zsh and Bash:
*   Enable completions to query active containers in real-time when typing `dockero stop [TAB]`.
*   Implement a `/tmp/dockero_completion_cache` file with a 2-second TTL to keep dynamic container queries ultra-fast and lag-free.

### 4. 🧠 Smart Diagnostics & Self-Healing (`heal` expansions)
Expand the self-healing routines to diagnose host systems:
*   **Port Collisions**: Automatically inspect conflicting host ports using `ss` or `netstat` and report the conflicting application process ID.
*   **Daemon Recovery**: Check docker socket permissions, daemon responsiveness, and provide systemd service restart suggestions.

### 5. 🗃️ Multi-Container Stack Presets
Enhance `dockero setup init --preset` to generate full development stack architectures:
*   Provide preset bundles (e.g., Node + React + MongoDB) that create ready-to-run docker-compose or multi-container system profiles.

---

## 🏗️ Completed Milestones

### 1. Simplified Directory Structure
*   Collapsed the redundant namespace subdirectory, moving all files from `lib/dockero/` directly into `lib/` at the root of the project.

### 2. Compilation-Focused Architecture
*   Decoupled files from complex, regex-based file-stripping compile logic by removing all dynamic utility `source` statements from [bin/dockero](https://github.com/the-abra/dockero/blob/main/bin/dockero). 
*   All utility libraries and subcommand functions are inlined directly at compile time using a clean, concatenation-based builder [bin/build.sh](https://github.com/the-abra/dockero/blob/main/bin/build.sh).

### 3. Centralized Makefile Build System
*   Added a unified [Makefile](https://github.com/the-abra/dockero/blob/main/Makefile) to build, clean, lint, and test the project using standardized commands (`make build`, `make test`, `make lint`, `make dist`).
*   Configured GitHub CI/CD workflows to run tests and lints directly via `make`.

### 4. Preset Auto-Setups
*   Created preset configuration profiles (`nginx`, `postgres`, `node`, `python`, `redis`) to configure local project container files with single commands: `dockero setup init --preset nginx`.
