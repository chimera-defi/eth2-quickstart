#!/bin/bash
# Updates the software stack
source ../exports.sh

sudo systemctl stop eth1

# regular linux housecleaning
sudo apt-get update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# geth - upgrade before already shouldve upgraded it for us but here is cmd in case needed
sudo apt-get install ethereum -y
sudo apt upgrade geth -y 
sudo systemctl start eth1

# prysm
sudo systemctl restart cl
sudo systemctl restart validator

# mev / flashbots
rm -rf ./mev-boost # remove any pre-existing copies
./install_mev_boost.sh && sudo systemctl restart mev

#nginx
sudo service nginx restart

# Try to output a report
echo 'Upgraded from versions:'
echo $MEV_BOOST_VERSION
echo $GETH_VERSION
echo $PRYSM_VERSION
echo $NGINX_VERSION
echo 'to version'
export MEV_BOOST_VERSION=$(../mev-boost -version)
export GETH_VERSION=$(geth version)
export PRYSM_VERSION=$(../prysm/prysm.sh validator --version)
export NGINX_VERSION=$(nginx -v)
echo $MEV_BOOST_VERSION
echo $GETH_VERSION
echo $PRYSM_VERSION
echo $NGINX_VERSION
