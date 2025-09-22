#!/bin/bash
source ./exports.sh
source ./lib/common.sh

set -e

ensure_jwt_secret

ensure_apt_packages curl jq tar gzip

cd "$HOME"
rm -rf nethermind
mkdir -p nethermind

# Fetch latest Nethermind linux-x64 build
LATEST_URL=$(curl -s https://api.github.com/repos/NethermindEth/nethermind/releases/latest | jq -r '.assets[] | select(.name | test("linux-x64.*\.tar\.gz$")) | .browser_download_url' | head -n1)
if [ -z "$LATEST_URL" ]; then
	echo "Failed to determine latest Nethermind release URL" >&2
	exit 1
fi
curl -L "$LATEST_URL" -o nethermind.tar.gz
tar -xzf nethermind.tar.gz -C nethermind --strip-components=1
rm nethermind.tar.gz

allow_ufw_ports 30303 30304 8551 8545 8546

NMCMD="$HOME/nethermind/Nethermind.Runner \
  --config mainnet \
  --datadir $HOME/.local/share/nethermind \
  --JsonRpc.Enabled true \
  --JsonRpc.Host 0.0.0.0 \
  --JsonRpc.Port 8545 \
  --JsonRpc.EnabledModules Engine,Eth,Net,Web3,Admin \
  --JsonRpc.WebSocketsEnabled true \
  --JsonRpc.JwtSecretFile $HOME/secrets/jwt.hex \
  --JsonRpc.EngineHost 127.0.0.1 \
  --JsonRpc.EnginePort 8551"

create_systemd_service eth1 "nethermind execution client service" "$NMCMD"
