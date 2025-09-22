#!/bin/bash
source ./exports.sh
source ./lib/common.sh

mkdir ~/prysm && cd ~/prysm 
curl https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh --output prysm.sh && chmod +x prysm.sh 
./prysm.sh beacon-chain generate-auth-secret
mkdir ~/secrets
mv ./jwt.hex ~/secrets

mkdir ./tmp
# Append user custom settings for fee recipient and grafitti
cat > ./tmp/prysm_validator_conf.yaml << EOF 
graffiti: $GRAFITTI
suggested-fee-recipient: $FEE_RECIPIENT
wallet-password-file: $HOME/secrets/pass.txt
EOF
cat ~/eth2-quickstart/prysm/prysm_validator_conf.yaml ~/eth2-quickstart/tmp/prysm_validator_conf.yaml > ~/prysm/prysm_validator_conf.yaml

cat > ./tmp/prysm_beacon_conf.yaml << EOF 
graffiti: $GRAFITTI
suggested-fee-recipient: $FEE_RECIPIENT
p2p-host-ip: $(echo $(curl -s v4.ident.me))
p2p-max-peers: $MAX_PEERS
checkpoint-sync-url: $PRYSM_CPURL
genesis-beacon-api-url: $PRYSM_CPURL
jwt-secret: $HOME/secrets/jwt.hex
EOF
cat ~/eth2-quickstart/prysm/prysm_beacon_conf.yaml ~/eth2-quickstart/tmp/prysm_beacon_conf.yaml > ~/prysm/prysm_beacon_conf.yaml

rm -rf ./tmp/

readonly BCM="$(echo $HOME)/prysm/prysm.sh beacon-chain 
--config-file=$(echo $HOME)/prysm/prysm_beacon_conf.yaml"
readonly VCM="$(echo $HOME)/prysm/prysm.sh validator
--config-file=$(echo $HOME)/prysm/prysm_validator_conf.yaml"

create_systemd_service cl "eth2 beacon chain service" "$BCM"

# Setup validator
create_systemd_service validator "eth2 validator service" "$VCM"

echo "DONE! Files generated in $HOME/prysm/ ; systemd services: /etc/systemd/system/validator.service , /etc/systemd/system/beacon-chain.service "
