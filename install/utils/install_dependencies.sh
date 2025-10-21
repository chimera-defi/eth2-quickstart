#!/bin/bash

# Centralized Dependency Installation Script
# Usage: ./install_dependencies.sh [--skip-system-update] [--skip-snapd] [--skip-nodejs] [--skip-go]

set -Eeuo pipefail
IFS=$'\n\t'

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Parse command line arguments
SKIP_SYSTEM_UPDATE=false
SKIP_SNAPD=false
SKIP_NODEJS=false
SKIP_GO=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-system-update) SKIP_SYSTEM_UPDATE=true ;;
        --skip-snapd) SKIP_SNAPD=true ;;
        --skip-nodejs) SKIP_NODEJS=true ;;
        --skip-go) SKIP_GO=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options: --skip-system-update, --skip-snapd, --skip-nodejs, --skip-go, --help"
            exit 0
            ;;
        *) log_error "Unknown option: $1. Use --help for usage information"; exit 1 ;;
    esac
    shift
done

log_info "Installing system dependencies..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Update system packages (unless skipped)
[[ "$SKIP_SYSTEM_UPDATE" == "false" ]] && sudo apt update -y

# Install essential packages
ESSENTIAL_PACKAGES=(
    "curl" "wget" "git" "unzip" "build-essential" "python3" "python3-pip"
    "jq" "chrony" "ufw" "aide" "software-properties-common"
)

install_dependencies "${ESSENTIAL_PACKAGES[@]}" || {
    log_error "Failed to install essential packages"
    exit 1
}

# Add Ethereum PPA and install ethereum package
add_ppa_repository "ppa:ethereum/ethereum" || {
    log_error "Failed to add Ethereum PPA repository"
    exit 1
}
install_dependencies ethereum || {
    log_error "Failed to install ethereum package"
    exit 1
}

# Install optional packages (unless skipped)
[[ "$SKIP_SNAPD" == "false" ]] && sudo apt install -y snapd

# Install Node.js (unless skipped)
if [[ "$SKIP_NODEJS" == "false" ]] && ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    install_dependencies nodejs || {
        log_error "Failed to install Node.js"
        exit 1
    }
fi

# Install Go (unless skipped)
if [[ "$SKIP_GO" == "false" ]] && ! command -v go &> /dev/null; then
    if ! sudo snap install --classic go; then
        log_error "Failed to install Go via snap"
        exit 1
    fi
    sudo ln -sf /snap/bin/go /usr/bin/go
fi

# Install Rust (for Reth)
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || {
        log_error "Failed to install Rust"
        exit 1
    }
    [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
fi

# Install Bazel (for Prysm MEV) - non-critical
if ! command -v bazel &> /dev/null; then
    if ! (sudo apt update && sudo apt install -y bazel bazel-5.3.0); then
        log_warn "Failed to install Bazel, some MEV features may not work"
    fi
fi

# Configure time synchronization
timedatectl set-ntp on || log_warn "Failed to enable NTP time synchronization"

# Verify essential tools
for tool in curl wget git jq ufw; do
    command -v "$tool" &> /dev/null || {
        log_error "$tool is not installed or not in PATH"
        exit 1
    }
done

# Check chrony service
systemctl is-active --quiet chrony || log_warn "chrony service is not active"

log_info "Dependency installation completed successfully!"