#!/bin/bash


# Lighthouse Consensus Client Installation Script
# Lighthouse is a Rust-based Ethereum consensus client developed by Sigma Prime

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting Lighthouse installation..."


# Check system requirements
check_system_requirements 16 1000

# Install dependencies
install_dependencies wget curl

# Setup firewall rules for Lighthouse
setup_firewall_rules 9000 5052

# Create Lighthouse directory
LIGHTHOUSE_DIR="$HOME/lighthouse"
ensure_directory "$LIGHTHOUSE_DIR"

cd "$LIGHTHOUSE_DIR" || exit

# Download Lighthouse
log_info "Downloading Lighthouse..."
if ! download_file "https://github.com/sigp/lighthouse/releases/download/v4.5.0/lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz" "lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz"; then
    log_error "Failed to download Lighthouse"
    exit 1
fi

tar -xvf lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz

# Generate JWT secret
log_info "Generating JWT secret..."
if ! openssl rand -hex 32 > "$HOME/secrets/jwt.hex"; then
    log_error "Failed to generate JWT secret"
    exit 1
fi

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create systemd service for beacon node
BEACON_EXEC_START="RUST_LOG=info $LIGHTHOUSE_DIR/lighthouse bn --checkpoint-sync-url https://mainnet.checkpoint.sigp.io --execution-endpoint http://localhost:8551 --execution-jwt $HOME/secrets/jwt.hex --disable-deposit-contract-sync"

create_systemd_service "cl" "Lighthouse Ethereum Consensus Client (Beacon Node)" "$BEACON_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Create systemd service for validator
VALIDATOR_EXEC_START="RUST_LOG=info $LIGHTHOUSE_DIR/lighthouse vc --beacon-nodes http://localhost:5052"

create_systemd_service "validator" "Lighthouse Ethereum Validator Client" "$VALIDATOR_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300" "network-online.target cl.service" "network-online.target"

# Enable and start services
enable_and_start_systemd_service "cl"
enable_and_start_systemd_service "validator"

# Show completion information
show_installation_complete "Lighthouse" "cl" "" "$LIGHTHOUSE_DIR"

# Display setup information
cat << EOF

=== Lighthouse Setup Information ===
Lighthouse has been installed with the following components:
1. Beacon Node (cl service) - Connects to execution client and other beacon nodes
2. Validator Client (validator service) - Manages validator keys and duties

Next Steps:
1. Import your validator keys into: $LIGHTHOUSE_DIR/
2. Create keystore password files in: $HOME/secrets/
3. Wait for beacon node to sync (validator will start automatically)

Key features:
- REST API available on port 5052
- P2P networking on ports 9000 (TCP) and 9000 (UDP)
- Checkpoint sync enabled for faster initial sync
- MEV-Boost integration ready

Service Management:
- Check status: sudo systemctl status cl && sudo systemctl status validator
- View logs: journalctl -fu cl && journalctl -fu validator
- Restart: sudo systemctl restart cl && sudo systemctl restart validator

For more information, visit: https://lighthouse.sigmaprime.io/
EOF
