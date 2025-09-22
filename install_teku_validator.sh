#!/bin/bash

# Install Teku validator client
# https://docs.teku.consensys.net/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Teku validator client..."

# Check if not running as root
check_not_root

# Check if Teku is already installed
if [[ ! -d "$HOME/teku" ]]; then
    log_error "Teku consensus client not found. Please install it first with ./install_teku.sh"
    exit 1
fi

TEKU_DIR="$HOME/teku"

# Create validator configuration
log_info "Creating Teku validator configuration..."
cat > "$TEKU_DIR/validator.yaml" << EOF
# Teku validator configuration file

data-path: "$TEKU_DIR/validator-data"
beacon-node-api-endpoint: "http://127.0.0.1:5051"

# Validator configuration
validators-graffiti: "$GRAFITTI"
validators-proposer-default-fee-recipient: "$FEE_RECIPIENT"

# Logging
log-destination: "file"
log-file: "$TEKU_DIR/validator.log"
log-level: "INFO"

# Metrics
metrics-enabled: true
metrics-host: "127.0.0.1"
metrics-port: 8009
EOF

# Create systemd service for validator
TEKU_VALIDATOR_CMD="$TEKU_DIR/bin/teku validator-client --config-file=$TEKU_DIR/validator.yaml"
create_systemd_service "validator" "Teku validator client service" "$TEKU_VALIDATOR_CMD" "$(whoami)"

# Print installation summary
print_installation_summary "Teku Validator" "validator"

log_info "Teku validator installation completed successfully!"
log_info "Configuration file: $TEKU_DIR/validator.yaml"
log_info "Data directory: $TEKU_DIR/validator-data"
log_info "Log file: $TEKU_DIR/validator.log"