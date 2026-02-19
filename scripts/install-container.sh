#!/bin/bash
# install-container.sh - Install container runtime (Podman) on Linux
# Usage: ./scripts/install-container.sh

set -e

echo "=== Container Runtime Installation (Podman) ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS. This script supports Debian/Ubuntu, Fedora, and RHEL-based distributions."
    exit 1
fi

echo "Detected OS: $OS"
echo ""

install_podman_debian() {
    echo "Installing Podman for Debian/Ubuntu..."
    
    # Add Podman repository
    . /etc/os-release
    OS_VERSION_ID=$VERSION_ID
    
    # Install prerequisites
    apt-get update
    apt-get install -y curl wget gnupg2
    
    # Add Podman repository
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${OS_VERSION_ID}/ /" | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${OS_VERSION_ID}/Release.key | apt-key add -
    
    # Install Podman
    apt-get update
    apt-get install -y podman
    
    echo "Podman installed successfully!"
}

install_podman_fedora() {
    echo "Installing Podman for Fedora..."
    
    # Install Podman
    dnf install -y podman
    
    echo "Podman installed successfully!"
}

install_podman_rhel() {
    echo "Installing Podman for RHEL/CentOS..."
    
    # Install Podman
    yum install -y podman
    
    echo "Podman installed successfully!"
}

# Install Podman based on OS
case $OS in
    ubuntu|debian)
        install_podman_debian
        ;;
    fedora)
        install_podman_fedora
        ;;
    centos|rhel|rocky|alma)
        install_podman_rhel
        ;;
    *)
        echo "Unsupported OS: $OS"
        echo "Please install Podman manually: https://podman.io/getting-started/installation"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo "Verifying Podman installation..."
podman --version
podman compose version

echo ""
echo "=== Container Runtime Installation Complete ==="
echo ""
echo "To start using Podman (works like Docker):"
echo "  podman machine init"
echo "  podman machine start"
echo ""
echo "Or on Linux (systemd):"
echo "  systemctl --user enable --now podman.socket"
