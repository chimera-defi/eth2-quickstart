#!/bin/bash

# Installs and sets up geth as a systemctl service according to :
# https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt update -y
sudo apt dist-upgrade -y
sudo apt install ethereum -y
sudo apt upgrade geth -y

# cmd=/usr/bin/geth --config $(echo $HOME)/geth/geth_conf_rpc.yaml --cache 4096 --http --http.addr "127.0.0.1" --http.corsdomain "*" --http.port "8545" --http.api "db, eth, net, web3, personal" --ws --ws.port 8546 --ws.addr "127.0.0.1" --ws.origins "*" --ws.api "web3, eth" --maxpeers=100
cat > $HOME/eth1.service << EOF 
[Unit]
Description     = geth execution client service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = /usr/bin/geth --cache 4096 --syncmode snap --http --http.addr "127.0.0.1" --http.corsdomain "*" --http.port "8545" --http.api "db, eth, net, web3, personal, engine,admin" --ws --ws.port 8546 --ws.addr "127.0.0.1" --ws.origins "*" --ws.api "web3, eth" --maxpeers=100 --authrpc.vhosts="localhost" --authrpc.jwtsecret=$(echo $HOME)/secrets/jwt.hex --http.vhosts=*
Restart         = on-failure
RestartSec      = 3
TimeoutSec      = 300

[Install]
WantedBy    = multi-user.target
EOF

sudo mv $HOME/eth1.service /etc/systemd/system/eth1.service
sudo chmod 644 /etc/systemd/system/eth1.service
sudo systemctl daemon-reload
sudo systemctl enable eth1
