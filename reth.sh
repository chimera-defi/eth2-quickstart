#!/bin/bash

source ./exports.sh

# Setup  reth
# https://paradigmxyz.github.io/reth/installation/source.html
#

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

sudo apt-get install libclang-dev pkg-config build-essential cargo -y

# erigon uses some extra ports - we open these for reth too to be safe? 
sudo ufw allow 30303
sudo ufw allow 30304
sudo ufw allow 42069 # Snap sync (Bittorent)
sudo ufw allow 4000/udp # sentinel 
sudo ufw allow 4001/udp

# stable
# git clone --branch stable --single-branch https://github.com/ledgerwatch/erigon.git
# devrel
# git clone --recurse-submodules https://github.com/paradigmxyz/reth
# cd reth
# git pull
# RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --release

cargo install --locked --path bin/reth --bin reth
# cargo build --release


rm -rf $HOME/reth/*
mkdir $HOME/reth

# overwrite the eth1 servicwe

cat > $HOME/eth1.service << EOF 
[Unit]
Description     = reth execution client service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = /home/eth/.cargo/bin/reth node
Restart         = on-failure
TimeoutStopSec  = 6000
RestartSec      = 10
TimeoutSec      = 3000

[Install]
WantedBy    = multi-user.target
EOF

sudo mv $HOME/eth1.service /etc/systemd/system/eth1.service
sudo chmod 644 /etc/systemd/system/eth1.service
sudo systemctl daemon-reload
sudo systemctl enable eth1
sudo systemctl start eth1
sudo systemctl status eth1
