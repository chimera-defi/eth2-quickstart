#!/bin/bash

# Install Lodestar Ethereum consensus client
# https://lodestar.chainsafe.io/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Lodestar consensus client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps
install_nodejs

# Create Lodestar directory
LODESTAR_DIR="$HOME/lodestar"
mkdir -p "$LODESTAR_DIR"

# Clone and build Lodestar
log_info "Building Lodestar from source..."
clone_and_build "https://github.com/ChainSafe/lodestar.git" "lodestar" "$LODESTAR_DIR" "npm install && npm run build" "main"

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Lodestar configuration
log_info "Creating Lodestar configuration..."
cat > "$LODESTAR_DIR/lodestar.yaml" << EOF
# Lodestar configuration file

network: "mainnet"
dataDir: "$LODESTAR_DIR/data"

# Network configuration
network.discv5.enabled: true
network.discv5.bindAddr: "0.0.0.0:9000"
network.discv5.bootEnrs: []
network.maxPeers: 50

# REST API
api.rest.enabled: true
api.rest.host: "127.0.0.1"
api.rest.port: 9596

# Execution client connection
execution.urls: ["http://127.0.0.1:8551"]
execution.jwtSecret: "$HOME/secrets/jwt.hex"

# Checkpoint sync
checkpointSyncUrl: "$PRYSM_CPURL"

# Logging
logLevel: "info"
logFile: "$LODESTAR_DIR/lodestar.log"

# Metrics
metrics.enabled: true
metrics.serverPort: 8008

# Validator configuration
graffiti: "$GRAFITTI"
suggestedFeeRecipient: "$FEE_RECIPIENT"
EOF

# Create systemd service
LODESTAR_CMD="$LODESTAR_DIR/packages/cli/bin/lodestar beacon --configFile=$LODESTAR_DIR/lodestar.yaml"
create_systemd_service "cl" "Lodestar consensus client service" "$LODESTAR_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "9000" "9596" "8008"

# Print installation summary
print_installation_summary "Lodestar" "cl"

log_info "Lodestar installation completed successfully!"
log_info "Configuration file: $LODESTAR_DIR/lodestar.yaml"
log_info "Data directory: $LODESTAR_DIR/data"
log_info "Log file: $LODESTAR_DIR/lodestar.log"