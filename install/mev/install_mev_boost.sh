#!/bin/bash

# MEV Boost Installation Script
# MEV Boost is a service that connects validators to MEV relays
# Uses pre-built binaries from GitHub releases (no build required)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

log_installation_start "MEV Boost"

# Check system requirements
check_system_requirements 8 500

# Setup firewall rules for MEV-Boost
setup_firewall_rules "$MEV_PORT"

# Create MEV Boost directory
MEV_BOOST_DIR="$HOME/mev-boost"
ensure_directory "$MEV_BOOST_DIR"

cd "$MEV_BOOST_DIR" || exit

# Resolve prebuilt release URL with fallbacks:
# 1) latest tag API
# 2) latest asset URL API
# 3) pinned stable fallback (for transient API/rate-limit failures in CI)
log_info "Fetching latest MEV-Boost release..."
LATEST_VERSION="$(get_latest_release "flashbots/mev-boost" || true)"
DOWNLOAD_URL=""
ARCHIVE_FILE=""

if [[ -n "$LATEST_VERSION" ]]; then
    log_info "Latest version: $LATEST_VERSION"
    VERSION_NUM="${LATEST_VERSION#v}"
    ARCHIVE_FILE="mev-boost_${VERSION_NUM}_linux_amd64.tar.gz"
    DOWNLOAD_URL="https://github.com/flashbots/mev-boost/releases/download/${LATEST_VERSION}/${ARCHIVE_FILE}"
else
    log_warn "Latest release tag lookup failed; trying latest asset URL lookup"
    DOWNLOAD_URL="$(get_github_release_asset_url "flashbots/mev-boost" "mev-boost_.*_linux_amd64\\.tar\\.gz" || true)"
    if [[ -n "$DOWNLOAD_URL" ]]; then
        ARCHIVE_FILE="${DOWNLOAD_URL##*/}"
        log_info "Resolved latest MEV-Boost asset URL: $ARCHIVE_FILE"
    fi
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
    FALLBACK_VERSION="${MEV_BOOST_FALLBACK_VERSION:-v1.12}"
    FALLBACK_VERSION_NUM="${FALLBACK_VERSION#v}"
    ARCHIVE_FILE="mev-boost_${FALLBACK_VERSION_NUM}_linux_amd64.tar.gz"
    DOWNLOAD_URL="https://github.com/flashbots/mev-boost/releases/download/${FALLBACK_VERSION}/${ARCHIVE_FILE}"
    log_warn "Using fallback MEV-Boost version: $FALLBACK_VERSION"
fi

log_info "Downloading MEV-Boost archive: ${ARCHIVE_FILE}..."
if ! download_file "$DOWNLOAD_URL" "$ARCHIVE_FILE"; then
    log_error "Failed to download MEV-Boost"
    exit 1
fi

log_info "Extracting MEV-Boost..."
tar -xzf "$ARCHIVE_FILE"
rm -f "$ARCHIVE_FILE"

# Verify binary exists (tarball contains: LICENSE, README.md, mev-boost)
if [[ ! -f "$MEV_BOOST_DIR/mev-boost" ]]; then
    log_error "mev-boost binary not found after extraction"
    exit 1
fi

chmod +x "$MEV_BOOST_DIR/mev-boost"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create systemd service
EXEC_START="$MEV_BOOST_DIR/mev-boost -mainnet -relay-check -min-bid $MIN_BID -relays $MEV_RELAYS -request-timeout-getheader $MEVGETHEADERT -request-timeout-getpayload $MEVGETPAYLOADT -request-timeout-regval $MEVREGVALT -addr $MEV_HOST:$MEV_PORT -loglevel info -json"

create_systemd_service "mev" "MEV Boost Service" "$EXEC_START" "$(whoami)" "always" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "mev"

# Patch deployed consensus client configs: the base configs disable the MEV builder
# by default.  Now that the relay is running, uncomment the relevant lines and
# restart any running consensus service so it picks up the builder endpoint.
patch_consensus_mev_builder() {
    local patched=0

    local prysm_beacon="$HOME/prysm/prysm_beacon_conf.yaml"
    local prysm_validator="$HOME/prysm/prysm_validator_conf.yaml"
    if [[ -f "$prysm_beacon" ]] && grep -q '^# http-mev-relay:' "$prysm_beacon"; then
        sed -i 's/^# \(http-mev-relay:.*\)$/\1/' "$prysm_beacon"
        log_info "Prysm beacon: enabled http-mev-relay in $prysm_beacon"
        patched=1
    fi
    if [[ -f "$prysm_validator" ]] && grep -q '^# enable-builder:' "$prysm_validator"; then
        sed -i 's/^# \(enable-builder:.*\)$/\1/' "$prysm_validator"
        log_info "Prysm validator: enabled enable-builder in $prysm_validator"
        patched=1
    fi

    local grandine_config="$HOME/grandine/grandine.toml"
    if [[ -f "$grandine_config" ]] && grep -q '^# builder_' "$grandine_config"; then
        sed -i 's/^# \(builder_boost_factor .*\)$/\1/; s/^# \(builder_endpoint .*\)$/\1/' "$grandine_config"
        log_info "Grandine: enabled builder settings in $grandine_config"
        patched=1
    fi

    if [[ "$patched" -eq 1 ]]; then
        log_info "MEV builder enabled in consensus config(s) — restarting affected services..."
        if systemctl is-active --quiet cl 2>/dev/null; then
            sudo systemctl restart cl
        fi
        if systemctl is-active --quiet validator 2>/dev/null; then
            sudo systemctl restart validator
        fi
    fi
}
patch_consensus_mev_builder

# Show completion information
log_installation_complete "MEV Boost" "mev" "" "$MEV_BOOST_DIR"
