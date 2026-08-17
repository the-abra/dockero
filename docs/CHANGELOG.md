# Changelog

All notable changes to Dockero will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2026-07-10

### Added
*   **Plugin Command**: Added `dockero plugin` command supporting `list`, `install`, and `remove` subcommands to fetch and manage user plugins.
*   **System Development Command**: Added `dockero system dev` command to convert a standard system installation into a symlinked development installation.
*   **Custom Plugins Guide**: Added `docs/PLUGINS.md` to document plugin architecture, function names, and parameter specifications.

### Changed
*   **Simplified Image Listing**: Changed `dockero list -img` to `dockero list img` (removing the hyphen) to improve CLI user experience.
*   **Developer Guide Rewrite**: Overhauled `docs/CONTRIBUTING.md` to provide comprehensive details on development symbolic links, command data flows, and integration procedures.
*   **Emoji Stripping**: Removed all decorative emojis from all command outputs, help documentation, manuals, and logs to align with standard shell output conventions.

## [1.1.0] - 2026-07-06

### Added
*   **Standalone Bash Compiler**: Added `build.sh` script to compile/bundle modular code into a single distribution-ready script `dist/dockero`.
*   **Zsh Completion Support**: Created a native Zsh autocompletion script at `completions/zsh/_dockero` for completing containers, subcommands, and networks.
*   **UNIX Man Page**: Added a comprehensive man page at `docs/man/dockero.1` covering usage, configs, and plugins.
*   **Debug Mode (`DOCKERO_DEBUG`)**: Added verbose trace logging and parameter indexing output at execution startup.
*   **GitHub Templates**: Added issue templates (bug reports, feature requests) and PR templates under `.github/`.

### Changed
*   **Filesystem Restructuring (FSH)**: Reorganized codebase to match File System Hierarchy standards:
    *   Main executable moved to `bin/dockero`.
    *   Subcommands and utilities moved to `lib/`.
    *   Shell completions moved to `completions/`.
*   **Unified Installer**: Updated `install.sh` to build the standalone executable, configure Bash/Zsh completions, install the man page, and trigger `mandb`.
*   **License Standardization**: Aligned repository badge and documentation to refer to the GNU GPLv3 license instead of MIT.

## [1.0.1] - 2026-04-19

### Fixed
- **Start command** - `-c <command>` flag now correctly executes the command after starting the container
  - Previously, the command passed via `-c` was stored in `params[c]` but never read, causing the exec step to be silently skipped
  - `dockero start <container> -c sh` now properly runs `docker exec -it <container> sh`

## [1.0.0] - 2026-04-19

### Added
- **New `exec` command** - Execute commands in running containers with full argument support
  - Usage: `dockero exec <command> [args...] <container>`
  - Supports interactive TTY mode (auto-detected)
  - Supports commands with flags and arguments (e.g., `dockero exec ls -la /tmp container`)
  - Comprehensive error handling with helpful hints
  - Examples included in help documentation

### Changed
- **Improved logging system**
  - Changed `[ERROR]` to `[FAIL]` for consistency
  - Removed extra spaces from all log level labels (`[INFO]`, `[WARN]`, `[DONE]`, `[HINT]`)
  - All log levels now use exactly 4 characters for better alignment

### Fixed
- **Version flag handling** - `--version` and `-v` flags now only show version when used as main command
  - Fixes issue where `dockero exec sh -v container` would show version instead of executing command
  - Commands like `dockero exec python --version container` now work correctly
- **Stop command** - Fixed "unbound variable" error in `dockero stop` command
  - Removed problematic trap that referenced uninitialized variable
  - Temporary log files now cleaned up properly

### Improved
- **Autocompletion enhancements**
  - Added `exec` command to autocompletion
  - Smart container name suggestions for `exec` command (suggests running containers at appropriate positions)
  - More context-aware completions for multi-argument commands
- **Help documentation**
  - Added `exec` command to main help menu under Container Management section
  - Updated command examples and usage patterns

## [0.1.1] - Previous Release

Initial release with core Docker management features.

[1.2.0]: https://github.com/the-abra/dockero/releases/tag/v1.2.0
[1.1.0]: https://github.com/the-abra/dockero/releases/tag/v1.1.0
[1.0.1]: https://github.com/the-abra/dockero/releases/tag/v1.0.1
[1.0.0]: https://github.com/the-abra/dockero/releases/tag/v1.0.0
[0.1.1]: https://github.com/the-abra/dockero/releases/tag/v0.1.1
