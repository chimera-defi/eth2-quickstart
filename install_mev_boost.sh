#!/bin/bash
source ./exports.sh
sudo apt install make gcc -y
sudo snap install --classic go
sudo ln -s /snap/bin/go /usr/bin/go

cd $HOME
rm -rf mev-boost
git clone https://github.com/flashbots/mev-boost
cd mev-boost
git checkout stable
git pull
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
ExecStart       = $(echo $HOME)/mev-boost/mev-boost -mainnet -relay-check -min-bid $MIN_BID -relays $MEV_RELAYS  -request-timeout-getheader $MEVGETHEADERT -request-timeout-getpayload $MEVGETPAYLOADT -request-timeout-regval $MEVREGVALT

Restart         = always
RestartSec      = 5

[Install]
WantedBy	= multi-user.target
EOF

sudo mv $HOME/mev.service /etc/systemd/system/mev.service
sudo chmod 644 /etc/systemd/system/mev.service

sudo systemctl daemon-reload
sudo systemctl enable mev
