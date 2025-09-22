#!/bin/bash
source ./exports.sh
source ./lib/common.sh

# Installs and sets up geth as a systemctl service according to :
# https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt update -y
sudo apt dist-upgrade -y
sudo apt install ethereum -y
sudo apt upgrade geth -y

ensure_jwt_secret

export GETH_CMD='/usr/bin/geth --cache='$GETH_CACHE' --syncmode snap 
--http --http.corsdomain "*" --http.vhosts=* --http.api="admin, eth, net, web3, engine" 
--ws --ws.origins "*" --ws.api="web3, eth, net, engine" 
--authrpc.jwtsecret='$HOME'/secrets/jwt.hex 
--authrpc.addr=127.0.0.1 --authrpc.port=8551 --authrpc.vhosts=* 
--miner.etherbase='$FEE_RECIPIENT' --miner.extradata='$GRAFITTI
'

create_systemd_service eth1 "geth execution client service" "$GETH_CMD"
