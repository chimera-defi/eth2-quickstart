#!/bin/bash

# Commit-Boost Installation Script
# Drop-in replacement for MEV-Boost with modular architecture.
# Speaks the same BuilderAPI on the same port — consensus client configs work unchanged.
# Auto-detects installed consensus client and configures signer with correct key paths.
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

# Get latest release
log_info "Fetching latest Commit-Boost release..."
LATEST_VERSION=$(get_latest_release "Commit-Boost/commit-boost-client")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Commit-Boost version from GitHub"
    exit 1
fi
log_info "Latest version: $LATEST_VERSION"

# Detect architecture used by upstream release artifacts
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        COMMIT_BOOST_ARCH="linux_x86-64"
        ;;
    aarch64|arm64)
        COMMIT_BOOST_ARCH="linux_arm64"
        ;;
    *)
        log_error "Unsupported architecture for Commit-Boost prebuilt binaries: $ARCH"
        log_error "Supported architectures: x86_64, arm64"
        exit 1
        ;;
esac
log_info "Using Commit-Boost artifact architecture: $COMMIT_BOOST_ARCH"

# Download Commit-Boost PBS binary
log_info "Downloading Commit-Boost PBS binary..."
PBS_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-pbs-${LATEST_VERSION}-${COMMIT_BOOST_ARCH}.tar.gz"
if ! download_file "$PBS_URL" "commit-boost-pbs.tar.gz"; then
    log_error "Failed to download Commit-Boost PBS binary"
    exit 1
fi

# Download Commit-Boost Signer binary
log_info "Downloading Commit-Boost Signer binary..."
SIGNER_URL="https://github.com/Commit-Boost/commit-boost-client/releases/download/${LATEST_VERSION}/commit-boost-signer-${LATEST_VERSION}-${COMMIT_BOOST_ARCH}.tar.gz"
if ! download_file "$SIGNER_URL" "commit-boost-signer.tar.gz"; then
    log_error "Failed to download Commit-Boost Signer binary"
    exit 1
fi

# Extract binaries from tarballs
log_info "Extracting Commit-Boost binaries..."
tar -xzf commit-boost-pbs.tar.gz
tar -xzf commit-boost-signer.tar.gz
rm -f commit-boost-pbs.tar.gz commit-boost-signer.tar.gz
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

ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Detect consensus client and validator key paths for signer auto-configuration.
# Checks the cl.service ExecStart to determine which client is installed, then
# maps to the correct Commit-Boost keystore format and paths.
detect_signer_config() {
    local cl_exec=""
    if [[ -f /etc/systemd/system/cl.service ]]; then
        cl_exec=$(grep '^ExecStart=' /etc/systemd/system/cl.service | sed 's/^ExecStart=//' || true)
    fi

    local format="" keys_path="" secrets_path=""

    if echo "$cl_exec" | grep -q "prysm" || [[ -d "$HOME/prysm" ]]; then
        format="prysm"
        keys_path="$HOME/.eth2validators/prysm-wallet-v2/direct/accounts/all-accounts.keystore.json"
        secrets_path="$HOME/secrets/pass.txt"
    elif echo "$cl_exec" | grep -q "lighthouse" || [[ -d "$HOME/lighthouse" ]]; then
        format="lighthouse"
        keys_path="$HOME/.lighthouse/mainnet/validators"
        secrets_path="$HOME/.lighthouse/mainnet/secrets"
    elif echo "$cl_exec" | grep -q "teku" || [[ -d "$HOME/teku" ]]; then
        format="teku"
        keys_path="$HOME/.local/share/teku/validator/keys"
        secrets_path="$HOME/.local/share/teku/validator/passwords"
    elif echo "$cl_exec" | grep -q "nimbus" || [[ -d "$HOME/nimbus" ]]; then
        format="nimbus"
        keys_path="$HOME/.local/share/nimbus/validators"
        secrets_path="$HOME/.local/share/nimbus/validators/secrets"
    elif echo "$cl_exec" | grep -q "lodestar" || [[ -d "$HOME/lodestar" ]]; then
        format="lodestar"
        keys_path="$HOME/.local/share/lodestar/validators/keystores"
        secrets_path="$HOME/.local/share/lodestar/validators/secrets"
    elif echo "$cl_exec" | grep -q "grandine" || [[ -d "$HOME/grandine" ]]; then
        format="lighthouse"
        keys_path="$HOME/.local/share/grandine/validators"
        secrets_path="$HOME/.local/share/grandine/validators/secrets"
    fi

    if [[ -n "$format" ]]; then
        echo "$format|$keys_path|$secrets_path"
    fi
}

SIGNER_DETECTED=$(detect_signer_config)
SIGNER_FORMAT="" SIGNER_KEYS="" SIGNER_SECRETS="" SIGNER_READY=false
if [[ -n "$SIGNER_DETECTED" ]]; then
    IFS='|' read -r SIGNER_FORMAT SIGNER_KEYS SIGNER_SECRETS <<< "$SIGNER_DETECTED"
    log_info "Detected consensus client: $SIGNER_FORMAT"
    log_info "Validator keys path: $SIGNER_KEYS"
    # For file-based keystores (prysm: single keystore file), check file existence.
    # For directory-based keystores (lighthouse, teku, lodestar, nimbus), check for
    # actual *.json keystore files — the directory is created by the VC at startup
    # even when no keys have been imported, so -e on a directory gives a false positive.
    if [[ -f "$SIGNER_KEYS" ]] || { [[ -d "$SIGNER_KEYS" ]] && find "$SIGNER_KEYS" -name "*.json" -maxdepth 3 2>/dev/null | grep -q .; }; then
        SIGNER_READY=true
        log_info "Validator keys found — signer will be auto-configured"
    else
        log_warn "Validator keys not yet imported at $SIGNER_KEYS"
        log_warn "Signer is pre-configured but will start after you import keys"
    fi
else
    log_warn "No consensus client detected — signer config requires manual setup"
fi

# Generate configuration
CONFIG_DIR="$COMMIT_BOOST_DIR/config"
ensure_directory "$CONFIG_DIR"
ensure_directory "$COMMIT_BOOST_DIR/logs"

# relay_check = true — verify relays are live before validators connect (no skip in Docker)
RELAY_CHECK="true"

RELAY_TOML=""
IFS=',' read -ra RELAY_ARRAY <<< "$MEV_RELAYS"
for relay in "${RELAY_ARRAY[@]}"; do
    relay="$(echo "$relay" | xargs)"
    [[ -z "$relay" ]] && continue
    RELAY_TOML+=$'\n'"[[relays]]"$'\n'"url = \"$relay\""$'\n'
done

# Build signer TOML block — active if client detected, commented-out otherwise
SIGNER_TOML=""
if [[ -n "$SIGNER_FORMAT" ]]; then
    SIGNER_TOML="
[signer]
port = $COMMIT_BOOST_SIGNER_PORT
host = \"$COMMIT_BOOST_HOST\"

[signer.local.loader]
format = \"$SIGNER_FORMAT\"
keys_path = \"$SIGNER_KEYS\"
secrets_path = \"$SIGNER_SECRETS\"
"
else
    SIGNER_TOML="
# Signer module — configure after installing a consensus client and importing validator keys.
# Supported keystore formats: lighthouse, prysm, teku, lodestar, nimbus
# See: https://commit-boost.github.io/commit-boost-client/get_started/configuration/#signer-module
#
# [signer]
# port = $COMMIT_BOOST_SIGNER_PORT
# host = \"$COMMIT_BOOST_HOST\"
# [signer.local.loader]
# format = \"lighthouse\"
# keys_path = \"/path/to/validator/keys\"
# secrets_path = \"/path/to/validator/secrets\"
"
fi

cat > "$CONFIG_DIR/cb-config.toml" << EOF
# Commit-Boost Configuration — generated $(date +%Y-%m-%d)
# Docs: https://commit-boost.github.io/commit-boost-client/get_started/configuration/
# Schema: chain, [pbs], [[relays]], [signer], [metrics], [logs.*]

chain = "Mainnet"

[pbs]
port = $COMMIT_BOOST_PORT
host = "$COMMIT_BOOST_HOST"
relay_check = $RELAY_CHECK
timeout_get_header_ms = $MEVGETHEADERT
timeout_get_payload_ms = $MEVGETPAYLOADT
timeout_register_validator_ms = $MEVREGVALT
min_bid_eth = $MIN_BID
late_in_slot_time_ms = 2000
skip_sigverify = false
${RELAY_TOML}${SIGNER_TOML}
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

# Create systemd services (CB_CONFIG env var required for binary mode)
PBS_EXEC_START="$COMMIT_BOOST_DIR/commit-boost-pbs"
create_systemd_service "commit-boost-pbs" "Commit-Boost PBS (MEV Sidecar)" "$PBS_EXEC_START" "$(whoami)" "always" "600" "5" "300"
sudo sed -i '/^\[Service\]/a Environment="CB_CONFIG='"$CONFIG_DIR"'/cb-config.toml"' /etc/systemd/system/commit-boost-pbs.service

SIGNER_EXEC_START="$COMMIT_BOOST_DIR/commit-boost-signer"
create_systemd_service "commit-boost-signer" "Commit-Boost Signer" "$SIGNER_EXEC_START" "$(whoami)" "always" "600" "5" "300"
sudo sed -i '/^\[Service\]/a Environment="CB_CONFIG='"$CONFIG_DIR"'/cb-config.toml"' /etc/systemd/system/commit-boost-signer.service

# PBS: start immediately (drop-in replacement for MEV-Boost)
enable_and_start_systemd_service "commit-boost-pbs"

# Signer: start if client detected AND keys exist. In CI/E2E lighthouse+commit-boost, run_2 creates
# dummy keys before this script runs, so SIGNER_READY is typically true here.
if [[ "$SIGNER_READY" == "true" ]]; then
    enable_and_start_systemd_service "commit-boost-signer"
elif [[ "${CI_E2E:-false}" == "true" ]]; then
    enable_systemd_service "commit-boost-signer"  # Enable only; ci_test_e2e adds keys then starts
else
    sudo systemctl daemon-reload 2>/dev/null || true
fi

# Show completion information
log_installation_complete "Commit-Boost" "commit-boost-pbs" "$CONFIG_DIR/cb-config.toml" "$COMMIT_BOOST_DIR"

echo ""
log_info "Commit-Boost ${LATEST_VERSION} is running on $COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
log_info "Your consensus client already points here via \$MEV_HOST:\$MEV_PORT — no config changes needed."

if [[ "$SIGNER_READY" == "true" ]]; then
    log_info "Signer auto-configured for $SIGNER_FORMAT and started."
elif [[ "${CI_E2E:-false}" == "true" ]]; then
    log_info "Signer enabled (CI E2E: keys added by ci_test_e2e, then started)."
elif [[ -n "$SIGNER_FORMAT" ]]; then
    echo ""
    log_warn "Signer pre-configured for $SIGNER_FORMAT but NOT started (keys not found at $SIGNER_KEYS)."
    log_warn "After importing validator keys, start signer with:"
    log_warn "  sudo systemctl enable --now commit-boost-signer"
else
    echo ""
    log_warn "Signer requires manual configuration (no consensus client detected)."
    log_warn "Edit $CONFIG_DIR/cb-config.toml, add [signer] section, then:"
    log_warn "  sudo systemctl enable --now commit-boost-signer"
fi
