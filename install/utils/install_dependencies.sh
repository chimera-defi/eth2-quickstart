#!/bin/bash

# Centralized Dependency Installation Script
# Installs all dependencies needed for Ethereum node setup

# Source common functions and get directories
source ../../lib/common_functions.sh

log_info "Installing all system dependencies..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
    exit 1
fi

# Update system packages
sudo apt update -y

# Install all essential packages
ESSENTIAL_PACKAGES=(
    "curl" "wget" "git" "unzip" "build-essential" "python3" "python3-pip"
    "jq" "chrony" "ufw" "aide" "software-properties-common" "snapd"
    "cmake" "libssl-dev" "libgmp-dev" "libtinfo5" "libprotoc" "apt-transport-https" "gnupg"
    "pkg-config" "openjdk-17-jdk" "libclang-dev" "fail2ban" "nginx" "apache2-utils"
    "bmon" "slurm" "tcptrack"
)

install_dependencies "${ESSENTIAL_PACKAGES[@]}"

# Add Ethereum PPA and install ethereum package
add_ppa_repository "ppa:ethereum/ethereum"
install_dependencies ethereum

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
install_dependencies nodejs

# Install Go
sudo snap install --classic go
sudo ln -sf /snap/bin/go /usr/bin/go

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# Install Bazel
sudo apt install -y bazel bazel-5.3.0

# Install certbot
sudo snap install core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Configure time synchronization
timedatectl set-ntp on

log_info "All dependencies installed successfully!"