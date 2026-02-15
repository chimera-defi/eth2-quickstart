#!/bin/bash

# Erigon Execution Client Installation Script
# Language: Go (pre-built binaries from GitHub releases)
# Erigon is a Go-based Ethereum client focused on efficiency and performance
# Usage: ./erigon.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Resolve script and project directories
get_script_directories

# Note: This script uses sudo internally for privileged operations

# Start installation
log_installation_start "Erigon"


# Check system requirements (Erigon recommends >=32GB RAM)
check_system_requirements 32 2000


# Setup firewall rules for Erigon (align with README)
# Public: 30303/30304 TCP+UDP (peering), 42069 TCP+UDP (snap), Caplin 4000/udp, 4001/tcp
# Private (NOT opened here): 8551, 8545, 9090, 9091, 6060, 6061
setup_firewall_rules 30303/tcp 30303/udp 30304/tcp 30304/udp 42069/tcp 42069/udp 4000/udp 4001/tcp

# Create Erigon directory
ERIGON_DIR="$HOME/erigon"
ensure_directory "$ERIGON_DIR"

cd "$ERIGON_DIR" || exit

# Get latest release (pre-built binaries)
log_info "Fetching latest Erigon release..."
LATEST_VERSION=$(get_latest_release "erigontech/erigon")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Erigon version from GitHub"
    exit 1
fi

# Parse version for download URL (v3.3.7 -> 3.3.7, filename: erigon_v3.3.7_linux_amd64.tar.gz)
VERSION_NUM="${LATEST_VERSION#v}"
DOWNLOAD_URL="https://github.com/erigontech/erigon/releases/download/${LATEST_VERSION}/erigon_v${VERSION_NUM}_linux_amd64.tar.gz"
ARCHIVE_FILE="erigon_v${VERSION_NUM}_linux_amd64.tar.gz"

log_info "Downloading Erigon ${LATEST_VERSION}..."
if ! download_file "$DOWNLOAD_URL" "$ARCHIVE_FILE"; then
    log_error "Failed to download Erigon"
    exit 1
fi

log_info "Extracting Erigon..."
tar -xzf "$ARCHIVE_FILE"
rm -f "$ARCHIVE_FILE"

# Move binaries from extracted dir to ERIGON_DIR (erigon_v3.3.7_linux_amd64/ -> .)
EXTRACTED_DIR=$(find "$ERIGON_DIR" -maxdepth 1 -type d -name "erigon_*" | head -1)
if [[ -n "$EXTRACTED_DIR" && "$EXTRACTED_DIR" != "$ERIGON_DIR" ]]; then
    mv "$EXTRACTED_DIR"/* "$ERIGON_DIR/"
    rmdir "$EXTRACTED_DIR"
fi

chmod +x "$ERIGON_DIR/erigon"

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

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create systemd service
EXEC_START="$ERIGON_DIR/erigon --config $ERIGON_DIR/config.yaml --externalcl"

create_systemd_service "eth1" "Erigon Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "eth1"

# Show completion information
log_installation_complete "Erigon" "eth1"

# Print integration stages
if [[ -f "$ERIGON_DIR/integration" ]]; then
    log_info "Erigon integration stages:"
    "$ERIGON_DIR/integration" print_stages --chain mainnet --datadir ~/.local/share/erigon 2>/dev/null || true
fi
