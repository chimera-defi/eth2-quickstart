#!/bin/bash

# Commit-Boost Installation Script
# Commit-Boost is a modular Ethereum validator sidecar that standardizes
# communication between validators and third-party protocols including MEV-Boost.
# It replaces MEV-Boost with a modular architecture: PBS + Signer + optional modules.
# Ref: https://commit-boost.github.io/commit-boost-client/
# Ref: https://github.com/Commit-Boost/commit-boost-client

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

get_script_directories

log_installation_start "Commit-Boost"

check_system_requirements 8 1000

# Setup firewall rules for PBS port (beacon node connects here)
setup_firewall_rules "$COMMIT_BOOST_PORT"

COMMIT_BOOST_DIR="$HOME/commit-boost"
ensure_directory "$COMMIT_BOOST_DIR"

cd "$COMMIT_BOOST_DIR" || exit

# =============================================================================
# DOWNLOAD BINARIES
# =============================================================================

log_info "Fetching latest Commit-Boost release..."
LATEST_VERSION=$(get_latest_release "Commit-Boost/commit-boost-client")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Commit-Boost version from GitHub"
    exit 1
fi
log_info "Latest version: $LATEST_VERSION"

# Asset naming: commit-boost-{component}-{version}-linux_x86-64.tar.gz
# Each tarball contains a single binary named commit-boost-{component}

log_info "Downloading Commit-Boost PBS binary..."
PBS_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-pbs-${LATEST_VERSION}-linux_x86-64.tar.gz"
if ! download_file "$PBS_URL" "commit-boost-pbs.tar.gz"; then
    log_error "Failed to download Commit-Boost PBS binary"
    exit 1
fi

log_info "Downloading Commit-Boost Signer binary..."
SIGNER_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-signer-${LATEST_VERSION}-linux_x86-64.tar.gz"
if ! download_file "$SIGNER_URL" "commit-boost-signer.tar.gz"; then
    log_error "Failed to download Commit-Boost Signer binary"
    exit 1
fi

log_info "Downloading Commit-Boost CLI..."
CLI_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-cli-${LATEST_VERSION}-linux_x86-64.tar.gz"
if ! download_file "$CLI_URL" "commit-boost-cli.tar.gz"; then
    log_warn "Failed to download Commit-Boost CLI (optional, continuing without it)"
fi

# =============================================================================
# EXTRACT BINARIES
# =============================================================================

log_info "Extracting Commit-Boost binaries..."
tar -xzf commit-boost-pbs.tar.gz
tar -xzf commit-boost-signer.tar.gz
if [[ -f "commit-boost-cli.tar.gz" ]]; then
    tar -xzf commit-boost-cli.tar.gz
fi

rm -f commit-boost-pbs.tar.gz commit-boost-signer.tar.gz commit-boost-cli.tar.gz

chmod +x commit-boost-pbs commit-boost-signer
[[ -f "commit-boost-cli" ]] && chmod +x commit-boost-cli

if [[ ! -f "$COMMIT_BOOST_DIR/commit-boost-pbs" ]]; then
    log_error "commit-boost-pbs binary not found after extraction"
    exit 1
fi

if [[ ! -f "$COMMIT_BOOST_DIR/commit-boost-signer" ]]; then
    log_error "commit-boost-signer binary not found after extraction"
    exit 1
fi

log_info "Binaries extracted: commit-boost-pbs, commit-boost-signer$([ -f commit-boost-cli ] && echo ', commit-boost-cli')"

# =============================================================================
# JWT SECRET
# =============================================================================

ensure_jwt_secret "$HOME/secrets/jwt.hex"

# =============================================================================
# CONFIGURATION
# =============================================================================

CONFIG_DIR="$COMMIT_BOOST_DIR/config"
ensure_directory "$CONFIG_DIR"

# Build relay entries in TOML [[relays]] format from MEV_RELAYS comma-separated list
RELAY_TOML=""
IFS=',' read -ra RELAY_ARRAY <<< "$MEV_RELAYS"
for relay in "${RELAY_ARRAY[@]}"; do
    relay="$(echo "$relay" | xargs)"
    [[ -z "$relay" ]] && continue
    RELAY_TOML+="
[[relays]]
url = \"$relay\"
"
done

log_info "Creating Commit-Boost configuration..."
cat > "$CONFIG_DIR/cb-config.toml" << EOF
# Commit-Boost Configuration
# Generated on $(date)
# Docs: https://commit-boost.github.io/commit-boost-client/get_started/configuration/

chain = "Mainnet"

[pbs]
port = $COMMIT_BOOST_PORT
host = "$COMMIT_BOOST_HOST"
relay_check = true
timeout_get_header_ms = $MEVGETHEADERT
timeout_get_payload_ms = $MEVGETPAYLOADT
timeout_register_validator_ms = $MEVREGVALT
min_bid_eth = $MIN_BID
late_in_slot_time_ms = 2000
skip_sigverify = false
${RELAY_TOML}
# Signer module: only needed for commitment protocols (preconfirmations, etc.)
# Uncomment and configure when you want to enable the signer with your validator keys.
# See: https://commit-boost.github.io/commit-boost-client/get_started/configuration/#signer-module
# [signer]
# port = $COMMIT_BOOST_SIGNER_PORT
# host = "$COMMIT_BOOST_HOST"
#
# For local keys (example for Lighthouse keystore format):
# [signer.local.loader]
# format = "lighthouse"
# keys_path = "/path/to/validator/keys"
# secrets_path = "/path/to/validator/secrets"
#
# [signer.local.store]
# proxy_dir = "$COMMIT_BOOST_DIR/proxies"

[metrics]
enabled = true
host = "$COMMIT_BOOST_HOST"
start_port = $COMMIT_BOOST_METRICS_PORT

[logs.stdout]
enabled = true
level = "info"
color = true

[logs.file]
enabled = true
level = "debug"
dir_path = "$COMMIT_BOOST_DIR/logs"
max_files = 30
EOF

ensure_directory "$COMMIT_BOOST_DIR/logs"

log_info "Configuration file created at: $CONFIG_DIR/cb-config.toml"

# =============================================================================
# SYSTEMD SERVICES
# =============================================================================

# PBS Module: receives BuilderAPI calls from the beacon node
# Environment variable CB_CONFIG is required for binary mode
log_info "Creating systemd service for Commit-Boost PBS..."
PBS_EXEC_START="$COMMIT_BOOST_DIR/commit-boost-pbs"

# Write a custom service file to include Environment directives
PBS_SERVICE_FILE="$HOME/commit-boost-pbs.service"
cat > "$PBS_SERVICE_FILE" << EOF
[Unit]
Description=Commit-Boost PBS (MEV Sidecar)
Wants=network-online.target
After=network-online.target

[Service]
User=$(whoami)
Environment="CB_CONFIG=$CONFIG_DIR/cb-config.toml"
ExecStart=$PBS_EXEC_START
Restart=always
TimeoutStopSec=600
RestartSec=5
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

sudo mv "$PBS_SERVICE_FILE" /etc/systemd/system/commit-boost-pbs.service
sudo chmod 644 /etc/systemd/system/commit-boost-pbs.service
log_info "Created systemd service: commit-boost-pbs.service"

# Signer Module: handles validator key operations
log_info "Creating systemd service for Commit-Boost Signer..."
SIGNER_EXEC_START="$COMMIT_BOOST_DIR/commit-boost-signer"

SIGNER_SERVICE_FILE="$HOME/commit-boost-signer.service"
cat > "$SIGNER_SERVICE_FILE" << EOF
[Unit]
Description=Commit-Boost Signer
Wants=network-online.target
After=network-online.target

[Service]
User=$(whoami)
Environment="CB_CONFIG=$CONFIG_DIR/cb-config.toml"
ExecStart=$SIGNER_EXEC_START
Restart=always
TimeoutStopSec=600
RestartSec=5
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

sudo mv "$SIGNER_SERVICE_FILE" /etc/systemd/system/commit-boost-signer.service
sudo chmod 644 /etc/systemd/system/commit-boost-signer.service
log_info "Created systemd service: commit-boost-signer.service"

# Enable and start PBS (the MEV relay proxy - works immediately)
enable_and_start_systemd_service "commit-boost-pbs"

# Signer service is installed but NOT started by default.
# It requires validator key configuration in cb-config.toml first.
# Enable it after configuring [signer] section:
#   sudo systemctl enable --now commit-boost-signer
sudo systemctl daemon-reload 2>/dev/null || true
log_info "Signer service installed (disabled - configure validator keys in cb-config.toml first)"

# =============================================================================
# COMPLETION
# =============================================================================

log_installation_complete "Commit-Boost" "commit-boost-pbs" "$CONFIG_DIR/cb-config.toml" "$COMMIT_BOOST_DIR"

cat << EOF

=== Commit-Boost Setup Information ===

Commit-Boost ${LATEST_VERSION} has been installed:
1. PBS Module (MEV-Boost compatible) - Port $COMMIT_BOOST_PORT [RUNNING]
2. Signer Module - Port $COMMIT_BOOST_SIGNER_PORT [INSTALLED, NOT STARTED]
   (Requires validator key configuration - see cb-config.toml)
3. Metrics - Port $COMMIT_BOOST_METRICS_PORT+

Installation Directory: $COMMIT_BOOST_DIR
Configuration File: $CONFIG_DIR/cb-config.toml
Binaries:
  - commit-boost-pbs: $COMMIT_BOOST_DIR/commit-boost-pbs
  - commit-boost-signer: $COMMIT_BOOST_DIR/commit-boost-signer

Key Features:
- MEV-Boost relay compatibility (drop-in replacement)
- Modular architecture for commitment protocols
- Support for preconfirmations, inclusion lists
- Prometheus metrics and file logging
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

IMPORTANT: Commit-Boost vs MEV-Boost
Commit-Boost is an ALTERNATIVE to MEV-Boost, not an addition.
- If you install Commit-Boost, you should NOT run MEV-Boost
- They both serve the same purpose (connecting to MEV relays)
- Commit-Boost adds support for additional protocols beyond standard MEV

Next Steps:
1. Stop MEV-Boost if running: sudo systemctl stop mev
2. Update your consensus client to point to Commit-Boost:
   - Prysm: http-mev-relay: http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT
   - Teku: builder-endpoint: "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
   - Lighthouse: --builder http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT
   - Lodestar: builder.urls: ["http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"]
   - Nimbus: payload-builder-url = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
   - Grandine: builder_endpoint = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
3. Enable builder/MEV in your consensus client configuration
4. To enable signer (for preconfirmations/commitment protocols):
   a. Edit $CONFIG_DIR/cb-config.toml - uncomment [signer] section
   b. Configure your validator keys (Lighthouse/Prysm/Teku/Lodestar/Nimbus format)
   c. Start signer: sudo systemctl enable --now commit-boost-signer

Documentation: https://commit-boost.github.io/commit-boost-client/
Repository: https://github.com/Commit-Boost/commit-boost-client

EOF
