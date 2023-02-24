#!/bin/bash

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
#       `./install_acme_ssl.sh`  or 
#       `./install_certbot_ssl.sh` 
#       to get SSL certs and configure NGINX properly


# Start syncing prysm and geth
# Geth takes a day
# prysm takes 3-5. few hrs w/ the checkpt
# Slightly faster via the screen cmds

# You may want to run a different cmd via screen for more flexibility and faster sync
# screen -d -m  geth --syncmode snap --http --http.addr 0.0.0.0 --cache=16384 --ipcdisable --maxpeers 500 --lightkdf --v5disc
# cd prysm
# screen -d -m ./prysm.sh beacon-chain --p2p-host-ip=$(curl -s v4.ident.me) --config-file=./prysm_conf_beacon_sync.yaml
#  ./prysm.sh beacon-chain --checkpoint-block=$PWD/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/genesis.ssz --config-file=$PWD/prysm_beacon_conf.yaml --p2p-host-ip=88.99.65.230
source ./exports.sh

./install_geth.sh
./install_prysm.sh
./install_mev_boost.sh

echo "Installed Geth"
echo "Installed Prysm"
echo "Installed Flashbots MEV boost"
echo "Done"
echo

echo "To expose your own uncensored geth rpc proxy for use, install nginx w/ SSL"

echo "To configure SSL for NGINX, run the following: "
echo "A. ' sudo su '  - to switch to super user "

echo "B. Run 1 of the 2 following cmds"
echo "1. '  ./install_acme_ssl.sh ' - Preferred - use acme.sh to set-up letsencrypt SSL cert"
echo "2. '  ./install_ssl_certbot.sh '  - use certbot and manual DNS verification to set-up letsencrypt SSL cert"

echo 
echo "If you are new to NGINX, strongly recommend running only ' ./install_nginx.sh ' first and confirming it works without SSL, locally, then remotely via your domain name using the curl cmd in the readme for geth rpc on step 5"

echo "Next step is to start syncing via 'systemctl start prysm'"
