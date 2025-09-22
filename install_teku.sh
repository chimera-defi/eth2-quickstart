#!/bin/bash
source ./exports.sh
source ./lib/common.sh

set -e

ensure_jwt_secret

ensure_apt_packages wget tar gzip default-jre-headless

cd "$HOME"
rm -rf teku
mkdir -p teku

# Download Teku stable (update version as needed)
TEKU_VERSION="24.8.0"
wget -q https://artifacts.consensys.net/public/teku/raw/versions/${TEKU_VERSION}/teku-${TEKU_VERSION}.tar.gz -O teku.tar.gz || wget -q https://github.com/ConsenSys/teku/releases/download/${TEKU_VERSION}/teku-${TEKU_VERSION}.tar.gz -O teku.tar.gz
tar -xzf teku.tar.gz -C teku --strip-components=1
rm teku.tar.gz

allow_ufw_ports 5052 5053

BCCMD="$HOME/teku/bin/teku \
  --network=mainnet \
  --ee-endpoint=http://127.0.0.1:8551 \
  --ee-jwt-secret-file=$HOME/secrets/jwt.hex \
  --p2p-peer-upper-bound=$MAX_PEERS \
  --rest-api-enabled \
  --checkpoint-sync-url=$PRYSM_CPURL \
  --suggested-fee-recipient=$FEE_RECIPIENT \
  --validators-graffiti=$GRAFITTI"

VCCMD="$HOME/teku/bin/teku validator-client \
  --beacon-node-api-endpoint=http://127.0.0.1:5052 \
  --validators-graffiti=$GRAFITTI \
  --validators-keystore-locking-enabled=false"

create_systemd_service cl "teku beacon chain service" "$BCCMD" simple "$(whoami)" on-failure 10 6000 3000
create_systemd_service validator "teku validator service" "$VCCMD" simple "$(whoami)" on-failure 10 6000 3000
