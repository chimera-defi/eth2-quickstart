#!/bin/bash
source ./exports.sh

mkdir ~/lighthouse && cd ~/lighthouse 
curl -LO https://github.com/sigp/lighthouse/releases/download/v4.5.0/lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz
tar -xvf lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz

# jwt => $HOME/.local/share/reth/
CLCMD="RUST_LOG=info /home/eth/lighthouse/lighthouse bn \
    --checkpoint-sync-url https://mainnet.checkpoint.sigp.io \
    --execution-endpoint http://localhost:8551 \
    --execution-jwt $HOME/.local/share/reth/mainnet/jwt.hex \
    --disable-deposit-contract-sync"

cat > $HOME/cl.service << EOF 
# The eth2 beacon chain service (part of systemd)
# file: /etc/systemd/system/cl.service 

[Unit]
Description     = eth2 beacon chain service
Wants           = network-online.target
After           = network-online.target 

[Service]
Type            = simple
User            = $(whoami)
ExecStart       = $(echo $CMD)
Restart         = on-failure
TimeoutStopSec  = 6000
RestartSec      = 10
TimeoutSec      = 3000

[Install]
WantedBy    = multi-user.target
EOF

sudo mv $HOME/cl.service /etc/systemd/system/cl.service
sudo chmod 644 /etc/systemd/system/cl.service

sudo systemctl daemon-reload
sudo systemctl enable cl
sudo systemctl stop cl
sudo systemctl start cl
sudo systemctl status cl
