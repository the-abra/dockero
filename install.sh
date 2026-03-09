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
    exit 1 # Always exit on error
}

# Helper function to run a command with error handling
run_command() {
    local cmd_description="$1" # A human-readable description of the command
    shift # Remove the first argument, now $@ is the actual command and its args

    log_info "Attempting to $cmd_description..."
    if ! "$@" &>/dev/null; then # Run the command silently
        log_error "Failed to $cmd_description. Please check your system configuration."
    fi
    log_info "Successfully $cmd_description."
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root, continuing..."
    else
        log_error "This script must be run as root. Use sudo."
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
    fi
    
    log_info "Detected package manager: $PKG_MANAGER"
}

# Install packages based on detected package manager
install_packages() {
    local packages_description="$1"
    shift
    local packages_list=("$@")

    case $PM in
        pacman)
            run_command "syncing pacman repositories and installing $packages_description" pacman -Sy --noconfirm "${packages_list[@]}"
            ;;
        apt)
            run_command "updating apt repositories" apt-get update
            run_command "installing $packages_description" apt-get install -y "${packages_list[@]}"
            ;;
        yum)
            run_command "installing $packages_description" yum install -y "${packages_list[@]}"
            ;;
        dnf)
            run_command "installing $packages_description" dnf install -y "${packages_list[@]}"
            ;;
        zypper)
            run_command "installing $packages_description" zypper install -y "${packages_list[@]}"
            ;;
        apk)
            run_command "installing $packages_description" apk add "${packages_list[@]}"
            ;;
    esac
}

# Install Docker
install_docker() {
    log_info "Initiating Docker installation process..."
    
    case $PM in
        pacman)
            install_packages "docker and docker-compose" docker docker-compose
            run_command "enabling Docker service" systemctl enable docker
            run_command "starting Docker service" systemctl start docker
            ;;
        apt)
            install_packages "prerequisites for Docker" ca-certificates curl gnupg lsb-release
            # Add Docker GPG key
            run_command "adding Docker GPG key" install -m 0755 -d /etc/apt/keyrings
            run_command "downloading Docker GPG key" curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            run_command "configuring Docker apt repository" echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            run_command "updating apt repositories after Docker setup" apt-get update
            install_packages "Docker Engine and Docker Compose" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            run_command "enabling Docker service" systemctl enable docker
            run_command "starting Docker service" systemctl start docker
            ;;
        yum|dnf)
            run_command "adding Docker repository" dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            install_packages "Docker Engine and Docker Compose" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            run_command "enabling Docker service" systemctl enable docker
            run_command "starting Docker service" systemctl start docker
            ;;
        zypper)
            run_command "adding Docker repository" zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo
            install_packages "Docker Engine and Docker Compose" docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            run_command "enabling Docker service" systemctl enable docker
            run_command "starting Docker service" systemctl start docker
            ;;
        apk)
            run_command "adding community repository for Docker" echo "@community http://nl.alpinelinux.org/alpine/v$(cut -d'.' -f1-2 /etc/alpine-release)/community" >> /etc/apk/repositories
            run_command "updating apk repositories" apk update
            install_packages "Docker and Docker Compose" docker docker-compose
            run_command "adding Docker service to runlevel" rc-update add docker boot
            run_command "starting Docker service" service docker start
            ;;
    esac
    
    log_info "Docker installation complete. Please ensure your user is in the 'docker' group to run Docker commands without sudo."
}

# Install jq
install_jq() {
    log_info "Initiating jq installation..."
    install_packages "jq" jq
    log_info "jq installation complete."
}

# Install Python dependencies
install_python_deps() {
    log_info "Initiating Python dependencies installation..."

    case $PM in
        pacman)
            install_packages "Python dependencies" python python-textual python-docker
            ;;
        apt)
            install_packages "Python dependencies" python3 python3-textual python3-docker
            ;;
        yum|dnf)
            install_packages "Python dependencies" python3 python3-textual python3-docker
            ;;
        zypper)
            install_packages "Python dependencies" python3 python3-textual python3-docker
            ;;
        apk)
            install_packages "Python dependencies" python3 py3-textual py3-docker
            ;;
    esac

    log_info "Python dependencies installation complete."
}

# Create symlink for dockero
create_symlink() {
    log_info "Initiating Dockero symlink creation..."
    
    # Make sure the script is executable
    run_command "making dockero script executable" chmod +x "./core/dockero"
    
    # Create symlink - using /usr/local/bin instead of /bin for user-installed software
    run_command "creating symlink for dockero" ln -sf "$(pwd)/core/dockero" /usr/local/bin/dockero
    
    log_info "Symlink created: /usr/local/bin/dockero -> $(pwd)/core/dockero"
}

# Install bash completion
install_completion() {
    log_info "Initiating Dockero bash completion installation..."
    local completion_file="./core/autocompletion/dockero.bash-completion.sh"
    local dest_dir="/etc/bash_completion.d"
    
    if [[ -f "$completion_file" ]]; then
        if [[ -d "$dest_dir" ]]; then
            run_command "installing bash completion" cp "$completion_file" "$dest_dir/dockero"
            log_info "Bash completion installed to $dest_dir/dockero"
        else
            log_warn "Bash completion directory $dest_dir not found. Skipping completion installation."
        fi
    else
        log_warn "Completion file $completion_file not found. Skipping completion installation."
    fi
}

main() {
    log_info "Starting Dockero installation..."
    
    check_root
    detect_package_manager
    install_docker
    install_jq
    install_python_deps
    create_symlink
    install_completion
    
    log_info "Dockero installation completed successfully!"
    log_info "You can now run 'dockero' from anywhere."
}

# Run main function
main "$@"