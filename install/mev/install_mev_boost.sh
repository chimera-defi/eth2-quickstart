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

# Get latest release (pre-built binaries, same pattern as install_commit_boost.sh, besu.sh)
log_info "Fetching latest MEV-Boost release..."
LATEST_VERSION=$(get_latest_release "flashbots/mev-boost")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest MEV-Boost version from GitHub"
    exit 1
fi
log_info "Latest version: $LATEST_VERSION"

# Parse version for download URL (v1.9 -> 1.9, v1.11 -> 1.11)
VERSION_NUM="${LATEST_VERSION#v}"
DOWNLOAD_URL="https://github.com/flashbots/mev-boost/releases/download/${LATEST_VERSION}/mev-boost_${VERSION_NUM}_linux_amd64.tar.gz"
ARCHIVE_FILE="mev-boost_${VERSION_NUM}_linux_amd64.tar.gz"

log_info "Downloading MEV-Boost ${LATEST_VERSION}..."
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
