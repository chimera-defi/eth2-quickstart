#!/bin/bash

# Install Besu Ethereum execution client
# https://besu.hyperledger.org/en/stable/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Besu execution client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps
install_java

# Create Besu directory
BESU_DIR="$HOME/besu"
mkdir -p "$BESU_DIR"

# Download and install Besu
log_info "Downloading Besu..."
BESU_VERSION=$(get_latest_release "hyperledger/besu")
BESU_URL="https://github.com/hyperledger/besu/releases/download/${BESU_VERSION}/besu-${BESU_VERSION}.tar.gz"

cd "$BESU_DIR"
wget -O besu.tar.gz "$BESU_URL"
tar -xzf besu.tar.gz
rm besu.tar.gz

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Besu configuration
log_info "Creating Besu configuration..."
cat > "$BESU_DIR/config.toml" << EOF
# Besu configuration file

data-path = "$BESU_DIR/data"
genesis-file = "$BESU_DIR/genesis.json"

# Network configuration
network = "mainnet"
p2p-port = 30303
max-peers = 50

# RPC configuration
rpc-http-enabled = true
rpc-http-host = "127.0.0.1"
rpc-http-port = 8545
rpc-http-api = ["ADMIN", "CLIQUE", "DEBUG", "EEA", "ETH", "IBFT", "MINER", "NET", "PERM", "PLUGINS", "PRIV", "TRACE", "TXPOOL", "WEB3"]

# WebSocket configuration
rpc-ws-enabled = true
rpc-ws-host = "127.0.0.1"
rpc-ws-port = 8546
rpc-ws-api = ["ADMIN", "CLIQUE", "DEBUG", "EEA", "ETH", "IBFT", "MINER", "NET", "PERM", "PLUGINS", "PRIV", "TRACE", "TXPOOL", "WEB3"]

# Engine API configuration
engine-rpc-enabled = true
engine-rpc-host = "127.0.0.1"
engine-rpc-port = 8551
engine-jwt-secret = "$HOME/secrets/jwt.hex"

# Sync configuration
sync-mode = "X_SNAP"
fast-sync-min-peers = 1

# Mining configuration
miner-enabled = false

# Logging
logging = "INFO"
log-file = "$BESU_DIR/besu.log"

# Metrics
metrics-enabled = true
metrics-host = "127.0.0.1"
metrics-port = 9545
metrics-categories = ["JVM", "PROCESS", "BLOCKCHAIN", "PEERS", "RPC", "NETWORK", "TRANSACTION_POOL"]
EOF

# Create systemd service
BESU_CMD="$BESU_DIR/bin/besu --config-file=$BESU_DIR/config.toml"
create_systemd_service "eth1" "Besu execution client service" "$BESU_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "30303" "8545" "8546" "8551" "9545"

# Print installation summary
print_installation_summary "Besu" "eth1"

log_info "Besu installation completed successfully!"
log_info "Configuration file: $BESU_DIR/config.toml"
log_info "Data directory: $BESU_DIR/data"
log_info "Log file: $BESU_DIR/besu.log"