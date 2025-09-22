#!/bin/bash
source ./exports.sh
source ./lib/common.sh

set -e

ensure_jwt_secret

ensure_apt_packages wget tar gzip default-jre-headless

cd "$HOME"
rm -rf besu
mkdir -p besu

# Download a specific stable Besu version (update as needed)
BESU_VERSION="24.6.0"
wget -q https://hyperledger.jfrog.io/artifactory/besu-binaries/besu/${BESU_VERSION}/besu-${BESU_VERSION}.tar.gz -O besu.tar.gz
tar -xzf besu.tar.gz -C besu --strip-components=1
rm besu.tar.gz

allow_ufw_ports 30303 30304 8551 8545 8546

BESUCMD="$HOME/besu/bin/besu \
  --network=mainnet \
  --data-path=$HOME/.local/share/besu \
  --rpc-http-enabled \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-api=ETH,NET,WEB3,ADMIN,ENGINE \
  --rpc-ws-enabled \
  --rpc-ws-host=0.0.0.0 \
  --engine-rpc-enabled=true \
  --engine-host=127.0.0.1 \
  --engine-port=8551 \
  --engine-jwt-secret=$HOME/secrets/jwt.hex"

create_systemd_service eth1 "besu execution client service" "$BESUCMD"
