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
make erigon

cat > $HOME/erigon.yaml << EOF
chain : "mainnet"
http : true
http.api : ["admin","eth","debug","net","web3","engine"]
authrpc.jwtsecret: '$HOME/secrets/jwt.hex'
externalcl: true
snapshot: true
EOF

cp ./build/bin/erigon $HOME/


# overwrite the eth1 servicwe

cat > $HOME/eth1.service << EOF 
[Unit]
Description     = erigon execution client service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = $HOME/erigon --config $HOME/config.yaml
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

