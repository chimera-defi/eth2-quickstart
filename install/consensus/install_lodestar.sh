#!/bin/bash


# Lodestar Consensus Client Installation Script
# Lodestar is a TypeScript Ethereum consensus client developed by ChainSafe

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting Lodestar installation..."


# Check system requirements
check_system_requirements 16 1000

# Install Node.js and npm if not present
if ! command -v node &> /dev/null; then
    log_info "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    install_dependencies nodejs
else
    log_info "Node.js already installed: $(node --version)"
fi

# Install dependencies
install_dependencies wget curl git build-essential python3

# Setup firewall rules for Lodestar
setup_firewall_rules 9000 9596

# Create Lodestar directory
LODESTAR_DIR="$HOME/lodestar"
ensure_directory "$LODESTAR_DIR"

cd "$LODESTAR_DIR" || exit

# Install Lodestar globally using npm
log_info "Installing Lodestar via npm..."
if ! npm install -g @chainsafe/lodestar; then
    log_error "Failed to install Lodestar via npm. Please check your Node.js installation and try again."
    exit 1
fi

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create Lodestar data directory
LODESTAR_DATA_DIR="$HOME/.local/share/lodestar"
ensure_directory "$LODESTAR_DATA_DIR"

# Create validator data directory
VALIDATOR_DATA_DIR="$LODESTAR_DATA_DIR/validators"
ensure_directory "$VALIDATOR_DATA_DIR"

# Create temporary directory for custom configuration
mkdir ./tmp

# Create custom beacon node configuration variables
cat > ./tmp/lodestar_beacon_custom.json << EOF
{
  "dataDir": "$LODESTAR_DATA_DIR/beacon",
  "targetPeers": $MAX_PEERS,
  "execution": {
    "urls": ["http://$LH:$ENGINE_PORT"],
    "jwtSecretFile": "$HOME/secrets/jwt.hex"
  },
  "rest": {
    "port": ${LODESTAR_REST_PORT}
  },
  "metrics": {
    "port": 8008
  },
  "checkpointSyncUrl": "$LODESTAR_CHECKPOINT_URL",
  "suggestedFeeRecipient": "$FEE_RECIPIENT",
  "graffiti": "$GRAFITTI",
  "logFile": "$LODESTAR_DATA_DIR/beacon.log"
}
EOF

# Create custom validator configuration variables  
cat > ./tmp/lodestar_validator_custom.json << EOF
{
  "dataDir": "$LODESTAR_DATA_DIR/validator",
  "keystoresDir": "$VALIDATOR_DATA_DIR/keystores",
  "secretsDir": "$VALIDATOR_DATA_DIR/secrets",
  "beaconNodes": ["http://$CONSENSUS_HOST:${LODESTAR_REST_PORT}"],
  "suggestedFeeRecipient": "$FEE_RECIPIENT",
  "graffiti": "$GRAFITTI",
  "metrics": {
    "port": 8009
  },
  "logFile": "$LODESTAR_DATA_DIR/validator.log"
}
EOF

# Merge base configurations with custom settings using jq (if available) or simple concatenation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v jq &> /dev/null; then
    jq -s '.[0] * .[1]' "$SCRIPT_DIR/configs/lodestar/lodestar_beacon_base.json" ./tmp/lodestar_beacon_custom.json > "$LODESTAR_DIR/beacon.config.json"
    jq -s '.[0] * .[1]' "$SCRIPT_DIR/configs/lodestar/lodestar_validator_base.json" ./tmp/lodestar_validator_custom.json > "$LODESTAR_DIR/validator.config.json"
else
    # Fallback: create complete configs with variables (TODO: implement proper JSON merging)
    cat > "$LODESTAR_DIR/beacon.config.json" << EOF
{
  "network": "mainnet",
  "dataDir": "$LODESTAR_DATA_DIR/beacon",
  "port": 9000,
  "discoveryPort": 9000,
  "targetPeers": $MAX_PEERS,
  "execution": {
    "urls": ["http://$LH:$ENGINE_PORT"],
    "jwtSecretFile": "$HOME/secrets/jwt.hex"
  },
  "rest": {
    "enabled": true,
    "host": "$CONSENSUS_HOST",
    "port": ${LODESTAR_REST_PORT},
    "cors": "*"
  },
  "metrics": {
    "enabled": true,
    "host": "$CONSENSUS_HOST",
    "port": 8008
  },
  "checkpointSyncUrl": "$LODESTAR_CHECKPOINT_URL",
  "suggestedFeeRecipient": "$FEE_RECIPIENT",
  "graffiti": "$GRAFITTI",
  "builder": {
    "enabled": true,
    "urls": ["http://$MEV_HOST:$MEV_PORT"]
  },
  "logLevel": "info",
  "logFile": "$LODESTAR_DATA_DIR/beacon.log"
}
EOF

    cat > "$LODESTAR_DIR/validator.config.json" << EOF
{
  "network": "mainnet",
  "dataDir": "$LODESTAR_DATA_DIR/validator",
  "keystoresDir": "$VALIDATOR_DATA_DIR/keystores",
  "secretsDir": "$VALIDATOR_DATA_DIR/secrets",
  "beaconNodes": ["http://$CONSENSUS_HOST:${LODESTAR_REST_PORT}"],
  "suggestedFeeRecipient": "$FEE_RECIPIENT",
  "graffiti": "$GRAFITTI",
  "metrics": {
    "enabled": true,
    "host": "$CONSENSUS_HOST",
    "port": 8009
  },
  "builder": {
    "enabled": true
  },
  "doppelgangerProtection": {
    "enabled": true
  },
  "logLevel": "info",
  "logFile": "$LODESTAR_DATA_DIR/validator.log"
}
EOF
fi

# Clean up temporary files
rm -rf ./tmp/

# Create systemd service for beacon node
BEACON_EXEC_START="lodestar beacon --paramsFile $LODESTAR_DIR/beacon.config.json"

create_systemd_service "cl" "Lodestar Ethereum Consensus Client (Beacon Node)" "$BEACON_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Create systemd service for validator
VALIDATOR_EXEC_START="lodestar validator --paramsFile $LODESTAR_DIR/validator.config.json"

create_systemd_service "validator" "Lodestar Ethereum Validator Client" "$VALIDATOR_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300" "network-online.target cl.service" "network-online.target"

# Enable services
enable_systemd_service "cl"
enable_systemd_service "validator"

log_info "Lodestar installation completed!"
log_info "Beacon node configuration: $LODESTAR_DIR/beacon.config.json"
log_info "Validator configuration: $LODESTAR_DIR/validator.config.json"
log_info "Data directory: $LODESTAR_DATA_DIR"
log_info "Validator directory: $VALIDATOR_DATA_DIR"
log_info ""
log_info "To start beacon node: sudo systemctl start cl"
log_info "To start validator: sudo systemctl start validator"
log_info "To check status: sudo systemctl status cl && sudo systemctl status validator"
log_info "To view logs: journalctl -fu cl && journalctl -fu validator"

# Display setup information
cat << EOF

=== Lodestar Setup Information ===
Lodestar has been installed with the following components:
1. Beacon Node (cl service) - TypeScript-based consensus client
2. Validator Client (validator service) - Manages validator keys and duties

Next Steps:
1. Import your validator keys into: $VALIDATOR_DATA_DIR/keystores/
2. Create keystore password files in: $VALIDATOR_DATA_DIR/secrets/
3. Start the beacon node: sudo systemctl start cl
4. Wait for beacon node to sync, then start validator: sudo systemctl start validator

Key features:
- Written in TypeScript for developer accessibility
- REST API available on port 9596
- P2P networking on port 9000
- Metrics available on ports 8008 (beacon) and 8009 (validator)
- Checkpoint sync enabled for faster initial sync
- MEV-Boost integration ready
- Doppelganger protection for validator safety
- Comprehensive logging and monitoring

Node.js version: $(node --version)
NPM version: $(npm --version)

Useful commands:
- Check Lodestar version: lodestar --version
- Import validator keys: lodestar validator import --keystoresDir $VALIDATOR_DATA_DIR/keystores --secretsDir $VALIDATOR_DATA_DIR/secrets

EOF