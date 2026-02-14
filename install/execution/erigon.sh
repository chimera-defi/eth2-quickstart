#!/bin/bash

# Erigon Execution Client Installation Script
# Uses pre-built binaries from GitHub releases (consistent with Besu, MEV-Boost, etc.)
# Erigon is a Go-based Ethereum client focused on efficiency and performance
# Usage: ./erigon.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

get_script_directories

log_installation_start "Erigon"

# Check system requirements (Erigon recommends >=32GB RAM)
check_system_requirements 32 2000

# Setup firewall rules for Erigon (align with README)
setup_firewall_rules 30303/tcp 30303/udp 30304/tcp 30304/udp 42069/tcp 42069/udp 4000/udp 4001/tcp

# Create Erigon directory
ERIGON_DIR="$HOME/erigon"
ensure_directory "$ERIGON_DIR"
cd "$ERIGON_DIR" || exit

# Get latest release (pre-built binaries, no build required)
log_info "Fetching latest Erigon release..."
LATEST_VERSION=$(get_latest_release "erigontech/erigon")
if [[ -z "$LATEST_VERSION" ]]; then
    LATEST_VERSION="v3.3.7"
    log_warn "Could not fetch latest version, using fallback: $LATEST_VERSION"
fi

# Erigon release format: erigon_v3.3.7_linux_amd64.tar.gz
ARCHIVE_FILE="erigon_${LATEST_VERSION}_linux_amd64.tar.gz"
DOWNLOAD_URL="https://github.com/erigontech/erigon/releases/download/${LATEST_VERSION}/${ARCHIVE_FILE}"

log_info "Downloading Erigon ${LATEST_VERSION}..."
if ! download_file "$DOWNLOAD_URL" "$ARCHIVE_FILE"; then
    log_error "Failed to download Erigon"
    exit 1
fi

log_info "Extracting Erigon..."
tar -xzf "$ARCHIVE_FILE"
rm -f "$ARCHIVE_FILE"

# Find erigon binary (may be in root or a subdir)
if [[ -f "$ERIGON_DIR/erigon" ]]; then
    chmod +x "$ERIGON_DIR/erigon"
elif [[ -f "$ERIGON_DIR/build/bin/erigon" ]]; then
    cp "$ERIGON_DIR/build/bin/erigon" "$ERIGON_DIR/"
    chmod +x "$ERIGON_DIR/erigon"
else
    ERIGON_BIN=$(find "$ERIGON_DIR" -maxdepth 3 -type f -name "erigon" -executable | head -1)
    if [[ -z "$ERIGON_BIN" ]]; then
        log_error "Erigon binary not found after extraction"
        exit 1
    fi
    cp "$ERIGON_BIN" "$ERIGON_DIR/erigon"
    chmod +x "$ERIGON_DIR/erigon"
fi

# Create Erigon configuration
log_info "Creating Erigon configuration..."
cat > "$ERIGON_DIR/config.yaml" << EOF
chain : "mainnet"
http : true
http.api : ["admin","engine","eth","erigon","web3","net","debug","db","trace","txpool","personal"]
authrpc.jwtsecret: '$HOME/secrets/jwt.hex'
externalcl: true
snapshots: true
nat: any
rpc.batch.limit: 1000
torrent.download.rate: 512mb
prune: hrtc
EOF

ensure_jwt_secret "$HOME/secrets/jwt.hex"

EXEC_START="$ERIGON_DIR/erigon --config $ERIGON_DIR/config.yaml --externalcl"
create_systemd_service "eth1" "Erigon Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"
enable_and_start_systemd_service "eth1"

log_installation_complete "Erigon" "eth1"
