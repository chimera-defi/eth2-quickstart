#!/bin/bash

# Install MEV-Boost service
# https://github.com/flashbots/mev-boost

source ./exports.sh
source ./common_functions.sh

log_info "Installing MEV-Boost service..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps
install_go

# Create MEV-Boost directory
MEV_BOOST_DIR="$HOME/mev-boost"
mkdir -p "$MEV_BOOST_DIR"

# Clone and build MEV-Boost
log_info "Building MEV-Boost from source..."
clone_and_build "https://github.com/flashbots/mev-boost.git" "mev-boost" "$MEV_BOOST_DIR" "make build" "stable"

# Create MEV-Boost command
MEV_BOOST_CMD="$MEV_BOOST_DIR/mev-boost -mainnet -relay-check -min-bid $MIN_BID -relays $MEV_RELAYS -request-timeout-getheader $MEVGETHEADERT -request-timeout-getpayload $MEVGETPAYLOADT -request-timeout-regval $MEVREGVALT"

# Create systemd service
create_systemd_service "mev" "MEV-Boost service" "$MEV_BOOST_CMD" "$(whoami)" "network-online.target" "network-online.target" "always" "5"

# Print installation summary
print_installation_summary "MEV-Boost" "mev"

log_info "MEV-Boost installation completed successfully!"
log_info "Configuration:"
log_info "  - Min bid: $MIN_BID ETH"
log_info "  - Relays: $MEV_RELAYS"
