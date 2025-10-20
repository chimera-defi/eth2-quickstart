#!/bin/bash


# MEV Boost Installation Script
# MEV Boost is a service that connects validators to MEV relays

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting MEV Boost installation..."


# Check system requirements
check_system_requirements 8 500

# Dependencies are installed centrally via install_dependencies.sh
# Go and build tools are already available

# Create MEV Boost directory
MEV_BOOST_DIR="$HOME/mev-boost"
rm -rf "$MEV_BOOST_DIR"
ensure_directory "$MEV_BOOST_DIR"

cd "$MEV_BOOST_DIR" || exit

# Clone and build MEV Boost
log_info "Cloning MEV Boost repository..."
if ! git clone https://github.com/flashbots/mev-boost .; then
    log_error "Failed to clone MEV Boost repository"
    exit 1
fi

git checkout v1.9

log_info "Building MEV Boost..."
if ! make build; then
    log_error "Failed to build MEV Boost"
    exit 1
fi

# Create systemd service
EXEC_START="$MEV_BOOST_DIR/mev-boost -mainnet -relay-check -min-bid $MIN_BID -relays $MEV_RELAYS -request-timeout-getheader $MEVGETHEADERT -request-timeout-getpayload $MEVGETPAYLOADT -request-timeout-regval $MEVREGVALT -addr $MEV_HOST:$MEV_PORT -loglevel info -json"

create_systemd_service "mev" "MEV Boost Service" "$EXEC_START" "$(whoami)" "always" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "mev"

# Show completion information
show_installation_complete "MEV Boost" "mev" "" "$MEV_BOOST_DIR"
