#!/bin/bash
source ./exports.sh
source ./lib/common.sh

set -e

ensure_jwt_secret

ensure_apt_packages curl git build-essential pkg-config libssl-dev

cd "$HOME"
rm -rf nimbus-eth2
git clone https://github.com/status-im/nimbus-eth2.git
cd nimbus-eth2
make -j4 nimbus_beacon_node

allow_ufw_ports 5052 5053

CLCMD="$HOME/nimbus-eth2/build/nimbus_beacon_node \
  --network=mainnet \
  --web3-url=http://127.0.0.1:8551 \
  --jwt-secret=$HOME/secrets/jwt.hex \
  --rest \
  --rest-address=127.0.0.1 \
  --suggested-fee-recipient=$FEE_RECIPIENT \
  --graffiti=$GRAFITTI \
  --checkpoint-sync-url=$PRYSM_CPURL"

VCCMD="$HOME/nimbus-eth2/build/nimbus_beacon_node validator \
  --data-dir=$HOME/.cache/nimbus \
  --beacon-node=http://127.0.0.1:5052"

create_systemd_service cl "nimbus beacon chain service" "$CLCMD" simple "$(whoami)" on-failure 10 6000 3000
create_systemd_service validator "nimbus validator service" "$VCCMD" simple "$(whoami)" on-failure 10 6000 3000
