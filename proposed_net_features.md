I propose the following improvements and new features for the `net` subcommands:

1.  **`net prune`**: This new command will remove all unused Docker networks, helping users to easily clean up their environment. It will essentially be a wrapper for `docker network prune`.

2.  **Aliases for existing commands**: To improve user experience and align with standard Docker command terminology, I propose adding aliases for existing commands:
    *   `net create <network_name>`: This will be an alias for `net new <network_name>`.
    *   `net connect <container> <network>`: This will be an alias for `net add <container> <network>`.
    *   `net disconnect <container> <network>`: This will be an alias for `net remove <container> <network>`.

These features will enhance resource management and make the `net` commands more intuitive to use. I will ensure that `help.sh` is updated for all new functionalities.

Would you like me to proceed with implementing these features?