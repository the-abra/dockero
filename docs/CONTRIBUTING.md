# Contributing to Dockero

Thank you for contributing to Dockero! This guide covers development environment setup, the modular project architecture, rules for creating new commands, and how to properly register them.

---

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Architecture](#project-architecture)
3. [Creating a New Command](#creating-a-new-command)
4. [Integrating a New Command](#integrating-a-new-command)
5. [Coding Standards](#coding-standards)
6. [Branching & Workflow](#branching--workflow)
7. [Reporting Issues](#reporting-issues)
8. [Pull Request Process](#pull-request-process)

---

## Development Setup

For active development, compile the binary once and create symbolic links so changes are immediately testable:

### 1. Compile the Standalone Executable
Dockero is compiled/bundled into a single standalone execution script:
```bash
make build
```
This generates the file `dist/dockero`.

### 2. Create Development Symbolic Links
Rather than copying files manually on each change, you can automate this using the built-in system development setup command:

```bash
sudo dockero system dev
```

Alternatively, you can manually create the symbolic links:

```bash
# Link the compiled executable to your system path
sudo ln -sf "$(pwd)/dist/dockero" /usr/local/bin/dockero

# Link Bash autocompletion script
sudo ln -sf "$(pwd)/completions/bash/dockero" /etc/bash_completion.d/dockero

# Link Zsh autocompletion script
sudo ln -sf "$(pwd)/completions/zsh/_dockero" /usr/local/share/zsh/site-functions/_dockero
```
After linking, any recompilation (`make build`) or edit to autocompletion scripts is immediately live in new terminal sessions.

---

## Project Architecture

Dockero is structured modularly to separate execution logic, subcommand implementations, and shell resources:

*   `bin/dockero` - Main script entry point. It parses global parameters and loads libraries.
*   `lib/commands/` - Subcommand implementations. Each file represents one subcommand.
*   `lib/utils/` - Shared helper modules (logging, terminal colors, validation, ini parsing).
*   `completions/` - Autocomplete scripts for Bash and Zsh.
*   `docs/` - User guides, documentation, and the Unix man page.

---

## Creating a New Command

### 1. File Naming
Add a new script file in `lib/commands/` named exactly after the subcommand in lowercase:
`lib/commands/mycommand.sh`

### 2. Functions Inside the File
Each command script must define exactly two functions:
1.  `<command_name>_help()`: Prints the command instructions, options, and parameters.
2.  `<command_name>()`: Contains the execution logic.

Example (`lib/commands/mycommand.sh`):
```bash
#!/usr/bin/env bash

# Command help documentation (No emojis allowed)
mycommand_help() {
cat << EOF
dockero mycommand <arg1> [options]
   • Purpose: Execute a custom development action.
   • Parameters:
     - <arg1>: Sourced parameter.
     - -f, --force: Force execution.
EOF
}

# Command main entry point
mycommand() {
  local target="${args[1]:-}"
  local force_mode="${params[f]+set}" # Reads short options

  if [[ -z "$target" ]]; then
    log.error "Missing required parameter: <arg1>"
    log.hint "Run 'dockero explain mycommand' for usage details."
    return 1
  fi

  log.info "Executing mycommand on: $target"
  # Sourced command logic goes here...
  log.done "mycommand execution complete"
}
```

### 3. Data Flow and Execution
1.  **Invocation**: The user executes `dockero mycommand arg1 --force`.
2.  **Parsing**: The main launcher `bin/dockero` parses input arguments into two global variables:
    *   `args`: An index-based array containing positional arguments (`${args[0]}` is `mycommand`, `${args[1]}` is `arg1`).
    *   `params`: An associative array mapping flags (`${params[f]}` or `${params[force]}`).
3.  **Bootstrap**: `bin/dockero` validates environment dependencies (Docker/Podman, jq), loads settings from `~/.dockero/config`, and sources all helper modules under `lib/utils/`.
4.  **Routing**: The loader searches for custom plugins at `~/.dockero/commands/mycommand.sh` first. If none exist, it matches against internal functions.
5.  **Execution**: Control is handed off to the `mycommand` function.

---

## Integrating a New Command

When adding or changing a subcommand, update the following files to ensure complete shell integration and correct documentation:

### 1. The Global Help Menu (`lib/commands/help.sh`)
Add the command syntax under the appropriate category in the `_show_general_help()` function list so it appears in `dockero help`.

### 2. Bash Completion (`completions/bash/dockero`)
1.  Add the new subcommand string to `base_opts` so it autocompletes at position 1.
2.  Under `case "$prev" in`, add a case block for your subcommand if it requires contextual completions (e.g., container names, file paths, or specific parameters).

### 3. Zsh Completion (`completions/zsh/_dockero`)
1.  Add the command and its summary description to the `commands` array inside `_dockero_commands()`.
2.  Under `case $words[1] in`, add a match case to handle subcommand parameters or sub-options using `_describe` or container listing helpers.

### 4. UNIX Man Page (`docs/man/dockero.1`)
Add the subcommand description under the appropriate category section using `.TP` and `.BI` formatting macros.

### 5. Compiled Executable Rebuilding
Rebuild and run checks to verify syntax correctness:
```bash
make build
make lint
make test
```

---

## Coding Standards

*   Follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html).
*   Indent with **2 spaces**, not tabs.
*   Always quote variables: `"$var"`.
*   Limit line length to 80 characters where possible.
*   Utilize shared functions under `lib/utils/` (e.g. `log.info`, `log.error`) instead of raw `echo`.
*   Do not use graphical or colorful emojis in source files, help texts, or documentation files.

---

## Branching & Workflow

We follow the GitHub Flow:
1.  Create a branch for your work: `git checkout -b feature/my-new-feature`
2.  Commit changes in logical chunks using conventional commit messages.
3.  Push your branch to GitHub: `git push origin feature/my-new-feature`

---

## Reporting Issues

*   Check existing issues to avoid duplicates.
*   Provide reproducible steps, shell version, container runtime config, and error logs.

---

## Pull Request Process

1.  Open a PR against the `dev` branch.
2.  Ensure that all shellcheck validations and unit tests (`make test`) pass successfully.
3.  Describe your changes and link related issues.