#!/bin/bash
sudo apt install golang-go make gcc -y

git clone https://github.com/flashbots/mev-boost
cd mev-boost
make build

cat > $HOME/mev.service << EOF 
# The eth2 mev service (part of systemd)
# file: /etc/systemd/system/mev.service 

[Unit]
Description     = eth2 mev service
Wants           = network-online.target
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = $(echo $HOME)/mev-boost/mev-boost -mainnet -relay-check -relays $MEV_RELAYS

Restart         = on-failure

[Install]
WantedBy	= multi-user.target
EOF

sudo mv $HOME/mev.service /etc/systemd/system/mev.service
sudo chmod 644 /etc/systemd/system/mev.service

sudo systemctl daemon-reload
sudo systemctl enable mev
