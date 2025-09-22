#!/bin/bash

source ./exports.sh
source ./lib/common.sh

# Setup  reth
# https://paradigmxyz.github.io/reth/installation/source.html
#

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

sudo apt-get install libclang-dev pkg-config build-essential cargo -y

# erigon uses some extra ports - we open these for reth too to be safe? 
allow_ufw_ports 30303 30304 42069 4000/udp 4001/udp

if [ ! -d "$HOME/reth-src" ]; then
    git clone --recurse-submodules https://github.com/paradigmxyz/reth "$HOME/reth-src"
fi
cd "$HOME/reth-src"
git pull --ff-only
RUSTFLAGS="-C target-cpu=native" cargo build --profile maxperf --release
cp -f target/maxperf/release/reth "$HOME/.cargo/bin/reth" || cp -f target/release/reth "$HOME/.cargo/bin/reth"


rm -rf $HOME/reth/*
mkdir $HOME/reth

# overwrite the eth1 servicwe

ensure_jwt_secret

create_systemd_service eth1 "reth execution client service" "$HOME/.cargo/bin/reth node --authrpc.jwtsecret=$HOME/secrets/jwt.hex --authrpc.addr=127.0.0.1 --authrpc.port=8551"

sudo systemctl start eth1
sudo systemctl status eth1 | cat
