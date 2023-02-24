#!/bin/bash
source ./exports.sh

mkdir ~/prysm && cd ~/prysm 
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh 
./prysm.sh beacon-chain generate-auth-secret
mkdir ~/secrets
mv ./jwt.hex ~/secrets

# Append user custom settings for fee recipient and grafitti
cat > ~/prysm/prysm_validator_conf.yaml << EOF 
graffiti: $GRAFITTI
suggested-fee-recipient: $FEE_RECIPIENT
wallet-password-file: $HOME/secrets/pass.txt
EOF
cat ~/eth2-quickstart/prysm/prysm_validator_conf.yaml ~/prysm/prysm_validator_conf.yaml >> ~/prysm/prysm_validator_conf.yaml

cat > ~/prysm/prysm_beacon_conf.yaml << EOF 
graffiti: $GRAFITTI
suggested-fee-recipient: $FEE_RECIPIENT
p2p-host-ip: $(echo $(curl -s v4.ident.me))
p2p-max-peers: $MAX_PEERS
checkpoint-sync-url: $PRYSM_CPURL
genesis-beacon-api-url: $PRYSM_CPURL
jwt-secret: $HOME/secrets/jwt.hex
EOF
cat ~/eth2-quickstart/prysm/prysm_beacon_conf.yaml ~/prysm/prysm_beacon_conf.yaml >> ~/prysm/prysm_beacon_conf.yaml


readonly BCM="$(echo $HOME)/prysm/prysm.sh beacon-chain 
--config-file=$(echo $HOME)/prysm/prysm_beacon_conf.yaml"
readonly VCM="$(echo $HOME)/prysm/prysm.sh validator
--config-file=$(echo $HOME)/prysm/prysm_validator\conf.yaml"

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
ExecStart       = $(echo $BCM)
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
ExecStart       = $(echo $VCM)

Restart         = on-failure

[Install]
WantedBy	= multi-user.target
EOF
sudo mv $HOME/validator.service /etc/systemd/system/validator.service
sudo chmod 644 /etc/systemd/system/validator.service

sudo systemctl daemon-reload
sudo systemctl enable beacon-chain
sudo systemctl enable validator

echo "DONE! Files generated in $HOME/prysm/ ; systemd services: /etc/systemd/system/validator.service , /etc/systemd/system/beacon-chain.service "
