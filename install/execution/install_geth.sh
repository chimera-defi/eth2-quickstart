#!/bin/bash

# Geth Installation Script
# Installs and configures Geth Ethereum execution client
# Usage: ./install_geth.sh
# Requirements: Ubuntu 20.04+, 16GB+ RAM, 2TB+ storage

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting Geth installation..."


# Installs and sets up geth as a systemctl service according to :
# https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client


# Check system requirements
check_system_requirements 16 2000

# Setup firewall rules for Geth
setup_firewall_rules 30303 8545 8546 8551

# Add Ethereum PPA and install
log_info "Adding Ethereum PPA repository..."
if ! add_ppa_repository "ppa:ethereum/ethereum"; then
    log_error "Failed to add Ethereum PPA repository"
    exit 1
fi

# Dependencies are installed centrally via install_dependencies.sh

export GETH_CMD='/usr/bin/geth --cache='$GETH_CACHE' --syncmode snap 
--http --http.addr '$LH' --http.corsdomain "*" --http.vhosts=* --http.api="admin, eth, net, web3, engine" 
--ws --ws.addr '$LH' --ws.origins "*" --ws.api="web3, eth, net, engine" 
--authrpc.addr '$LH' --authrpc.port $ENGINE_PORT --authrpc.jwtsecret='$HOME'/secrets/jwt.hex 
--miner.etherbase='$FEE_RECIPIENT' --miner.extradata='$GRAFITTI' 
--maxpeers 50 --txpool.globalslots 10000 --txpool.globalqueue 5000 
--metrics --metrics.addr '$LH' --metrics.port $METRICS_PORT'


# Ensure JWT secret directory exists
ensure_directory "$HOME/secrets"

# Create systemd service using common function
create_systemd_service "eth1" "Geth Ethereum Execution Client" "$GETH_CMD" "$(whoami)" "on-failure" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "eth1"

# Show completion information
show_installation_complete "Geth" "eth1" "" "$HOME"

log_info "Geth installation completed!"
log_info "To check status: sudo systemctl status eth1"
log_info "To view logs: journalctl -fu eth1"
