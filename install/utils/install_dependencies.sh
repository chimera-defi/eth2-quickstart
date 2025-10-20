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

log_info "Installing system dependencies..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Update system packages (unless skipped)
if [[ "$SKIP_SYSTEM_UPDATE" == "false" ]]; then
    if ! sudo apt update -y; then
        log_error "Failed to update package lists"
        exit 1
    fi
fi

# Install essential system packages
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
if ! add_ppa_repository "ppa:ethereum/ethereum"; then
    log_error "Failed to add Ethereum PPA repository"
    exit 1
fi

if ! install_dependencies ethereum; then
    log_error "Failed to install ethereum package"
    exit 1
fi

# Install snapd (unless skipped)
if [[ "$SKIP_SNAPD" == "false" ]]; then
    if ! sudo apt install -y snapd; then
        log_error "Failed to install snapd"
        exit 1
    fi
fi

# Install Node.js (unless skipped)
if [[ "$SKIP_NODEJS" == "false" ]]; then
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        if ! install_dependencies nodejs; then
            log_error "Failed to install Node.js"
            exit 1
        fi
    fi
fi

# Install Go (unless skipped)
if [[ "$SKIP_GO" == "false" ]]; then
    if ! command -v go &> /dev/null; then
        if ! sudo snap install --classic go; then
            log_error "Failed to install Go via snap"
            exit 1
        fi
        sudo ln -sf /snap/bin/go /usr/bin/go
    fi
fi

# Install Rust (for Reth)
if ! command -v cargo &> /dev/null; then
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        log_error "Failed to install Rust"
        exit 1
    fi
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi
fi

# Install Bazel (for Prysm MEV)
if ! command -v bazel &> /dev/null; then
    if ! sudo apt update && sudo apt install -y bazel bazel-5.3.0; then
        log_warn "Failed to install Bazel, some MEV features may not work"
    fi
fi

# Configure time synchronization
if ! timedatectl set-ntp on; then
    log_warn "Failed to enable NTP time synchronization"
fi

# Verify essential tools
ESSENTIAL_TOOLS=("curl" "wget" "git" "jq" "ufw")
for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        log_error "$tool is not installed or not in PATH"
        exit 1
    fi
done

# Check chrony service instead of command
if ! systemctl is-active --quiet chrony; then
    log_warn "chrony service is not active"
fi

log_info "Dependency installation completed successfully!"