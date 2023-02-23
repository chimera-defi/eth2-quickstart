#!/bin/bash
source ./exports.sh

# Installs and sets up geth as a systemctl service according to :
# https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt update -y
sudo apt dist-upgrade -y
sudo apt install ethereum -y
sudo apt upgrade geth -y

export GETH_CMD='/usr/bin/geth --cache='$GETH_CACHE' --syncmode snap 
--http --http.corsdomain "*" --http.vhosts=* --http.api="admin, eth, net, web3, engine" 
--ws --ws.origins "*" --ws.api="web3, eth, net, engine" 
--authrpc.jwtsecret='$HOME'/secrets/jwt.hex 
--miner.etherbase='$FEE_RECIPIENT' --miner.extradata='$GRAFITTI


cat > $HOME/eth1.service << EOF 
[Unit]
Description     = geth execution client service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = $(echo $GETH_CMD)
Restart         = on-failure
TimeoutStopSec  = 600
RestartSec      = 5
TimeoutSec      = 300

[Install]
WantedBy    = multi-user.target
EOF

sudo mv $HOME/eth1.service /etc/systemd/system/eth1.service
sudo chmod 644 /etc/systemd/system/eth1.service
sudo systemctl daemon-reload
sudo systemctl enable eth1
