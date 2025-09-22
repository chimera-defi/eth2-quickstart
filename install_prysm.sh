#!/bin/bash

# Install Prysm Ethereum consensus client
# https://docs.prylabs.network/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Prysm consensus client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps

# Create Prysm directory
PRYSM_DIR="$HOME/prysm"
mkdir -p "$PRYSM_DIR"

# Download and install Prysm
log_info "Downloading Prysm..."
cd "$PRYSM_DIR"
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh
chmod +x prysm.sh

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Prysm beacon chain configuration
log_info "Creating Prysm beacon chain configuration..."
cat > "$PRYSM_DIR/prysm_beacon_conf.yaml" << EOF
# Prysm beacon chain configuration

# Network
network: "mainnet"

# P2P configuration
p2p-host-ip: $(curl -s v4.ident.me)
p2p-max-peers: $MAX_PEERS

# Checkpoint sync
checkpoint-sync-url: $PRYSM_CPURL
genesis-beacon-api-url: $PRYSM_CPURL

# Execution client connection
jwt-secret: $HOME/secrets/jwt.hex

# Validator configuration
graffiti: $GRAFITTI
suggested-fee-recipient: $FEE_RECIPIENT

# Logging
log-format: "text"
log-level: "info"
log-file: "$PRYSM_DIR/beacon.log"

# Metrics
enable-monitoring: true
monitoring-port: 8080
EOF

# Create Prysm validator configuration
log_info "Creating Prysm validator configuration..."
cat > "$PRYSM_DIR/prysm_validator_conf.yaml" << EOF
# Prysm validator configuration

# Validator configuration
graffiti: $GRAFITTI
suggested-fee-recipient: $FEE_RECIPIENT
wallet-password-file: $HOME/secrets/pass.txt

# Logging
log-format: "text"
log-level: "info"
log-file: "$PRYSM_DIR/validator.log"

# Metrics
enable-monitoring: true
monitoring-port: 8081
EOF

# Create systemd services
PRYSM_BEACON_CMD="$PRYSM_DIR/prysm.sh beacon-chain --config-file=$PRYSM_DIR/prysm_beacon_conf.yaml"
create_systemd_service "cl" "Prysm consensus client service" "$PRYSM_BEACON_CMD" "$(whoami)"

PRYSM_VALIDATOR_CMD="$PRYSM_DIR/prysm.sh validator --config-file=$PRYSM_DIR/prysm_validator_conf.yaml"
create_systemd_service "validator" "Prysm validator client service" "$PRYSM_VALIDATOR_CMD" "$(whoami)" "network-online.target cl.service" "network-online.target"

# Open required ports
open_firewall_ports "9000" "8080" "8081"

# Print installation summary
print_installation_summary "Prysm" "cl" "validator"

log_info "Prysm installation completed successfully!"
log_info "Configuration files:"
log_info "  - Beacon: $PRYSM_DIR/prysm_beacon_conf.yaml"
log_info "  - Validator: $PRYSM_DIR/prysm_validator_conf.yaml"
log_info "Log files:"
log_info "  - Beacon: $PRYSM_DIR/beacon.log"
log_info "  - Validator: $PRYSM_DIR/validator.log"
