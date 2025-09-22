#!/bin/bash

# Install Reth Ethereum execution client
# https://paradigmxyz.github.io/reth/installation/source.html

source ./exports.sh
source ./common_functions.sh

log_info "Installing Reth execution client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps
install_rust

# Install additional Rust dependencies
sudo apt-get install -y libclang-dev pkg-config build-essential

# Create Reth directory
RETH_DIR="$HOME/reth"
mkdir -p "$RETH_DIR"

# Clone and build Reth from source
log_info "Building Reth from source..."
clone_and_build "https://github.com/paradigmxyz/reth.git" "reth" "$RETH_DIR" "RUSTFLAGS=\"-C target-cpu=native\" cargo build --profile maxperf --release --bin reth" "main"

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Reth configuration
log_info "Creating Reth configuration..."
cat > "$RETH_DIR/reth.toml" << EOF
# Reth configuration file

[datadir]
path = "$RETH_DIR/data"

[network]
port = 30303
max_outbound_peers = 50
max_inbound_peers = 50

[rpc]
http = true
http.addr = "127.0.0.1"
http.port = 8545
http.api = ["eth", "net", "web3", "debug", "trace", "txpool", "admin", "rpc"]

ws = true
ws.addr = "127.0.0.1"
ws.port = 8546
ws.api = ["eth", "net", "web3", "debug", "trace", "txpool", "admin", "rpc"]

# Engine API
authrpc.addr = "127.0.0.1"
authrpc.port = 8551
authrpc.jwtsecret = "$HOME/secrets/jwt.hex"

[txpool]
max_account_slots = 16
max_allowed_senders = 1000

[log]
file = "$RETH_DIR/reth.log"
level = "info"

[metrics]
enabled = true
addr = "127.0.0.1"
port = 9001
EOF

# Create systemd service
RETH_CMD="$RETH_DIR/target/release/reth node --config $RETH_DIR/reth.toml"
create_systemd_service "eth1" "Reth execution client service" "$RETH_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "30303" "8545" "8546" "8551" "9001"

# Print installation summary
print_installation_summary "Reth" "eth1"

log_info "Reth installation completed successfully!"
log_info "Configuration file: $RETH_DIR/reth.toml"
log_info "Data directory: $RETH_DIR/data"
log_info "Log file: $RETH_DIR/reth.log"