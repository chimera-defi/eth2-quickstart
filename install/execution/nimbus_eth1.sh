#!/bin/bash

# Nimbus Execution Client Installation Script
# Language: Nim
# Nimbus-eth1 is a Nim-based Ethereum execution client designed for resource efficiency
# Usage: ./nimbus_eth1.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

log_installation_start "Nimbus-eth1"

# Check system requirements (Nimbus is lightweight)
check_system_requirements 4 500

# Setup firewall rules for Nimbus execution client
setup_firewall_rules 30303 8545 8546 8551

# Create Nimbus execution client directory
NIMBUS_ETH1_DIR="$HOME/nimbus-eth1"
ensure_directory "$NIMBUS_ETH1_DIR"

cd "$NIMBUS_ETH1_DIR" || exit

# Nimbus-eth1 ships prebuilt release archives via GitHub Releases
log_info "Fetching latest Nimbus-eth1 release..."
NIMBUS_URL=$(get_github_release_asset_url "status-im/nimbus-eth1" "nimbus-linux-amd64-.*\\.tar\\.gz")
if [[ -z "$NIMBUS_URL" ]]; then
    log_error "Could not fetch Nimbus-eth1 release URL from GitHub"
    exit 1
fi

ARCHIVE_FILE="${NIMBUS_URL##*/}"

log_info "Downloading Nimbus-eth1 release build..."
if download_file "$NIMBUS_URL" "$ARCHIVE_FILE"; then
    if ! extract_archive "$ARCHIVE_FILE" "$NIMBUS_ETH1_DIR" 1; then
        log_error "Failed to extract Nimbus-eth1 archive"
        exit 1
    fi
    rm -f "$ARCHIVE_FILE"
else
    log_error "Failed to download Nimbus-eth1"
    exit 1
fi

# Find and make Nimbus executable (could be nimbus, nimbus-eth1, or in build/ subdirectory)
if [[ -f "$NIMBUS_ETH1_DIR/nimbus" ]]; then
    chmod +x "$NIMBUS_ETH1_DIR/nimbus"
    NIMBUS_EXEC="$NIMBUS_ETH1_DIR/nimbus"
elif [[ -f "$NIMBUS_ETH1_DIR/build/nimbus" ]]; then
    chmod +x "$NIMBUS_ETH1_DIR/build/nimbus"
    NIMBUS_EXEC="$NIMBUS_ETH1_DIR/build/nimbus"
elif [[ -f "$NIMBUS_ETH1_DIR/nimbus-eth1" ]]; then
    chmod +x "$NIMBUS_ETH1_DIR/nimbus-eth1"
    NIMBUS_EXEC="$NIMBUS_ETH1_DIR/nimbus-eth1"
else
    # Try to find any executable named nimbus*
    NIMBUS_EXEC=$(find "$NIMBUS_ETH1_DIR" -type f -name "nimbus*" -executable | head -1)
    if [[ -z "$NIMBUS_EXEC" ]]; then
        log_error "Could not find Nimbus executable"
        exit 1
    fi
fi

log_info "Found Nimbus executable: $NIMBUS_EXEC"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create Nimbus execution client data directory
NIMBUS_ETH1_DATA_DIR="$HOME/.local/share/nimbus-eth1"
ensure_directory "$NIMBUS_ETH1_DATA_DIR"

# Merge base + custom config so user-selected values and defaults are captured
create_temp_config_dir
cat > ./tmp/nimbus_eth1_custom.toml << EOF
data-dir = "$NIMBUS_ETH1_DATA_DIR"

# Shared HTTP listener for JSON-RPC + WS in current Nimbus-eth1
http-address = "$LH"
http-port = ${NIMBUS_ETH1_HTTP_PORT:-8545}
rpc = true
ws = true

engine-api = true
engine-api-address = "$LH"
engine-api-port = ${NIMBUS_ETH1_ENGINE_PORT:-8551}
jwt-secret = "$HOME/secrets/jwt.hex"

metrics = true
metrics-address = "$LH"
metrics-port = ${METRICS_PORT:-6060}
EOF

merge_client_config "Nimbus-eth1" "execution" \
    "$PROJECT_ROOT/configs/nimbus/nimbus_eth1_base.toml" \
    "./tmp/nimbus_eth1_custom.toml" \
    "$NIMBUS_ETH1_DIR/nimbus_eth1.toml"
rm -rf ./tmp/

# Create systemd service
EXEC_START="$NIMBUS_EXEC executionClient --config-file=$NIMBUS_ETH1_DIR/nimbus_eth1.toml"

create_systemd_service "eth1" "Nimbus Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "eth1"

log_installation_complete "Nimbus-eth1" "eth1"
log_info "Data directory: $NIMBUS_ETH1_DATA_DIR"
log_info "To check status: sudo systemctl status eth1"
log_info "To view logs: journalctl -fu eth1"

# Display setup information
cat << EOF

=== Nimbus-eth1 Setup Information ===
Nimbus-eth1 has been installed with the following features:
- Lightweight, resource-efficient execution client
- JSON-RPC API available on port ${NIMBUS_ETH1_HTTP_PORT:-8545}
- WebSocket API available on port ${NIMBUS_ETH1_HTTP_PORT:-8545}
- Engine API for consensus client communication on port ${NIMBUS_ETH1_ENGINE_PORT:-8551}
- P2P networking on port 30303
- Metrics available on port ${METRICS_PORT:-6060}

Next Steps:
1. Wait for execution client to sync (this may take 1-3 days)
2. Once synced, start your consensus client
3. Monitor sync progress: journalctl -fu eth1

Key features:
- Resource efficient design (low memory and CPU usage)
- Fast sync capabilities
- MEV-Boost ready
- Suitable for low-resource systems

Nimbus-eth1 is particularly suitable for:
- Raspberry Pi and other ARM devices
- VPS instances with limited resources
- Home stakers with bandwidth constraints

Note: Nimbus-eth1 is installed from the latest GitHub release archive.
Configuration: $NIMBUS_ETH1_DIR/nimbus_eth1.toml

EOF
