#!/bin/bash

# Centralized Dependency Installation Script
# This script installs all system dependencies required for Ethereum node setup
# Usage: ./install_dependencies.sh [--skip-system-update] [--skip-snapd] [--skip-nodejs] [--skip-go]

set -Eeuo pipefail
IFS=$'\n\t'

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Command line options
SKIP_SYSTEM_UPDATE=false
SKIP_SNAPD=false
SKIP_NODEJS=false
SKIP_GO=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-system-update)
            SKIP_SYSTEM_UPDATE=true
            shift
            ;;
        --skip-snapd)
            SKIP_SNAPD=true
            shift
            ;;
        --skip-nodejs)
            SKIP_NODEJS=true
            shift
            ;;
        --skip-go)
            SKIP_GO=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-system-update    Skip system package update"
            echo "  --skip-snapd           Skip snapd installation"
            echo "  --skip-nodejs          Skip Node.js installation"
            echo "  --skip-go              Skip Go installation"
            echo "  --help                 Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log_info "Starting centralized dependency installation..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Update system packages (unless skipped)
if [[ "$SKIP_SYSTEM_UPDATE" == "false" ]]; then
    log_info "Updating system packages..."
    if ! sudo apt update -y; then
        log_error "Failed to update package lists"
        exit 1
    fi
    log_info "System packages updated successfully"
fi

# Install essential system packages (excluding ethereum which needs PPA)
log_info "Installing essential system packages..."
ESSENTIAL_PACKAGES=(
    "curl"
    "wget"
    "git"
    "unzip"
    "build-essential"
    "python3"
    "python3-pip"
    "jq"
    "chrony"
    "ufw"
    "aide"
    "software-properties-common"
)

if ! install_dependencies "${ESSENTIAL_PACKAGES[@]}"; then
    log_error "Failed to install essential packages"
    exit 1
fi

# Add Ethereum PPA and install ethereum package
log_info "Adding Ethereum PPA repository..."
if ! add_ppa_repository "ppa:ethereum/ethereum"; then
    log_error "Failed to add Ethereum PPA repository"
    exit 1
fi

log_info "Installing ethereum package..."
if ! install_dependencies ethereum; then
    log_error "Failed to install ethereum package"
    exit 1
fi

# Install snapd (unless skipped)
if [[ "$SKIP_SNAPD" == "false" ]]; then
    log_info "Installing snapd..."
    if ! sudo apt install -y snapd; then
        log_error "Failed to install snapd"
        exit 1
    fi
    log_info "snapd installed successfully"
fi

# Install Node.js (unless skipped)
if [[ "$SKIP_NODEJS" == "false" ]]; then
    log_info "Installing Node.js..."
    if ! command -v node &> /dev/null; then
        # Add NodeSource repository for Node.js 18.x
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        if ! install_dependencies nodejs; then
            log_error "Failed to install Node.js"
            exit 1
        fi
        log_info "Node.js installed: $(node --version)"
    else
        log_info "Node.js already installed: $(node --version)"
    fi
fi

# Install Go (unless skipped)
if [[ "$SKIP_GO" == "false" ]]; then
    log_info "Installing Go..."
    if ! command -v go &> /dev/null; then
        if ! sudo snap install --classic go; then
            log_error "Failed to install Go via snap"
            exit 1
        fi
        # Create symlink for easier access
        sudo ln -sf /snap/bin/go /usr/bin/go
        log_info "Go installed: $(go version)"
    else
        log_info "Go already installed: $(go version)"
    fi
fi

# Install Rust (for Reth)
log_info "Installing Rust..."
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    log_info "Rust installed: $(cargo --version)"
else
    log_info "Rust already installed: $(cargo --version)"
fi

# Install Bazel (for Prysm MEV)
log_info "Installing Bazel..."
if ! command -v bazel &> /dev/null; then
    if ! sudo apt update && sudo apt install -y bazel bazel-5.3.0; then
        log_warn "Failed to install Bazel, some MEV features may not work"
    else
        log_info "Bazel installed: $(bazel --version)"
    fi
else
    log_info "Bazel already installed: $(bazel --version)"
fi

# Configure time synchronization
log_info "Configuring time synchronization..."
if ! timedatectl set-ntp on; then
    log_warn "Failed to enable NTP time synchronization"
else
    log_info "Time synchronization enabled"
fi

# Verify installations
log_info "Verifying installations..."

# Check essential tools
ESSENTIAL_TOOLS=("curl" "wget" "git" "jq" "chrony" "ufw")
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "$tool is not installed or not in PATH"
        exit 1
    fi
done

# Check optional tools
OPTIONAL_TOOLS=("node" "go" "cargo" "bazel")
for tool in "${OPTIONAL_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        log_info "$tool: $(command -v "$tool")"
    else
        log_warn "$tool is not installed"
    fi
done

log_info "Dependency installation completed successfully!"
log_info "All essential dependencies are now available for Ethereum node setup"

# Display summary
cat << EOF

=== Dependency Installation Summary ===

Essential packages installed:
- curl, wget, git, unzip, build-essential
- python3, python3-pip, jq
- chrony (time synchronization)
- ufw (firewall)
- aide (file integrity monitoring)
- ethereum (Geth)

Development tools installed:
- Node.js $(node --version 2>/dev/null || echo "not installed")
- Go $(go version 2>/dev/null || echo "not installed")
- Rust $(cargo --version 2>/dev/null || echo "not installed")
- Bazel $(bazel --version 2>/dev/null || echo "not installed")

System services configured:
- NTP time synchronization enabled
- UFW firewall ready for configuration

Next steps:
1. Run client installation scripts
2. Configure firewall rules
3. Set up SSL certificates (optional)

EOF