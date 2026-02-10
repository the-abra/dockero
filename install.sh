#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root, continuing..."
    else
        log_error "This script must be run as root. Use sudo."
        exit 1
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        PM=pacman
        PKG_MANAGER="pacman"
    elif command -v apt-get &> /dev/null; then
        PM=apt
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PM=yum
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PM=dnf
        PKG_MANAGER="dnf"
    elif command -v zypper &> /dev/null; then
        PM=zypper
        PKG_MANAGER="zypper"
    elif command -v apk &> /dev/null; then
        PM=apk
        PKG_MANAGER="apk"
    else
        log_error "Unsupported package manager. Supported: pacman, apt, yum, dnf, zypper, apk"
        exit 1
    fi
    
    log_info "Detected package manager: $PKG_MANAGER"
}

# Install packages based on detected package manager
install_packages() {
    local packages=("$@")
    
    case $PM in
        pacman)
            pacman -Sy --noconfirm "${packages[@]}"
            ;;
        apt)
            apt-get update
            apt-get install -y "${packages[@]}"
            ;;
        yum)
            yum install -y "${packages[@]}"
            ;;
        dnf)
            dnf install -y "${packages[@]}"
            ;;
        zypper)
            zypper install -y "${packages[@]}"
            ;;
        apk)
            apk add "${packages[@]}"
            ;;
    esac
}

# Install Docker
install_docker() {
    log_info "Installing Docker..."
    
    case $PM in
        pacman)
            install_packages docker docker-compose
            systemctl enable docker
            ;;
        apt)
            install_packages ca-certificates curl gnupg lsb-release docker.io docker-compose
            systemctl enable docker
            ;;
        yum|dnf)
            install_packages docker docker-compose-plugin
            systemctl enable docker
            ;;
        zypper)
            install_packages docker docker-compose
            systemctl enable docker
            ;;
        apk)
            install_packages docker docker-compose
            rc-update add docker
            ;;
    esac
    
    log_info "Docker installed and enabled"
}

# Install jq
install_jq() {
    log_info "Installing jq..."
    install_packages jq
    log_info "jq installed"
}

# Install Python dependencies
install_python_deps() {
    log_info "Installing Python dependencies..."

    case $PM in
        pacman)
            install_packages python python-textual python-docker
            ;;
        apt)
            install_packages python3 python3-textual python3-docker
            ;;
        yum|dnf)
            install_packages python3 python3-textual python3-docker
            ;;
        zypper)
            install_packages python3 python3-textual python3-docker
            ;;
        apk)
            install_packages python3 py3-textual py3-docker
            ;;
    esac

    log_info "Python dependencies installed"
}

# Create symlink for dockero
create_symlink() {
    log_info "Creating symlink for dockero..."
    
    # Make sure the script is executable
    chmod +x ./core/dockero.sh
    
    # Create symlink - using /usr/local/bin instead of /bin for user-installed software
    ln -sf "$(pwd)/core/dockero.sh" /usr/local/bin/dockero
    
    log_info "Symlink created: /usr/local/bin/dockero -> $(pwd)/core/dockero.sh"
}

main() {
    log_info "Starting Dockero installation..."
    
    check_root
    detect_package_manager
    install_docker
    install_jq
    install_python_deps
    create_symlink
    
    log_info "Installation completed successfully!"
    log_info "You can now run 'dockero' from anywhere."
}

# Run main function
main "$@"