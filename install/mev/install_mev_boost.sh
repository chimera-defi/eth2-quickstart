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

# Show completion information
log_installation_complete "MEV Boost" "mev" "" "$MEV_BOOST_DIR"
