#!/bin/bash
# SECRETS_PATH=$(echo $HOME)/secrets/jwt.hex
# export pcmd=$(echo $HOME)/prysm/prysm.sh beacon-chain --config-file=$(echo $HOME)/prysm/prysm_beacon_conf.yaml --p2p-host-ip=$(curl -s v4.ident.me) 
mkdir ~/prysm && cd ~/prysm 
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh 
./prysm.sh beacon-chain generate-auth-secret
mkdir ~/secrets
mv ./jwt.hex ~/secrets

cp ~/eth2-quickstart/prysm/prysm_beacon_conf.yaml ~/prysm/prysm_beacon_conf.yaml
cp ~/eth2-quickstart/prysm/prysm_beacon_sync_conf.yaml ~/prysm/prysm_beacon_sync_conf.yaml
cp ~/eth2-quickstart/prysm/prysm_validator_conf.yaml ~/prysm/prysm_validator_conf.yaml


cat > $HOME/beacon-chain.service << EOF 
# The eth2 beacon chain service (part of systemd)
# file: /etc/systemd/system/beacon-chain.service 

[Unit]
Description     = eth2 beacon chain service
Wants           = network-online.target
After           = network-online.target 

[Service]
Type            = simple
User            = $(whoami)
ExecStart       = $(echo $HOME)/prysm/prysm.sh beacon-chain --p2p-host-ip=$(curl -s v4.ident.me) --config-file=$(echo $HOME)/prysm/prysm_beacon_conf.yaml --jwt-secret $(echo $HOME)/secrets/jwt.hex
Restart         = on-failure

[Install]
WantedBy    = multi-user.target
EOF

sudo mv $HOME/beacon-chain.service /etc/systemd/system/beacon-chain.service
sudo chmod 644 /etc/systemd/system/beacon-chain.service


# Setup validator

cat > $HOME/validator.service << EOF 
# The eth2 validator service (part of systemd)
# file: /etc/systemd/system/validator.service 

[Unit]
Description     = eth2 validator service
Wants           = network-online.target beacon-chain.service
After           = network-online.target 

[Service]
User            = $(whoami)
ExecStart       = $(echo $HOME)/prysm/prysm.sh validator --p2p-host-ip=$(curl -s v4.ident.me) --config-file=$(echo $HOME)/prysm/prysm_validator_conf.yaml --jwt-secret $(echo $HOME)/secrets/jwt.hex

Restart         = on-failure

[Install]
WantedBy	= multi-user.target
EOF
sudo mv $HOME/validator.service /etc/systemd/system/validator.service
sudo chmod 644 /etc/systemd/system/validator.service


sudo systemctl daemon-reload
sudo systemctl enable beacon-chain
sudo systemctl enable validator
