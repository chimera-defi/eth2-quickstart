#!/bin/bash


# Flashbots Builder Geth Installation Script
# Builds Geth from Flashbots builder repository

source ../../exports.sh
source ../../lib/common_functions.sh

# Check if running as root
require_root

# Get script directories
get_script_directories

# Start installation
log_installation_start "Flashbots Builder Geth"


# Check system requirements
check_system_requirements 16 2000


# Clone Flashbots builder repository
log_info "Cloning Flashbots builder repository..."
if ! git clone https://github.com/flashbots/builder.git; then
    log_error "Failed to clone Flashbots builder repository"
    exit 1
fi

cd builder/ || exit

# Build Geth
log_info "Building Geth from source..."
if ! make geth; then
    log_error "Failed to build Geth"
    exit 1
fi

# Install Geth binary
log_info "Installing Geth binary..."
if ! sudo cp ./build/bin/geth /usr/bin/; then
    log_error "Failed to install Geth binary"
    exit 1
fi

log_installation_complete "Flashbots Builder Geth" "mev-geth"
log_info "Geth binary installed to: /usr/bin/geth"
log_info "This is a custom Geth build with Flashbots builder support"
