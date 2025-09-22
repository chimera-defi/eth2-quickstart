#!/bin/bash

# Install Nimbus Ethereum consensus client
# https://nimbus.guide/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Nimbus consensus client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps

# Install Nim dependencies
sudo apt install -y build-essential git curl libpcre3-dev libssl-dev libffi-dev libsodium-dev

# Create Nimbus directory
NIMBUS_DIR="$HOME/nimbus"
mkdir -p "$NIMBUS_DIR"

# Install Nim
log_info "Installing Nim..."
if ! command -v nim &> /dev/null; then
    curl https://nim-lang.org/choosenim/init.sh -sSf | sh
    source $HOME/.bashrc
    choosenim stable
fi

# Clone and build Nimbus
log_info "Building Nimbus from source..."
clone_and_build "https://github.com/status-im/nimbus-eth2.git" "nimbus-eth2" "$NIMBUS_DIR" "make nimbus_beacon_node" "stable"

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Nimbus configuration
log_info "Creating Nimbus configuration..."
cat > "$NIMBUS_DIR/nimbus.conf" << EOF
# Nimbus configuration file

# Network
network = "mainnet"
tcp-port = 9000
udp-port = 9000
max-peers = 50

# REST API
rest = true
rest-address = "127.0.0.1"
rest-port = 5052

# Execution client connection
web3-url = "http://127.0.0.1:8551"
jwt-secret = "$HOME/secrets/jwt.hex"

# Checkpoint sync
trusted-node-url = "$PRYSM_CPURL"

# Logging
log-level = "INFO"
log-file = "$NIMBUS_DIR/nimbus.log"

# Metrics
metrics = true
metrics-address = "127.0.0.1"
metrics-port = 8008

# Validator configuration
graffiti = "$GRAFITTI"
suggested-fee-recipient = "$FEE_RECIPIENT"
EOF

# Create systemd service
NIMBUS_CMD="$NIMBUS_DIR/build/nimbus_beacon_node --config-file=$NIMBUS_DIR/nimbus.conf"
create_systemd_service "cl" "Nimbus consensus client service" "$NIMBUS_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "9000" "5052" "8008"

# Print installation summary
print_installation_summary "Nimbus" "cl"

log_info "Nimbus installation completed successfully!"
log_info "Configuration file: $NIMBUS_DIR/nimbus.conf"
log_info "Data directory: $NIMBUS_DIR/data"
log_info "Log file: $NIMBUS_DIR/nimbus.log"