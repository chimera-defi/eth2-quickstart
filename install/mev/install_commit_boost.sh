#!/bin/bash

# Commit-Boost Installation Script
# Commit-Boost is a modular Ethereum validator sidecar that standardizes
# communication between validators and third-party protocols including MEV-Boost

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

log_installation_start "Commit-Boost"

# Check system requirements
check_system_requirements 8 1000

# Setup firewall rules for Commit-Boost
setup_firewall_rules "$COMMIT_BOOST_PORT"

# Create Commit-Boost directory
COMMIT_BOOST_DIR="$HOME/commit-boost"
ensure_directory "$COMMIT_BOOST_DIR"

cd "$COMMIT_BOOST_DIR" || exit

# Get latest release version
log_info "Fetching latest Commit-Boost release..."
LATEST_VERSION=$(get_latest_release "Commit-Boost/commit-boost-client")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Commit-Boost version from GitHub"
    exit 1
fi
log_info "Latest version: $LATEST_VERSION"

# Download Commit-Boost PBS binary
log_info "Downloading Commit-Boost PBS binary..."
PBS_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-pbs-${LATEST_VERSION}-linux_x86-64.tar.gz"
if ! download_file "$PBS_URL" "commit-boost-pbs.tar.gz"; then
    log_error "Failed to download Commit-Boost PBS binary"
    exit 1
fi

# Download Commit-Boost Signer binary
log_info "Downloading Commit-Boost Signer binary..."
SIGNER_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-signer-${LATEST_VERSION}-linux_x86-64.tar.gz"
if ! download_file "$SIGNER_URL" "commit-boost-signer.tar.gz"; then
    log_error "Failed to download Commit-Boost Signer binary"
    exit 1
fi

# Extract binaries
log_info "Extracting Commit-Boost binaries..."
tar -xzf commit-boost-pbs.tar.gz
tar -xzf commit-boost-signer.tar.gz

# Clean up archives
rm -f commit-boost-pbs.tar.gz commit-boost-signer.tar.gz

# Make binaries executable
chmod +x commit-boost-pbs commit-boost-signer

# Verify binaries exist
if [[ ! -f "$COMMIT_BOOST_DIR/commit-boost-pbs" ]]; then
    log_error "commit-boost-pbs binary not found after extraction"
    exit 1
fi

if [[ ! -f "$COMMIT_BOOST_DIR/commit-boost-signer" ]]; then
    log_error "commit-boost-signer binary not found after extraction"
    exit 1
fi

# Create configuration directory
CONFIG_DIR="$COMMIT_BOOST_DIR/config"
ensure_directory "$CONFIG_DIR"

# Create Commit-Boost configuration file
log_info "Creating Commit-Boost configuration..."
cat > "$CONFIG_DIR/cb-config.toml" << EOF
# Commit-Boost Configuration File
# Generated on $(date)

chain = "Mainnet"

[pbs]
port = $COMMIT_BOOST_PORT
timeout_get_header_ms = $MEVGETHEADERT
timeout_get_payload_ms = $MEVGETPAYLOADT
timeout_register_validator_ms = $MEVREGVALT

$(echo "$MEV_RELAYS" | tr ',' '\n' | sed 's|.*|[[relays]]\nurl = "&"|')

[signer]
port = $((COMMIT_BOOST_PORT + 1))

[signer.local.loader]
format = "prysm"
keys_path = "$HOME/.eth2validators/prysm-wallet-v2/direct/accounts/all-accounts.keystore.json"
secrets_path = "$HOME/secrets/pass.txt"

[metrics]
start_port = $((COMMIT_BOOST_PORT + 2))
EOF

log_info "Configuration file created at: $CONFIG_DIR/cb-config.toml"

# Create systemd service for Commit-Boost PBS
log_info "Creating systemd service for Commit-Boost PBS..."
PBS_EXEC_START="/usr/bin/env CB_CONFIG=$CONFIG_DIR/cb-config.toml $COMMIT_BOOST_DIR/commit-boost-pbs"

create_systemd_service "commit-boost-pbs" "Commit-Boost PBS (MEV Sidecar)" "$PBS_EXEC_START" "$(whoami)" "always" "600" "5" "300"

# Create systemd service for Commit-Boost Signer
log_info "Creating systemd service for Commit-Boost Signer..."
SIGNER_EXEC_START="/usr/bin/env CB_CONFIG=$CONFIG_DIR/cb-config.toml $COMMIT_BOOST_DIR/commit-boost-signer"

create_systemd_service "commit-boost-signer" "Commit-Boost Signer" "$SIGNER_EXEC_START" "$(whoami)" "always" "600" "5" "300" "network-online.target" "network-online.target"

# Enable and start PBS service
enable_and_start_systemd_service "commit-boost-pbs"

# Enable and start Signer service (may not start until validator keys are configured)
enable_and_start_systemd_service "commit-boost-signer" || log_warn "Signer service did not start - configure validator keys in $CONFIG_DIR/cb-config.toml to enable signing"

# Show completion information
log_installation_complete "Commit-Boost" "commit-boost-pbs" "$CONFIG_DIR/cb-config.toml" "$COMMIT_BOOST_DIR"

# Display setup information
cat << EOF

=== Commit-Boost Setup Information ===

Commit-Boost has been installed with the following components:
1. PBS Module (MEV-Boost compatible) - Port $COMMIT_BOOST_PORT
2. Signer Module - Port $((COMMIT_BOOST_PORT + 1))
3. Metrics Endpoint - Port $((COMMIT_BOOST_PORT + 2))

Installation Directory: $COMMIT_BOOST_DIR
Configuration File: $CONFIG_DIR/cb-config.toml
Binaries:
  - commit-boost-pbs:    $COMMIT_BOOST_DIR/commit-boost-pbs
  - commit-boost-signer: $COMMIT_BOOST_DIR/commit-boost-signer

Key Features:
- MEV-Boost relay compatibility
- Modular architecture for custom protocols
- Support for preconfirmations and commitment protocols (requires signer)
- Metrics and monitoring enabled
- Audited by Sigma Prime

Service Management:
- PBS:    sudo systemctl {start|stop|status} commit-boost-pbs
- Signer: sudo systemctl {start|stop|status} commit-boost-signer
- Logs PBS:    journalctl -u commit-boost-pbs -f
- Logs Signer: journalctl -u commit-boost-signer -f

Verification:
- Check PBS service:    sudo systemctl status commit-boost-pbs
- Check Signer service: sudo systemctl status commit-boost-signer
- Check MEV-Boost compatibility: curl http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT/eth/v1/builder/status

⚠️  NOTE: The Signer requires Prysm validator keys to be imported before it will start.
   Keys path: $HOME/.eth2validators/prysm-wallet-v2/direct/accounts/all-accounts.keystore.json
   After importing keys: sudo systemctl start commit-boost-signer

⚠️  IMPORTANT: Commit-Boost vs MEV-Boost
Commit-Boost is an ALTERNATIVE to MEV-Boost, not an addition.
- If you install Commit-Boost, you should NOT run MEV-Boost
- They both serve the same purpose (connecting to MEV relays)
- Commit-Boost adds support for additional protocols beyond standard MEV

Next Steps:
1. Stop MEV-Boost if running: sudo systemctl stop mev
2. Update your consensus client configuration to use Commit-Boost:
   - Use port $COMMIT_BOOST_PORT instead of MEV-Boost's port
   - Prysm: http-mev-relay: http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT
   - Teku: builder-endpoint: "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
   - Lighthouse: --builder http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT
   - Lodestar: builder.urls: ["http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"]
   - Nimbus: payload-builder-url = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
   - Grandine: builder_endpoint = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
3. Enable builder/MEV in your consensus client configuration
4. Restart your consensus client to apply changes

For more information:
- Documentation: https://commit-boost.github.io/commit-boost-client/
- Repository: https://github.com/Commit-Boost/commit-boost-client
- Twitter: https://x.com/Commit_Boost

EOF
