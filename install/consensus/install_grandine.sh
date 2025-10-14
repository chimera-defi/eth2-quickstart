#!/bin/bash


# Grandine Consensus Client Installation Script
# Grandine is a Rust-based Ethereum consensus client focused on performance

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting Grandine installation..."


# Check system requirements
check_system_requirements 16 1000

# Install Rust and dependencies
if ! command -v cargo &> /dev/null; then
    log_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
else
    log_info "Rust already installed: $(rustc --version)"
fi

# Install dependencies
install_dependencies wget curl git build-essential pkg-config libssl-dev

# Setup firewall rules for Grandine
setup_firewall_rules 9000 5052

# Create Grandine directory
GRANDINE_DIR="$HOME/grandine"
ensure_directory "$GRANDINE_DIR"

cd "$GRANDINE_DIR" || exit

# Clone Grandine repository (as it may not have regular releases yet)
log_info "Cloning Grandine repository..."
if [[ -d ".git" ]]; then
    log_info "Updating existing Grandine repository..."
    git fetch origin
    git checkout main
    git pull origin main
else
    git clone https://github.com/grandinetech/grandine.git .
fi

# Build Grandine
log_info "Building Grandine... This may take some time."
if ! cargo build --release --bin grandine; then
    log_error "Failed to build Grandine. Please check your Rust installation and try again."
    exit 1
fi

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create Grandine data directory
GRANDINE_DATA_DIR="$HOME/.local/share/grandine"
ensure_directory "$GRANDINE_DATA_DIR"

# Create validator data directory
VALIDATOR_DATA_DIR="$GRANDINE_DATA_DIR/validators"
ensure_directory "$VALIDATOR_DATA_DIR"

# Create temporary directory for custom configuration
mkdir ./tmp

# Create custom configuration variables file
cat > ./tmp/grandine_custom.toml << EOF
# Grandine Custom Configuration Variables

# Network settings
target_peers = $MAX_PEERS

# Data directory
data_dir = "$GRANDINE_DATA_DIR"

# Execution layer
jwt_secret_path = "$HOME/secrets/jwt.hex"

# HTTP API
http_api_listen_address = "$CONSENSUS_HOST:${GRANDINE_REST_PORT}"

# Checkpoint sync
checkpoint_sync_url = "$GRANDINE_CHECKPOINT_URL"

# Metrics
metrics_listen_address = "$CONSENSUS_HOST:8008"

# Validator settings
suggested_fee_recipient = "$FEE_RECIPIENT"
graffiti = "$GRAFITTI"
EOF

# Merge base configuration with custom settings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat "$SCRIPT_DIR/configs/grandine/grandine_base.toml" ./tmp/grandine_custom.toml > "$GRANDINE_DIR/grandine.toml"

# Clean up temporary files
rm -rf ./tmp/

# Create validator client configuration (if Grandine supports separate validator client)
cat > "$GRANDINE_DIR/validator.toml" << EOF
# Grandine Validator Configuration

# Beacon node connection
beacon_node_endpoint = "http://$CONSENSUS_HOST:5052"

# Validator settings
validators_dir = "$VALIDATOR_DATA_DIR"
suggested_fee_recipient = "$FEE_RECIPIENT"
graffiti = "$GRAFITTI"

# Metrics
metrics_enabled = true
metrics_listen_address = "$CONSENSUS_HOST:8009"

# Safety
doppelganger_detection = true

# Logging
log_level = "info"
EOF

# Create systemd service for beacon node
BEACON_EXEC_START="$GRANDINE_DIR/target/release/grandine --config $GRANDINE_DIR/grandine.toml"

create_systemd_service "cl" "Grandine Ethereum Consensus Client" "$BEACON_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable service
enable_systemd_service "cl"

log_info "Grandine installation completed!"
log_info "Configuration file: $GRANDINE_DIR/grandine.toml"
log_info "Data directory: $GRANDINE_DATA_DIR"
log_info "Validator directory: $VALIDATOR_DATA_DIR"
log_info ""
log_info "To start Grandine: sudo systemctl start cl"
log_info "To check status: sudo systemctl status cl"
log_info "To view logs: journalctl -fu cl"

# Display setup information
cat << EOF

=== Grandine Setup Information ===
Grandine has been installed as a high-performance Rust consensus client.

Note: Grandine is a newer client and may have different validator management
compared to other clients. Please check the latest documentation for
validator key import procedures.

Next Steps:
1. Import your validator keys (check Grandine docs for specific procedure)
2. Start the beacon node: sudo systemctl start cl
3. Monitor logs to ensure proper sync and operation

Key features:
- High-performance Rust implementation
- HTTP API available on port 5052
- P2P networking on port 9000
- Metrics available on port 8008
- Checkpoint sync enabled for faster initial sync
- MEV-Boost integration ready
- Optimized for performance and correctness

Rust version: $(rustc --version)
Cargo version: $(cargo --version)

Important Notes:
- Grandine is under active development
- Always check the official documentation for the latest features
- Consider this an advanced option for experienced operators

Repository: https://github.com/grandinetech/grandine

EOF