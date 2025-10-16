#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 2
# This script should be run as the non-root user
# It will install:
# 1. Geth
# 2. Prysm
# 3. Flashbots mev boost builder
# 4. Nginx without SSL, exposing the geth RPC route. 
#    (You can run `service nginx stop` to disable this)
# Note: External ETH1 RPC calls expect SSL so you will have to 
#       manually run: `sudo su`
#       Followed by: 
#       `./install/ssl/install_acme_ssl.sh`  or 
#       `./install_certbot_ssl.sh` 
#       to get SSL certs and configure NGINX properly

source ./exports.sh
source ./lib/common_functions.sh

log_info "Starting system setup - Phase 2..."

# Check system compatibility first
if ! check_system_compatibility; then
    log_error "System compatibility check failed"
    exit 1
fi
log_info "This script will install Ethereum clients and services"

# Start syncing prysm and geth
# Geth takes a day
# prysm takes 3-5. few hrs w/ the checkpt
# Slightly faster via the screen cmds

# You may want to run a different cmd via screen for more flexibility and faster sync
# screen -d -m  geth --syncmode snap --http --http.addr 0.0.0.0 --cache=16384 --ipcdisable --maxpeers 500 --lightkdf --v5disc
# cd prysm
# screen -d -m ./prysm.sh beacon-chain --p2p-host-ip=$(curl -s v4.ident.me) --config-file=./prysm_conf_beacon_sync.yaml
#  ./prysm.sh beacon-chain --checkpoint-block=$PWD/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/genesis.ssz --config-file=$PWD/prysm_beacon_conf.yaml --p2p-host-ip=88.99.65.230
# Install snapd
log_info "Installing snapd..."
if ! sudo apt install -y snapd; then
    log_error "Failed to install snapd"
    exit 1
fi

# Install Ethereum clients (seamless installation)
log_info "Installing default Ethereum clients (Geth + Prysm + MEV Boost)..."
log_info "This provides a complete, production-ready Ethereum node setup"
log_info "For custom client selection, run: ./install/utils/quick_client_install.sh"

log_info "Installing Geth (Execution Client)..."
if ! ./install/execution/install_geth.sh; then
    log_error "Failed to install Geth"
    exit 1
fi

log_info "Installing Prysm (Consensus Client)..."
if ! ./install/consensus/install_prysm.sh; then
    log_error "Failed to install Prysm"
    exit 1
fi

log_info "Installing Flashbots MEV Boost..."
if ! ./install/mev/install_mev_boost.sh; then
    log_error "Failed to install Flashbots MEV Boost"
    exit 1
fi

log_info "All Ethereum clients installed successfully!"
log_info "Installed: Geth, Prysm, Flashbots MEV Boost"
show_log_location

# Display next steps
cat << EOF

=== Next Steps ===

To expose your own uncensored geth RPC proxy for use, install nginx with SSL:

1. Switch to super user: sudo su
2. Run one of the following SSL setup commands:
   - ./install/ssl/install_acme_ssl.sh (Preferred - uses acme.sh)
   - ./install/ssl/install_ssl_certbot.sh (uses certbot with manual DNS verification)

If you are new to NGINX, strongly recommend running only './install/web/install_nginx.sh' first 
and confirming it works without SSL, locally, then remotely via your domain name.

Next step is to start syncing via:
- sudo systemctl start eth1
- Or try: ./install/utils/start.sh

EOF
