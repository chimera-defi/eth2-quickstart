#!/bin/bash

# Reth Execution Client Installation Script
# Language: Rust (pre-built binaries from GitHub releases)
# Reth is a Rust-based Ethereum client focused on performance and modularity
# Usage: ./reth.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

# Note: This script uses sudo internally for privileged operations

# Start installation
log_installation_start "Reth"


# Check system requirements
check_system_requirements 16 2000

# Setup firewall rules for Reth
setup_firewall_rules 30303 30304 42069 4000 4001

# Create Reth directory
RETH_DIR="$HOME/reth"
ensure_directory "$RETH_DIR"

cd "$RETH_DIR" || exit

# Get latest release (pre-built binaries)
log_info "Fetching latest Reth release..."
LATEST_VERSION=$(get_latest_release "paradigmxyz/reth")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Reth version from GitHub"
    exit 1
fi

# Download URL: reth-v1.10.2-x86_64-unknown-linux-gnu.tar.gz
VERSION_NUM="${LATEST_VERSION#v}"
DOWNLOAD_URL="https://github.com/paradigmxyz/reth/releases/download/${LATEST_VERSION}/reth-v${VERSION_NUM}-x86_64-unknown-linux-gnu.tar.gz"
ARCHIVE_FILE="reth-v${VERSION_NUM}-x86_64-unknown-linux-gnu.tar.gz"

log_info "Downloading Reth ${LATEST_VERSION}..."
if ! download_file "$DOWNLOAD_URL" "$ARCHIVE_FILE"; then
    log_error "Failed to download Reth"
    exit 1
fi

log_info "Extracting Reth..."
tar -xzf "$ARCHIVE_FILE"
rm -f "$ARCHIVE_FILE"

# Tarball contains single 'reth' binary at root
if [[ ! -f "$RETH_DIR/reth" ]]; then
    log_error "Reth binary not found after extraction"
    exit 1
fi

chmod +x "$RETH_DIR/reth"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create systemd service
EXEC_START="$RETH_DIR/reth node"

create_systemd_service "eth1" "Reth Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "6000" "10" "3000"

# Enable and start the service
enable_and_start_systemd_service "eth1"

# Show completion information
log_installation_complete "Reth" "eth1"
