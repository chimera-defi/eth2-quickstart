#!/bin/bash

# Prysm Consensus Client Installation Script
# Language: Go
# Prysm is a Go-based Ethereum consensus client developed by Prysmatic Labs
# Usage: ./prysm.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

CLIENT_GRAFFITI="$(printf '%s' "Prysm ${GRAFITTI}" | head -c 32)"

log_installation_start "Prysm"


# Check system requirements
check_system_requirements 16 1000


# Setup firewall rules for Prysm
setup_firewall_rules 13000 12000 5051

# Create Prysm directory
PRYSM_DIR="$HOME/prysm"
ensure_directory "$PRYSM_DIR"

cd "$PRYSM_DIR" || exit

# Download Prysm
log_info "Downloading Prysm..."
if ! download_file "https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh" "prysm.sh"; then
    log_error "Failed to download Prysm"
    exit 1
fi

chmod +x prysm.sh

# Verify download
if [[ ! -f "prysm.sh" || ! -x "prysm.sh" ]]; then
    log_error "Prysm script not found or not executable"
    exit 1
fi

ensure_directory "$HOME/secrets"
chmod 700 "$HOME/secrets"
if [[ ! -s "$HOME/secrets/jwt.hex" ]]; then
    log_info "Generating JWT secret..."
    ./prysm.sh beacon-chain generate-auth-secret
    mv ./jwt.hex "$HOME/secrets/"
else
    log_info "JWT secret already exists"
fi

# Create temporary directory for custom configuration
create_temp_config_dir

# Create custom beacon node configuration variables
# Note: graffiti is a validator-only flag, not beacon
cat > ./tmp/prysm_beacon_custom.yaml << EOF
suggested-fee-recipient: $FEE_RECIPIENT
p2p-host-ip: $(detect_external_ip)
p2p-max-peers: $MAX_PEERS
checkpoint-sync-url: $PRYSM_CPURL
genesis-beacon-api-url: $PRYSM_CPURL
jwt-secret: $HOME/secrets/jwt.hex
EOF

# Create custom validator configuration variables
cat > ./tmp/prysm_validator_custom.yaml << EOF
graffiti: $CLIENT_GRAFFITI
suggested-fee-recipient: $FEE_RECIPIENT
wallet-password-file: $HOME/secrets/pass.txt
EOF

# Merge base configurations with custom settings
merge_client_config "Prysm" "beacon" "$PROJECT_ROOT/configs/prysm/prysm_beacon_conf.yaml" "./tmp/prysm_beacon_custom.yaml" "$PRYSM_DIR/prysm_beacon_conf.yaml"
merge_client_config "Prysm" "validator" "$PROJECT_ROOT/configs/prysm/prysm_validator_conf.yaml" "./tmp/prysm_validator_custom.yaml" "$PRYSM_DIR/prysm_validator_conf.yaml"

# Clean up temporary files
rm -rf ./tmp/

# Create systemd service for beacon node
BEACON_EXEC_START="$PRYSM_DIR/prysm.sh beacon-chain --config-file=$PRYSM_DIR/prysm_beacon_conf.yaml"

create_systemd_service "cl" "Prysm Ethereum Consensus Client (Beacon Node)" "$BEACON_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300" "network-online.target eth1.service" "network-online.target eth1.service"

# Resolve the prysm version to pin. Prefer the latest published release from the
# GitHub API (avoids the prysmaticlabs.com live version check, which 403s on
# rate-limited hosts); fall back to the newest locally cached binary only if the
# API is unreachable. Pinning to newest-cached alone silently goes stale — a
# stale v7.1.5 pin once stalled a besu sync ~30h until manually bumped to v7.1.6.
PRYSM_PINNED="$(get_latest_release "prysmaticlabs/prysm" 2>/dev/null || true)"
# get_latest_release() prints diagnostics to stdout when the GitHub API is
# rate-limited/unparseable (fresh CI containers); those would otherwise be
# captured above as a bogus "version". Only accept a real vX.Y tag — anything
# else falls through to the cached-binary fallback / no-pin.
if [[ ! "${PRYSM_PINNED:-}" =~ ^v[0-9]+\.[0-9]+ ]]; then
  PRYSM_PINNED=""
fi
if [[ -z "${PRYSM_PINNED:-}" && -d "$PRYSM_DIR/dist" ]]; then
  PRYSM_PINNED="$(find "$PRYSM_DIR/dist/" -maxdepth 1 -name 'beacon-chain-v*-linux-amd64' ! -name '*.sha256' ! -name '*.sig' 2>/dev/null | sed 's|.*/beacon-chain-||; s|-linux-amd64||' | sort -V | tail -1 || true)"
  [[ -n "${PRYSM_PINNED:-}" ]] && log_warn "prysm GitHub release lookup failed; falling back to newest cached binary $PRYSM_PINNED"
fi
if [[ -n "${PRYSM_PINNED:-}" ]]; then
  sudo sed -i "/^\[Service\]/a Environment=\"USE_PRYSM_VERSION=${PRYSM_PINNED}\"" /etc/systemd/system/cl.service
  log_info "Pinned prysm beacon to $PRYSM_PINNED (bypasses live version check)"
fi

# Create systemd service for validator
VALIDATOR_EXEC_START="$PRYSM_DIR/prysm.sh validator --config-file=$PRYSM_DIR/prysm_validator_conf.yaml"

create_systemd_service "validator" "Prysm Ethereum Validator Client" "$VALIDATOR_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300" "network-online.target cl.service" "network-online.target cl.service"

if [[ -n "${PRYSM_PINNED:-}" ]]; then
  sudo sed -i "/^\[Service\]/a Environment=\"USE_PRYSM_VERSION=${PRYSM_PINNED}\"" /etc/systemd/system/validator.service
  log_info "Pinned prysm validator to $PRYSM_PINNED (bypasses live version check)"
fi

enable_and_start_systemd_service "cl"
enable_and_start_systemd_service "validator"

# Show completion information
log_installation_complete "Prysm" "cl"

# Display setup information
display_client_setup_info "Prysm" "cl" "validator" "Prysm Beacon Node" "Prysm Validator Client"
cat << EOF

Useful commands:
- Check Prysm version: $PRYSM_DIR/prysm.sh beacon-chain --version
- Import validator keys: $PRYSM_DIR/prysm.sh validator accounts import --keys-dir=/path/to/keys

EOF
