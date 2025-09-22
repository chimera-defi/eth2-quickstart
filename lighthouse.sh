#!/bin/bash

# Install Lighthouse Ethereum consensus client
# https://lighthouse.sigmaprime.io/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Lighthouse consensus client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps

# Create Lighthouse directory
LIGHTHOUSE_DIR="$HOME/lighthouse"
mkdir -p "$LIGHTHOUSE_DIR"

# Download and install Lighthouse
log_info "Downloading Lighthouse..."
LIGHTHOUSE_VERSION=$(get_latest_release "sigp/lighthouse")
LIGHTHOUSE_URL="https://github.com/sigp/lighthouse/releases/download/${LIGHTHOUSE_VERSION}/lighthouse-${LIGHTHOUSE_VERSION}-x86_64-unknown-linux-gnu.tar.gz"

cd "$LIGHTHOUSE_DIR"
wget -O lighthouse.tar.gz "$LIGHTHOUSE_URL"
tar -xzf lighthouse.tar.gz
rm lighthouse.tar.gz

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Lighthouse configuration
log_info "Creating Lighthouse configuration..."
cat > "$LIGHTHOUSE_DIR/lighthouse.yaml" << EOF
# Lighthouse configuration file

# Network
network: "mainnet"
datadir: "$LIGHTHOUSE_DIR/data"

# Network configuration
discovery-port: 9000
port: 9000
max-peers: 50

# REST API
http: true
http-address: "127.0.0.1"
http-port: 5052

# Execution client connection
execution-endpoint: "http://127.0.0.1:8551"
execution-jwt: "$HOME/secrets/jwt.hex"

# Checkpoint sync
checkpoint-sync-url: "https://mainnet.checkpoint.sigp.io"

# Logging
logfile: "$LIGHTHOUSE_DIR/lighthouse.log"
log-level: "info"

# Metrics
metrics: true
metrics-address: "127.0.0.1"
metrics-port: 5054

# Validator configuration
graffiti: "$GRAFITTI"
suggested-fee-recipient: "$FEE_RECIPIENT"
EOF

# Create systemd service
LIGHTHOUSE_CMD="$LIGHTHOUSE_DIR/lighthouse bn --config-file=$LIGHTHOUSE_DIR/lighthouse.yaml"
create_systemd_service "cl" "Lighthouse consensus client service" "$LIGHTHOUSE_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "9000" "5052" "5054"

# Print installation summary
print_installation_summary "Lighthouse" "cl"

log_info "Lighthouse installation completed successfully!"
log_info "Configuration file: $LIGHTHOUSE_DIR/lighthouse.yaml"
log_info "Data directory: $LIGHTHOUSE_DIR/data"
log_info "Log file: $LIGHTHOUSE_DIR/lighthouse.log"
