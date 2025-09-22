#!/bin/bash
source ./exports.sh
source ./lib/common.sh

set -e

ensure_jwt_secret

ensure_apt_packages curl gnupg ca-certificates

# Install Node.js (LTS) via NodeSource
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs build-essential

sudo npm install -g @lodestar/cli

allow_ufw_ports 5052 5053

CLCMD="lodestar beacon \
  --network mainnet \
  --execution.urls http://127.0.0.1:8551 \
  --jwt-secret $HOME/secrets/jwt.hex \
  --checkpointSyncUrl $PRYSM_CPURL \
  --rest.address 127.0.0.1 \
  --rest.port 5052 \
  --suggestedFeeRecipient $FEE_RECIPIENT \
  --graffiti '$GRAFITTI'"

VCCMD="lodestar validator \
  --network mainnet \
  --beaconNodes http://127.0.0.1:5052 \
  --suggestedFeeRecipient $FEE_RECIPIENT \
  --graffiti '$GRAFITTI'"

create_systemd_service cl "lodestar beacon chain service" "$CLCMD" simple "$(whoami)" on-failure 10 6000 3000
create_systemd_service validator "lodestar validator service" "$VCCMD" simple "$(whoami)" on-failure 10 6000 3000
