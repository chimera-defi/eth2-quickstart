#!/bin/bash

# Commit-Boost Installation Script
# Drop-in replacement for MEV-Boost with modular architecture.
# Speaks the same BuilderAPI on the same port — consensus client configs work unchanged.
# Ref: https://commit-boost.github.io/commit-boost-client/

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

get_script_directories

log_installation_start "Commit-Boost"

check_system_requirements 8 1000

# Stop MEV-Boost if running (mutually exclusive)
if systemctl is-active --quiet mev 2>/dev/null; then
    log_warn "Stopping MEV-Boost (mutually exclusive with Commit-Boost)"
    sudo systemctl stop mev
    sudo systemctl disable mev 2>/dev/null || true
fi

setup_firewall_rules "$COMMIT_BOOST_PORT"

COMMIT_BOOST_DIR="$HOME/commit-boost"
ensure_directory "$COMMIT_BOOST_DIR"
cd "$COMMIT_BOOST_DIR" || exit

# =============================================================================
# DOWNLOAD
# =============================================================================

log_info "Fetching latest Commit-Boost release..."
LATEST_VERSION=$(get_latest_release "Commit-Boost/commit-boost-client")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Commit-Boost version from GitHub"
    exit 1
fi
log_info "Latest version: $LATEST_VERSION"

# Asset pattern: commit-boost-{component}-{version}-linux_x86-64.tar.gz
# Each tarball contains a single binary named commit-boost-{component}
for component in pbs signer cli; do
    url="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-${component}-${LATEST_VERSION}-linux_x86-64.tar.gz"
    archive="commit-boost-${component}.tar.gz"
    log_info "Downloading commit-boost-${component}..."
    if ! download_file "$url" "$archive"; then
        if [[ "$component" == "cli" ]]; then
            log_warn "CLI download failed (optional, continuing)"
            continue
        fi
        log_error "Failed to download commit-boost-${component}"
        exit 1
    fi
    tar -xzf "$archive"
    rm -f "$archive"
done

for bin in commit-boost-pbs commit-boost-signer; do
    if [[ ! -f "$COMMIT_BOOST_DIR/$bin" ]]; then
        log_error "$bin binary not found after extraction"
        exit 1
    fi
    chmod +x "$bin"
done
[[ -f "commit-boost-cli" ]] && chmod +x commit-boost-cli

ensure_jwt_secret "$HOME/secrets/jwt.hex"

# =============================================================================
# CONFIGURATION
# =============================================================================

CONFIG_DIR="$COMMIT_BOOST_DIR/config"
ensure_directory "$CONFIG_DIR"
ensure_directory "$COMMIT_BOOST_DIR/logs"

# Build [[relays]] TOML from MEV_RELAYS (same relays used by MEV-Boost)
RELAY_TOML=""
IFS=',' read -ra RELAY_ARRAY <<< "$MEV_RELAYS"
for relay in "${RELAY_ARRAY[@]}"; do
    relay="$(echo "$relay" | xargs)"
    [[ -z "$relay" ]] && continue
    RELAY_TOML+=$'\n'"[[relays]]"$'\n'"url = \"$relay\""$'\n'
done

cat > "$CONFIG_DIR/cb-config.toml" << EOF
# Commit-Boost Configuration — generated $(date +%Y-%m-%d)
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
# Signer module — uncomment after configuring your validator keys.
# Required for commitment protocols (preconfirmations, etc.) and for ETHGas.
# Supported keystore formats: lighthouse, prysm, teku, lodestar, nimbus
# See: https://commit-boost.github.io/commit-boost-client/get_started/configuration/#signer-module
#
# [signer]
# port = $COMMIT_BOOST_SIGNER_PORT
# host = "$COMMIT_BOOST_HOST"
# [signer.local.loader]
# format = "lighthouse"
# keys_path = "/path/to/validator/keys"
# secrets_path = "/path/to/validator/secrets"

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

log_info "Configuration: $CONFIG_DIR/cb-config.toml"

# =============================================================================
# SYSTEMD SERVICES
# =============================================================================
# CB_CONFIG env var is required for binary mode (not --config flag)

for svc in commit-boost-pbs commit-boost-signer; do
    desc="Commit-Boost PBS (MEV Sidecar)"
    [[ "$svc" == "commit-boost-signer" ]] && desc="Commit-Boost Signer"

    tmpfile="$HOME/${svc}.service"
    cat > "$tmpfile" << EOF
[Unit]
Description=$desc
Wants=network-online.target
After=network-online.target

[Service]
User=$(whoami)
Environment="CB_CONFIG=$CONFIG_DIR/cb-config.toml"
ExecStart=$COMMIT_BOOST_DIR/$svc
Restart=always
TimeoutStopSec=600
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    sudo mv "$tmpfile" "/etc/systemd/system/${svc}.service"
    sudo chmod 644 "/etc/systemd/system/${svc}.service"
done

# PBS: start immediately — drop-in replacement for MEV-Boost
enable_and_start_systemd_service "commit-boost-pbs"

# Signer: install only — needs validator key config first
sudo systemctl daemon-reload 2>/dev/null || true

# =============================================================================
# COMPLETION
# =============================================================================

log_installation_complete "Commit-Boost" "commit-boost-pbs" "$CONFIG_DIR/cb-config.toml" "$COMMIT_BOOST_DIR"

echo ""
log_info "Commit-Boost ${LATEST_VERSION} is running on $COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
log_info "Your consensus client already points to this port via \$MEV_HOST:\$MEV_PORT — no config changes needed."
echo ""
log_warn "Signer is installed but NOT started (needs validator keys)."
log_warn "To enable: edit $CONFIG_DIR/cb-config.toml, uncomment [signer], then:"
log_warn "  sudo systemctl enable --now commit-boost-signer"
