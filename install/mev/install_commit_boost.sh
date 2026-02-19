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

# Setup firewall rules for Commit-Boost (PBS, Signer, Metrics)
setup_firewall_rules "$COMMIT_BOOST_PORT" "$((COMMIT_BOOST_PORT + 1))" "$((COMMIT_BOOST_PORT + 2))"

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

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create configuration directory
CONFIG_DIR="$COMMIT_BOOST_DIR/config"
ensure_directory "$CONFIG_DIR"

# Create Commit-Boost configuration file (per official docs: https://commit-boost.github.io/commit-boost-client/get_started/configuration)
log_info "Creating Commit-Boost configuration..."
{
    echo "# Commit-Boost Configuration File"
    echo "# Generated on $(date)"
    echo "# Config format per: https://github.com/Commit-Boost/commit-boost-client/blob/main/config.example.toml"
    echo ""
    echo "chain = \"$COMMIT_BOOST_CHAIN\""
    echo ""
    echo "[pbs]"
    echo "host = \"$COMMIT_BOOST_HOST\""
    echo "port = $COMMIT_BOOST_PORT"
    echo "timeout_get_header_ms = $MEVGETHEADERT"
    echo "timeout_get_payload_ms = $MEVGETPAYLOADT"
    echo "timeout_register_validator_ms = $MEVREGVALT"
    echo "min_bid_eth = $MIN_BID"
    echo ""
    # Generate [[relays]] entries from MEV_RELAYS (comma-separated URLs)
    relay_num=1
    old_ifs="$IFS"
    IFS=',' read -ra RELAY_ARRAY <<< "$MEV_RELAYS"
    IFS="$old_ifs"
    for relay_url in "${RELAY_ARRAY[@]}"; do
        relay_url="${relay_url#"${relay_url%%[![:space:]]*}"}"
        relay_url="${relay_url%"${relay_url##*[![:space:]]}"}"
        [[ -z "$relay_url" ]] && continue
        # Derive id from hostname (part after @) or use relay-N
        if [[ "$relay_url" =~ @([^/]+) ]]; then
            relay_id="${BASH_REMATCH[1]}"
        else
            relay_id="relay-$relay_num"
        fi
        echo "[[relays]]"
        echo "id = \"$relay_id\""
        echo "url = \"$relay_url\""
        echo ""
        ((relay_num++)) || true
    done
    echo "[signer]"
    echo "host = \"$COMMIT_BOOST_HOST\""
    echo "port = $((COMMIT_BOOST_PORT + 1))"
    echo ""
    echo "[metrics]"
    echo "enabled = true"
    echo "host = \"$COMMIT_BOOST_HOST\""
    echo "start_port = $((COMMIT_BOOST_PORT + 2))"
} > "$CONFIG_DIR/cb-config.toml"

log_info "Configuration file created at: $CONFIG_DIR/cb-config.toml"

# Create systemd service for Commit-Boost PBS
log_info "Creating systemd service for Commit-Boost PBS..."
PBS_EXEC_START="$COMMIT_BOOST_DIR/commit-boost-pbs --config $CONFIG_DIR/cb-config.toml"

create_systemd_service "commit-boost-pbs" "Commit-Boost PBS (MEV Sidecar)" "$PBS_EXEC_START" "$(whoami)" "always" "600" "5" "300"

# Create systemd service for Commit-Boost Signer
log_info "Creating systemd service for Commit-Boost Signer..."
SIGNER_EXEC_START="$COMMIT_BOOST_DIR/commit-boost-signer --config $CONFIG_DIR/cb-config.toml --jwt-secret $HOME/secrets/jwt.hex"

create_systemd_service "commit-boost-signer" "Commit-Boost Signer" "$SIGNER_EXEC_START" "$(whoami)" "always" "600" "5" "300" "network-online.target" "network-online.target"

# Enable and start PBS service
enable_and_start_systemd_service "commit-boost-pbs"

# Enable and start Signer service
enable_and_start_systemd_service "commit-boost-signer"

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
  - commit-boost-pbs: $COMMIT_BOOST_DIR/commit-boost-pbs
  - commit-boost-signer: $COMMIT_BOOST_DIR/commit-boost-signer

Key Features:
- MEV-Boost relay compatibility
- Modular architecture for custom protocols
- Support for preconfirmations and commitment protocols
- Metrics and monitoring enabled
- Audited by Sigma Prime

Service Management:
- PBS:    sudo systemctl {start|stop|status} commit-boost-pbs
- Signer: sudo systemctl {start|stop|status} commit-boost-signer
- Logs PBS:    journalctl -u commit-boost-pbs -f
- Logs Signer: journalctl -u commit-boost-signer -f

Verification:
- Check PBS service: sudo systemctl status commit-boost-pbs
- Check Signer service: sudo systemctl status commit-boost-signer
- Check MEV-Boost compatibility: curl http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT/eth/v1/builder/status
- Check metrics: curl http://$COMMIT_BOOST_HOST:$((COMMIT_BOOST_PORT + 2))/metrics

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
