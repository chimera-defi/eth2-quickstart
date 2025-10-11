#!/bin/bash


# Erigon Execution Client Installation Script
# Erigon is a Go-based Ethereum client focused on efficiency and performance

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting Erigon installation..."


# Check system requirements
check_system_requirements 16 2000

# Install dependencies
install_dependencies git build-essential

# Setup firewall rules for Erigon
setup_firewall_rules 30303 30304 42069 4000 4001

# Clone and build Erigon
log_info "Cloning Erigon repository..."
if ! git clone --recurse-submodules https://github.com/ledgerwatch/erigon.git; then
    log_error "Failed to clone Erigon repository"
    exit 1
fi

cd erigon || exit
git pull

log_info "Building Erigon..."
if ! make erigon; then
    log_error "Failed to build Erigon"
    exit 1
fi

if ! make rpcdaemon; then
    log_error "Failed to build RPC daemon"
    exit 1
fi

if ! make integration; then
    log_error "Failed to build integration tools"
    exit 1
fi

# Create Erigon directory
ERIGON_DIR="$HOME/erigon"
if [[ -d "$ERIGON_DIR" ]]; then
    rm -rf "$ERIGON_DIR"/*
else
    ensure_directory "$ERIGON_DIR"
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

# Copy Erigon binary
cp ./build/bin/erigon "$ERIGON_DIR/"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create systemd service
EXEC_START="$ERIGON_DIR/erigon --config $ERIGON_DIR/config.yaml --externalcl"

create_systemd_service "eth1" "Erigon Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable the service
enable_systemd_service "eth1"

# Show completion information
show_installation_complete "Erigon" "eth1" "$ERIGON_DIR/config.yaml" "$ERIGON_DIR"

# Print integration stages
log_info "Erigon integration stages:"
./build/bin/integration print_stages --chain mainnet --datadir ~/.local/share/erigon