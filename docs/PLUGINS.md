# Custom Plugins and Extensibility Guide

Dockero features an extensibility system that allows developers to add custom subcommands as plugins without modifying the core codebase.

---

## 1. How Plugins Work

Dockero checks the user's plugin directory at `~/.dockero/commands/` when loading subcommands. 

If a script named `~/.dockero/commands/backup.sh` exists:
1. Sourcing `dockero backup` will load `backup.sh`.
2. Sourcing `dockero explain backup` will display the plugin's help manual.

---

## 2. Creating a Custom Plugin

### Rules for Writing Plugins:
*   **Filename**: Must be named `<command_name>.sh` (e.g., `backup.sh` for the command `dockero backup`).
*   **Required Functions**:
    1.  `<command_name>_help()`: Prints the help instructions/arguments. Called dynamically by `dockero explain`.
    2.  `<command_name>()`: Contains the main execution logic. Called dynamically when the command is run.
*   **Arguments Access**:Sourced parameters are stored in the global `args` array (1-indexed, where `${args[0]}` is the subcommand name).
*   **Logging**: You can use the standard logging utilities (`log.info`, `log.done`, `log.error`, `log.hint`) which are automatically loaded in scope.

### Plugin Template:

Save this template as `~/.dockero/commands/hello.sh`:

```bash
#!/usr/bin/env bash

# Help documentation function
hello_help() {
cat << EOF
dockero hello [name]
   • Purpose: Print a friendly greeting.
   • Parameters:
     - [name]: Person or target to greet (defaults to World).
EOF
}

# Main execution function
hello() {
  local name="${args[1]:-World}"
  
  log.info "Starting greeting sequence..."
  log.done "Hello, $name!"
}
```

Now you can run:
```bash
dockero hello Alice   # Output: Hello, Alice!
dockero explain hello # Output: Displays the help instructions
```

---

## 3. Managing Plugins via CLI

You can install, list, and remove plugins directly using the built-in `dockero plugin` command.

### Listing Installed Plugins
Shows all active custom scripts and their descriptions:
```bash
dockero plugin list
```

### Installing a Plugin
Downloads a raw shell script from a URL and saves it as a local subcommand:
```bash
dockero plugin install backup https://raw.githubusercontent.com/user/repo/main/backup.sh
```

### Removing a Plugin
Uninstalls the specified plugin script from your local system:
```bash
dockero plugin remove backup
```
