#!/bin/bash

# Start syncing prysm and geth
# Geth takes a day
# prysm takes 3-5
# Slightly faster via the screen cmds

# You may want to run a different cmd via screen for more flexibility and faster sync
# screen -d -m  geth --syncmode snap --http --http.addr 0.0.0.0 --cache=16384 --ipcdisable --maxpeers 500 --lightkdf --v5disc
# cd prysm
# screen -d -m ./prysm.sh beacon-chain --p2p-host-ip=$(curl -s v4.ident.me) --config-file=./prysm_conf_beacon_sync.yaml

./install_geth.sh
./install_prysm.sh
./install_nginx.sh