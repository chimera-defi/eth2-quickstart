#!/bin/bash
source ./exports.sh
source ./lib/common_functions.sh

log_info "Starting Geth installation..."

# Installs and sets up geth as a systemctl service according to :
# https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client

# Check system requirements
check_system_requirements 16 2000

# Add Ethereum PPA and install
sudo add-apt-repository -y ppa:ethereum/ethereum
install_dependencies ethereum

export GETH_CMD='/usr/bin/geth --cache='$GETH_CACHE' --syncmode snap 
--http --http.corsdomain "*" --http.vhosts=* --http.api="admin, eth, net, web3, engine" 
--ws --ws.origins "*" --ws.api="web3, eth, net, engine" 
--authrpc.jwtsecret='$HOME'/secrets/jwt.hex 
--miner.etherbase='$FEE_RECIPIENT' --miner.extradata='$GRAFITTI


# Ensure JWT secret directory exists
ensure_directory "$HOME/secrets"

# Create systemd service using common function
create_systemd_service "eth1" "Geth Ethereum Execution Client" "$GETH_CMD" "$(whoami)" "on-failure" "600" "5" "300"

# Enable the service
enable_systemd_service "eth1"

log_info "Geth installation completed!"
log_info "To start Geth: sudo systemctl start eth1"
log_info "To check status: sudo systemctl status eth1"
log_info "To view logs: journalctl -fu eth1"
