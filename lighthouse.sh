#!/bin/bash
source ./exports.sh
source ./lib/common.sh

mkdir -p ~/lighthouse && cd ~/lighthouse 
curl -LO https://github.com/sigp/lighthouse/releases/download/v4.5.0/lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz
tar -xvf lighthouse-v4.5.0-x86_64-unknown-linux-gnu.tar.gz

ensure_jwt_secret

CLCMD="RUST_LOG=info $HOME/lighthouse/lighthouse bn \
    --checkpoint-sync-url $PRYSM_CPURL \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt $HOME/secrets/jwt.hex \
    --suggested-fee-recipient $FEE_RECIPIENT \
    --graffiti $GRAFITTI \
    --disable-deposit-contract-sync"

VCCMD="$HOME/lighthouse/lighthouse vc \
    --suggested-fee-recipient $FEE_RECIPIENT \
    --graffiti $GRAFITTI \
    --datadir $HOME/.lighthouse \
    --beacon-nodes http://127.0.0.1:5052"

create_systemd_service cl "lighthouse beacon chain service" "$CLCMD" simple "$(whoami)" on-failure 10 6000 3000
create_systemd_service validator "lighthouse validator service" "$VCCMD" simple "$(whoami)" on-failure 10 6000 3000

sudo systemctl stop cl || true
sudo systemctl start cl
sudo systemctl status cl | cat
