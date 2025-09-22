#!/bin/bash

# Install Teku Ethereum consensus client
# https://docs.teku.consensys.net/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Teku consensus client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps
install_java

# Create Teku directory
TEKU_DIR="$HOME/teku"
mkdir -p "$TEKU_DIR"

# Download and install Teku
log_info "Downloading Teku..."
TEKU_VERSION=$(get_latest_release "ConsenSys/teku")
TEKU_URL="https://artifacts.consensys.net/public/teku/raw/names/teku.tar.gz/versions/${TEKU_VERSION}/teku-${TEKU_VERSION}.tar.gz"

cd "$TEKU_DIR"
wget -O teku.tar.gz "$TEKU_URL"
tar -xzf teku.tar.gz
rm teku.tar.gz

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Teku configuration
log_info "Creating Teku configuration..."
cat > "$TEKU_DIR/teku.yaml" << EOF
# Teku configuration file

data-path: "$TEKU_DIR/data"
data-storage-mode: "prune"

# Network configuration
network: "mainnet"
p2p-port: 9000
p2p-peer-lower-bound: 20
p2p-peer-upper-bound: 50

# REST API
rest-api-enabled: true
rest-api-host: "127.0.0.1"
rest-api-port: 5051
rest-api-docs-enabled: true

# Execution client connection
ee-endpoint: "http://127.0.0.1:8551"
ee-jwt-secret-file: "$HOME/secrets/jwt.hex"

# Checkpoint sync
initial-state: "$PRYSM_CPURL/eth/v2/debug/beacon/states/finalized"

# Logging
log-destination: "file"
log-file: "$TEKU_DIR/teku.log"
log-level: "INFO"

# Metrics
metrics-enabled: true
metrics-host: "127.0.0.1"
metrics-port: 8008

# Validator configuration
validators-graffiti: "$GRAFITTI"
validators-proposer-default-fee-recipient: "$FEE_RECIPIENT"
EOF

# Create systemd service for beacon node
TEKU_CMD="$TEKU_DIR/bin/teku --config-file=$TEKU_DIR/teku.yaml"
create_systemd_service "cl" "Teku consensus client service" "$TEKU_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "9000" "5051" "8008"

# Print installation summary
print_installation_summary "Teku" "cl"

log_info "Teku installation completed successfully!"
log_info "Configuration file: $TEKU_DIR/teku.yaml"
log_info "Data directory: $TEKU_DIR/data"
log_info "Log file: $TEKU_DIR/teku.log"