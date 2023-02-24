#!/bin/bash
source ./exports.sh

# Hot patch prysm installation with mev prysm 

# prereqs to build from src
sudo apt install cmake libssl-dev libgmp-dev libtinfo5 libprotoc
# go install github.com/bazelbuild/bazelisk@latest
# bazel 
sudo apt install apt-transport-https curl gnupg -y
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update && sudo apt install bazel-5.3.0


rm -rf prysm
git clone --recurse-submodules https://github.com/flashbots/prysm.git
cd prysm
bazel build //cmd/beacon-chain:beacon-chain --config=release
bazel build //cmd/validator:validator --config=release
sudo apt update && sudo apt install bazel

# ?? 
# $(echo $HOME)/prysm/prysm.sh
# 

cd $HOME && rm -rf ~/prysm
git clone --recurse-submodules https://github.com/flashbots/prysm.git
cd prysm
bazel build //cmd/beacon-chain:beacon-chain --config=release
bazel build //cmd/validator:validator --config=release

cp bazel-bin/cmd/validator/validator_/validator $HOME/prysm/
cp bazel-bin/cmd/beacon-chain/beacon-chain_/beacon-chain $HOME/prysm/

# gen jwt again
$HOME/prysm/beacon-chain generate-auth-secret
mkdir ~/secrets
mv ./jwt.hex ~/secrets


# overwrite pre-installed prysm bin with our commands

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
ExecStart       = $HOME/prysm/beacon-chain --config-file=$(echo $HOME)/prysm/prysm_beacon_conf.yaml
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
ExecStart       = $HOME/prysm/validator --config-file=$(echo $HOME)/prysm/prysm_validator_conf.yaml

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
