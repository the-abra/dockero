#!/bin/bash
# Install Python dependencies for Dockero enhanced UX features

echo "Installing Python dependencies for Dockero enhanced UX..."

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 is not installed. Please install Python 3 and pip."
    exit 1
fi

# Install required Python packages
echo "Installing required libraries..."
if pip3 install rich npyscreen textual docker; then
    echo "✅ Python dependencies installed successfully!"
    echo ""
    echo "You can now use enhanced UX features:"
    echo "  - dockero tui          # Interactive dashboard"
    echo "  - dockero create-interactive  # Interactive container creation"
    echo ""
    echo "Note: These features require Python 3 and the installed libraries."
else
    echo "❌ Failed to install Python dependencies"
    exit 1
fi