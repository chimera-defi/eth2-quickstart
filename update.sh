#!/bin/bash

# Updates the software stack
# Verify the versions first
export MEV_BOOST_VERSION=$(../mev-boost -version)
export GETH_VERSION=$(geth version)
export PRYSM_VERSION=$(../prysm/prysm.sh validator --version)
export NGINX_VERSION=$(nginx -v)

# regular linux housecleaning
sudo apt-get update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# geth - upgrade before already shouldve upgraded it for us but here is cmd in case needed
# sudo apt upgrade geth -y 
sudo systemctl restart eth1

# prysm
sudo systemctl restart beacon-chain
sudo systemctl restart validator

# mev / flashbots
rm -rf ./mev-boost # remove any pre-existing copies
./install_mev_boost_censored.sh && sudo systemctl restart mev

#nginx
sudo service nginx restart

echo 'Upgraded from versions:'
echo $MEV_BOOST_VERSION
echo $GETH_VERSION
echo $PRYSM_VERSION
echo $NGINX_VERSION
echo 'to version'
export MEV_BOOST_VERSION=$(../mev-boost -version)
export GETH_VERSION=$(geth version)
export PRYSM_VERSION=$(../prysm/prysm.sh validator --version)
echo $MEV_BOOST_VERSION
echo $GETH_VERSION
echo $PRYSM_VERSION
echo $NGINX_VERSION
