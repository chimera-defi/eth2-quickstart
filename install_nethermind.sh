#!/bin/bash

# Install Nethermind Ethereum execution client
# https://docs.nethermind.io/nethermind/ethereum-client-for-enterprise/nethermind-cli-client

source ./exports.sh
source ./common_functions.sh

log_info "Installing Nethermind execution client..."

# Check if not running as root
check_not_root

# Update system and install dependencies
update_system
install_common_deps

# Install .NET dependencies
log_info "Installing .NET dependencies..."
sudo apt install -y wget apt-transport-https software-properties-common
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt update
sudo apt install -y dotnet-sdk-6.0

# Create Nethermind directory
NETHERMIND_DIR="$HOME/nethermind"
mkdir -p "$NETHERMIND_DIR"

# Download and install Nethermind
log_info "Downloading Nethermind..."
NETHERMIND_VERSION=$(get_latest_release "NethermindEth/nethermind")
NETHERMIND_URL="https://github.com/NethermindEth/nethermind/releases/download/${NETHERMIND_VERSION}/nethermind-linux-amd64-${NETHERMIND_VERSION}.tar.gz"

cd "$NETHERMIND_DIR"
wget -O nethermind.tar.gz "$NETHERMIND_URL"
tar -xzf nethermind.tar.gz
rm nethermind.tar.gz

# Create JWT secret
create_jwt_secret "$HOME/secrets/jwt.hex"

# Create Nethermind configuration
log_info "Creating Nethermind configuration..."
cat > "$NETHERMIND_DIR/config.json" << EOF
{
  "Init": {
    "ChainSpecPath": "chainspec.json",
    "GenesisHash": "0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3",
    "BaseDbPath": "nethermind_db",
    "LogFileName": "nethermind.log",
    "MemoryHint": "8192"
  },
  "Network": {
    "DiscoveryPort": 30303,
    "P2PPort": 30303,
    "MaxActivePeers": 50,
    "PriorityPeersMaxCount": 25,
    "StaticPeers": []
  },
  "JsonRpc": {
    "Enabled": true,
    "Host": "127.0.0.1",
    "Port": 8545,
    "WebSocketsPort": 8546,
    "EnabledModules": ["Admin", "Eth", "Net", "Web3", "Debug", "Trace", "TxPool", "Personal", "Proof", "Engine"],
    "JwtSecretFile": "$HOME/secrets/jwt.hex"
  },
  "Sync": {
    "SyncMode": "SnapSync",
    "FastSync": true,
    "FastBlocks": true,
    "DownloadBodiesInFastSync": true,
    "DownloadReceiptsInFastSync": true,
    "AncientBodiesBarrier": 11052984,
    "AncientReceiptsBarrier": 11052984
  },
  "Mining": {
    "Enabled": false
  },
  "EthStats": {
    "Enabled": false
  },
  "Metrics": {
    "Enabled": true,
    "NodeName": "Nethermind",
    "PushGatewayUrl": "",
    "IntervalSeconds": 5
  }
}
EOF

# Create systemd service
NETHERMIND_CMD="$NETHERMIND_DIR/Nethermind.Runner --config $NETHERMIND_DIR/config.json"
create_systemd_service "eth1" "Nethermind execution client service" "$NETHERMIND_CMD" "$(whoami)"

# Open required ports
open_firewall_ports "30303" "8545" "8546"

# Print installation summary
print_installation_summary "Nethermind" "eth1"

log_info "Nethermind installation completed successfully!"
log_info "Configuration file: $NETHERMIND_DIR/config.json"
log_info "Data directory: $NETHERMIND_DIR/nethermind_db"
log_info "Log file: $NETHERMIND_DIR/nethermind.log"