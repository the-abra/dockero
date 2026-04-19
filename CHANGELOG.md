# Changelog

All notable changes to Dockero will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/the-abra/dockero/releases/tag/v1.0.0
[0.1.1]: https://github.com/the-abra/dockero/releases/tag/v0.1.1
