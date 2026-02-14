#!/bin/bash

# Reth Execution Client Installation Script
# Uses pre-built binaries from GitHub releases (consistent with Besu, MEV-Boost, etc.)
# Reth is a Rust-based Ethereum client focused on performance and modularity
# Usage: ./reth.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

get_script_directories

log_installation_start "Reth"

# Check system requirements
check_system_requirements 16 2000

# Setup firewall rules for Reth
setup_firewall_rules 30303 30304 42069 4000 4001

# Create Reth directory
RETH_DIR="$HOME/reth"
ensure_directory "$RETH_DIR"
cd "$RETH_DIR" || exit

# Get latest release (pre-built binaries, no Rust build required)
log_info "Fetching latest Reth release..."
LATEST_VERSION=$(get_latest_release "paradigmxyz/reth")
if [[ -z "$LATEST_VERSION" ]]; then
    LATEST_VERSION="v1.10.2"
    log_warn "Could not fetch latest version, using fallback: $LATEST_VERSION"
fi

# Reth release format: op-reth-v1.10.2-x86_64-unknown-linux-gnu.tar.gz
ARCHIVE_FILE="op-reth-${LATEST_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
DOWNLOAD_URL="https://github.com/paradigmxyz/reth/releases/download/${LATEST_VERSION}/${ARCHIVE_FILE}"

log_info "Downloading Reth ${LATEST_VERSION}..."
if ! download_file "$DOWNLOAD_URL" "$ARCHIVE_FILE"; then
    log_error "Failed to download Reth"
    exit 1
fi

log_info "Extracting Reth..."
tar -xzf "$ARCHIVE_FILE"
rm -f "$ARCHIVE_FILE"

# op-reth tarball extracts to reth or op-reth binary
RETH_BIN=""
for name in reth op-reth; do
    if [[ -f "$RETH_DIR/$name" ]]; then
        RETH_BIN="$RETH_DIR/$name"
        break
    fi
    RETH_BIN=$(find "$RETH_DIR" -maxdepth 2 -type f -name "$name" 2>/dev/null | head -1)
    [[ -n "$RETH_BIN" ]] && break
done
if [[ -z "$RETH_BIN" ]]; then
    log_error "Reth binary not found after extraction"
    exit 1
fi
cp "$RETH_BIN" "$RETH_DIR/reth"
chmod +x "$RETH_DIR/reth"

# Install to ~/.cargo/bin for consistency (systemd uses this path)
ensure_directory "$HOME/.cargo/bin"
cp "$RETH_DIR/reth" "$HOME/.cargo/bin/reth"
chmod +x "$HOME/.cargo/bin/reth"

ensure_jwt_secret "$HOME/secrets/jwt.hex"

EXEC_START="$HOME/.cargo/bin/reth node"
create_systemd_service "eth1" "Reth Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "6000" "10" "3000"
enable_and_start_systemd_service "eth1"

log_installation_complete "Reth" "eth1"
