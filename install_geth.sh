#!/bin/bash

# Install Geth Ethereum execution client
# https://geth.ethereum.org/

source ./exports.sh
source ./common_functions.sh

log_info "Installing Geth execution client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps

# Add Ethereum repository and install Geth
log_info "Installing Geth from Ethereum repository..."
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt update -y
sudo apt install -y ethereum
sudo apt upgrade -y geth

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Geth command
GETH_CMD="/usr/bin/geth --cache=$GETH_CACHE --syncmode snap --http --http.corsdomain \"*\" --http.vhosts=* --http.api=\"admin,eth,net,web3,engine\" --ws --ws.origins \"*\" --ws.api=\"web3,eth,net,engine\" --authrpc.jwtsecret=$HOME/secrets/jwt.hex --miner.etherbase=$FEE_RECIPIENT --miner.extradata=$GRAFITTI"

# Create systemd service
create_systemd_service "eth1" "Geth execution client service" "$GETH_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "30303" "8545" "8546"

# Print installation summary
print_installation_summary "Geth" "eth1"

log_info "Geth installation completed successfully!"
