#!/bin/bash


# Lighthouse Consensus Client Installation Script
# Lighthouse is a Rust-based Ethereum consensus client developed by Sigma Prime

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting Lighthouse installation..."


# Check system requirements
check_system_requirements 16 1000

# Install dependencies
install_dependencies wget curl

# Setup firewall rules for Lighthouse
setup_firewall_rules 9000 5052

# Create Lighthouse directory
LIGHTHOUSE_DIR="$HOME/lighthouse"
ensure_directory "$LIGHTHOUSE_DIR"

cd "$LIGHTHOUSE_DIR" || exit

# Download Lighthouse
log_info "Downloading Lighthouse..."
if ! download_file "https://github.com/sigp/lighthouse/releases/download/v4.5.0/lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz" "lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz"; then
    log_error "Failed to download Lighthouse"
    exit 1
fi

tar -xvf lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz

# Generate JWT secret
log_info "Generating JWT secret..."
if ! openssl rand -hex 32 > "$HOME/secrets/jwt.hex"; then
    log_error "Failed to generate JWT secret"
    exit 1
fi

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create systemd service
EXEC_START="RUST_LOG=info $LIGHTHOUSE_DIR/lighthouse bn --checkpoint-sync-url https://mainnet.checkpoint.sigp.io --execution-endpoint http://localhost:8551 --execution-jwt $HOME/secrets/jwt.hex --disable-deposit-contract-sync"

create_systemd_service "cl" "Lighthouse Ethereum Consensus Client" "$EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable the service
enable_systemd_service "cl"

# Show completion information
show_installation_complete "Lighthouse" "cl" "" "$LIGHTHOUSE_DIR"

log_info "Starting Lighthouse service..."
sudo systemctl start cl
sudo systemctl status cl
