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

# Download binaries — asset pattern: commit-boost-{component}-{version}-linux_x86-64.tar.gz
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

# Verify required binaries
for bin in commit-boost-pbs commit-boost-signer; do
    if [[ ! -f "$COMMIT_BOOST_DIR/$bin" ]]; then
        log_error "$bin binary not found after extraction"
        exit 1
    fi
    chmod +x "$bin"
done
[[ -f "commit-boost-cli" ]] && chmod +x commit-boost-cli

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
    if [[ -e "$SIGNER_KEYS" ]]; then
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

# Signer: start if client detected AND keys exist; otherwise just install the service file
if [[ "$SIGNER_READY" == "true" ]]; then
    enable_and_start_systemd_service "commit-boost-signer"
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
