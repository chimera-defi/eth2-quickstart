#!/bin/bash

source ./exports.sh

# Setup erigon devel 
# https://github.com/ledgerwatch/erigon
#

# erigon uses some extra ports
sudo ufw allow 30303
sudo ufw allow 30304
sudo ufw allow 42069 # lmao - Snap sync (Bittorent)
sudo ufw allow 4000/udp # sentinel 
sudo ufw allow 4001/udp

# stable
# git clone --branch stable --single-branch https://github.com/ledgerwatch/erigon.git
# devrel
git clone --recurse-submodules https://github.com/ledgerwatch/erigon.git
cd erigon
git pull
make erigon

rm -rf $HOME/erigon/*
mkdir $HOME/erigon

cat > $HOME/erigon/config.yaml << EOF
chain : "mainnet"
http : true
http.api : ["admin","eth","debug","net","web3","engine"]
authrpc.jwtsecret: '$HOME/secrets/jwt.hex'
externalcl: true
snapshots: true
nat: any
rpc.batch.limit: 1000
torrent.download.rate: 512mb
prune: hrtc
EOF

cp ./build/bin/erigon $HOME/erigon/


# overwrite the eth1 servicwe

cat > $HOME/eth1.service << EOF 
[Unit]
Description     = erigon execution client service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = $HOME/erigon/erigon --config $HOME/erigon/config.yaml --externalcl
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
