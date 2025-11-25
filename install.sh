#!/usr/bin/env bash

# Install script for Dockero
# This script installs Dockero to your system and sets up autocompletion

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}
  ____                        _        _   
 |  _ \                      | |      | |  
 | |_) | ___  _ __ ___   ___ | |_ __ _| |_ 
 |  _ < / _ \| '_ ' _ \ / _ \| __/ _' | __|
 | |_) | (_) | | | | | | (_) | || (_| | |_ 
 |____/ \___/|_| |_| |_|\___/ \__\__,_|\__|
    ${NC}Simplified Docker CLI with Autocompletion"
    echo
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        print_warning "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! command -v bash &> /dev/null; then
        print_error "Bash is not available"
        exit 1
    fi
    
    print_status "Prerequisites check passed"
}

# Install Dockero
install_dockero() {
    print_status "Installing Dockero..."
    
    # Determine installation directory
    local install_dir="${1:-/usr/local/bin}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local core_dir="${script_dir}/core"
    
    # Check if we have write permissions
    if [[ ! -w "$install_dir" ]]; then
        print_warning "No write permission to $install_dir, using sudo"
        sudo mkdir -p "$install_dir"
        sudo cp "$core_dir/dockero.sh" "$install_dir/dockero"
        sudo chmod +x "$install_dir/dockero"
    else
        mkdir -p "$install_dir"
        cp "$core_dir/dockero.sh" "$install_dir/dockero"
        chmod +x "$install_dir/dockero"
    fi
    
    print_status "Dockero installed to $install_dir/dockero"
}

# Setup autocompletion
setup_autocompletion() {
    print_status "Setting up autocompletion..."
    
    local bash_completion_dir=""
    local completion_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/core/autocompletion/dockero.bash-completion.sh"
    
    # Try common bash completion directories
    for dir in "/etc/bash_completion.d" "/usr/local/etc/bash_completion.d" "$HOME/.local/etc/bash_completion.d"; do
        if [[ -d "$dir" ]] && [[ -w "$dir" ]]; then
            bash_completion_dir="$dir"
            break
        fi
    done
    
    # If no writable directory found, use sudo
    if [[ -z "$bash_completion_dir" ]]; then
        # Check if we can write to any of them with sudo
        for dir in "/etc/bash_completion.d" "/usr/local/etc/bash_completion.d"; do
            if [[ -d "$dir" ]]; then
                bash_completion_dir="$dir"
                break
            fi
        done
        
        if [[ -n "$bash_completion_dir" ]]; then
            print_warning "No write permission to bash completion directory, using sudo"
            sudo cp "$completion_script" "$bash_completion_dir/dockero"
            print_status "Autocompletion script installed to $bash_completion_dir/dockero"
        else
            print_warning "Could not find bash completion directory, will add to .bashrc"
        fi
    else
        cp "$completion_script" "$bash_completion_dir/dockero"
        print_status "Autocompletion script installed to $bash_completion_dir/dockero"
    fi
    
    # Check if completion is already in .bashrc
    if ! grep -q "dockero" "$HOME/.bashrc" 2>/dev/null; then
        # Add source command to .bashrc if completion dir wasn't used
        if [[ -z "$bash_completion_dir" ]]; then
            # Try to add to .bashrc
            {
                echo ""
                echo "# Dockero autocompletion"
                echo "source $completion_script"
                echo ""
            } >> "$HOME/.bashrc" 2>/dev/null || {
                print_warning "Could not add to .bashrc automatically"
                echo ""
                echo "To enable autocompletion, add this line to your shell configuration:"
                echo "source $completion_script"
                echo ""
                echo "For bash, add to ~/.bashrc"
                echo "For zsh, add to ~/.zshrc"
                echo ""
            }
        else
            print_status "Autocompletion should work automatically in new shells"
        fi
    else
        print_status "Autocompletion already configured"
    fi
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if command -v dockero &> /dev/null; then
        print_status "Dockero is available in PATH"
        print_status "Version: $(dockero version 2>/dev/null || echo 'Unknown')"
    else
        print_warning "Dockero not found in PATH"
        print_status "You may need to restart your shell or add $(dirname $(which dockero 2>/dev/null || echo '/usr/local/bin/dockero')) to your PATH"
    fi
}

show_next_steps() {
    echo
    echo -e "${BLUE}=== Next Steps ===${NC}"
    echo "1. Restart your shell or run: source ~/.bashrc"
    echo "2. Try: dockero -h (to see all commands)"
    echo "3. Run: dockero wizard (for interactive setup)"
    echo "4. Check: dockero learn basic (for Docker learning)"
    echo
    echo -e "${GREEN}Installation complete! 🎉${NC}"
}

# Main execution
main() {
    print_header
    check_prerequisites
    
    local install_dir="${1:-/usr/local/bin}"
    install_dockero "$install_dir"
    setup_autocompletion
    verify_installation
    show_next_steps
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS] [INSTALL_DIR]"
    echo "Install Dockero with autocompletion"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "INSTALL_DIR:"
    echo "  Installation directory (default: /usr/local/bin)"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                    # Install to default location"
    echo "  $0 ~/bin             # Install to user directory"
    echo "  $0 /opt/dockero/bin  # Install to custom location"
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac