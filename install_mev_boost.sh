#!/bin/bash
source ./exports.sh
source ./lib/common.sh
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

create_systemd_service mev "eth2 mev service" "$(echo $HOME)/mev-boost/mev-boost -mainnet -relay-check -min-bid $MIN_BID -relays $MEV_RELAYS  -request-timeout-getheader $MEVGETHEADERT -request-timeout-getpayload $MEVGETPAYLOADT -request-timeout-regval $MEVREGVALT" simple "$(whoami)" always 5 600 300
