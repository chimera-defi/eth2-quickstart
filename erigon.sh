#!/bin/bash

source ./exports.sh
source ./lib/common.sh

# Setup erigon devel 
# https://github.com/ledgerwatch/erigon
#

# erigon uses some extra ports
allow_ufw_ports 30303 30304 42069 4000/udp 4001/udp

# stable
# git clone --branch stable --single-branch https://github.com/ledgerwatch/erigon.git
# devrel
git clone --recurse-submodules https://github.com/ledgerwatch/erigon.git
cd erigon
git pull
make erigon
make rpcdaemon
make integration

rm -rf $HOME/erigon/*
mkdir $HOME/erigon

cat > $HOME/erigon/config.yaml << EOF
chain : "mainnet"
http : true
http.api : ["admin","engine","eth","erigon","web3","net","debug","db","trace","txpool","personal"]
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

ensure_jwt_secret

create_systemd_service eth1 "erigon execution client service" "$HOME/erigon/erigon --config $HOME/erigon/config.yaml --externalcl"

# print integration stages
./build/bin/integration print_stages --chain mainnet --datadir ~/.local/share/erigon