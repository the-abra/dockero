#!/usr/bin/env bash
# Direct Python execution script for Dockero enhanced features
# This avoids terminal issues when calling Python from dockero

set -e

CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHON_SCRIPT="$CORE_DIR/dockero_helper.py"

# Ensure proper terminal settings for Kitty and other terminals
export TERM="${TERM:-xterm-256color}"
export COLUMNS="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
export LINES="${LINES:-$(tput lines 2>/dev/null || echo 24)}"

# Check if Python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: Python3 is not installed or not in PATH"
    echo "Please install Python 3."
    exit 1
fi

# Check if required Python packages are available
# For TUI functionality, we need textual and docker; npyscreen may be used by other parts
if ! python3 -c "import textual, docker" &> /dev/null; then
    echo "❌ Error: Required Python packages 'textual' and 'docker' not found."
    echo "Please install required packages: pip3 install textual docker"
    exit 1
fi

# Execute the Python script with proper terminal environment
exec python3 "$PYTHON_SCRIPT" "$@"