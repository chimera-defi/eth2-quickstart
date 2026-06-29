#!/bin/bash

# Nethermind Execution Client Installation Script
# Language: C# (.NET)
# Nethermind is a .NET Ethereum client designed for enterprise use
# Usage: ./nethermind.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

log_installation_start "Nethermind"

# Check system requirements
check_system_requirements 16 2000


# Setup firewall rules for Nethermind
setup_firewall_rules 30303 8545 8546 8551

# Create Nethermind directory
NETHERMIND_DIR="$HOME/nethermind"
ensure_directory "$NETHERMIND_DIR"

cd "$NETHERMIND_DIR" || exit

# Get download URL from GitHub API (asset name includes commit hash, e.g. nethermind-1.36.0-31cb81b7-linux-x64.zip)
log_info "Fetching latest Nethermind release..."
DOWNLOAD_URL=$(get_github_release_asset_url "NethermindEth/nethermind" "nethermind-.*-linux-x64\.zip")
if [[ -z "$DOWNLOAD_URL" ]]; then
    log_error "Could not fetch Nethermind release asset URL"
    exit 1
fi

ARCHIVE_FILE="${DOWNLOAD_URL##*/}"

log_info "Downloading Nethermind..."
if download_file "$DOWNLOAD_URL" "$ARCHIVE_FILE"; then
    extract_archive "$ARCHIVE_FILE" "$NETHERMIND_DIR" 0
    rm -f "$ARCHIVE_FILE"
else
    log_error "Failed to download Nethermind"
    exit 1
fi

# Make Nethermind executable
chmod +x "$NETHERMIND_DIR/Nethermind.Runner"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"
ensure_directory "$HOME/.local/share/nethermind/nethermind_db"

# Create temporary directory for custom configuration
create_temp_config_dir

# Detect external IP via shared helper (safe fallback chain; no-op if all fail).
NETHERMIND_EXTERNAL_IP="$(detect_external_ip)"
if [[ -z "$NETHERMIND_EXTERNAL_IP" ]]; then
    log_warn "Could not detect external IP — nethermind will advertise no ExternalIp (degraded peering)"
fi

# Fetch the latest finalized block to use as a real snap pivot (post-merge, so TTD is fixed).
# A zero pivot makes SnapSync degenerate to a full fast-sync from genesis.
_nmd_pivot_json="$(curl -s --max-time 15 -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized",false],"id":1}' \
  https://ethereum.publicnode.com 2>/dev/null || \
  curl -s --max-time 15 -H 'Content-Type: application/json' \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized",false],"id":1}' \
  https://rpc.flashbots.net 2>/dev/null || true)"
NETHERMIND_PIVOT_NUMBER="$(printf '%s' "$_nmd_pivot_json" | python3 -c \
  'import json,sys; b=json.load(sys.stdin)["result"]; print(int(b["number"],16))' 2>/dev/null || echo 0)"
NETHERMIND_PIVOT_HASH="$(printf '%s' "$_nmd_pivot_json" | python3 -c \
  'import json,sys; b=json.load(sys.stdin)["result"]; print(b["hash"])' 2>/dev/null || \
  echo '0x0000000000000000000000000000000000000000000000000000000000000000')"
log_info "Nethermind snap pivot: block ${NETHERMIND_PIVOT_NUMBER} (${NETHERMIND_PIVOT_HASH})"

# Create custom configuration with variables
cat > "$NETHERMIND_DIR/nethermind_custom.cfg" << EOF
{
  "Init": {
    "WebSocketsEnabled": true,
    "StoreReceipts": true,
    "IsMining": false,
    "BaseDbPath": "$HOME/.local/share/nethermind/nethermind_db/mainnet",
    "LogFileName": "mainnet.logs.txt",
    "MemoryHint": ${NETHERMIND_CACHE}000000
  },
  "Network": {
    "DiscoveryPort": 30303,
    "P2PPort": 30303,
    "ExternalIp": "${NETHERMIND_EXTERNAL_IP}"
  },
  "JsonRpc": {
    "Enabled": true,
    "Timeout": 20000,
    "Host": "$LH",
    "Port": ${NETHERMIND_HTTP_PORT},
    "WebSocketsPort": ${NETHERMIND_WS_PORT},
    "JwtSecretFile": "$HOME/secrets/jwt.hex",
    "EngineHost": "$LH",
    "EnginePort": ${NETHERMIND_ENGINE_PORT},
    "EnabledModules": ["Admin", "Eth", "Net", "Web3"]
  },
  "EthStats": {
    "Enabled": false
  },
  "Metrics": {
    "Enabled": true,
    "NodeName": "Nethermind",
    "PushGatewayUrl": "",
    "IntervalSeconds": 5,
    "ExposeHost": "$LH",
    "ExposePort": 6060
  },
  "Sync": {
    "SnapSync": true,
    "PivotNumber": ${NETHERMIND_PIVOT_NUMBER},
    "PivotHash": "${NETHERMIND_PIVOT_HASH}",
    "PivotTotalDifficulty": "58750000000000000000000",
    "FastBlocks": true,
    "UseGethLimitsInFastBlocks": false,
    "AncientBodiesBarrier": 15537394,
    "AncientReceiptsBarrier": 15537394,
    "SnapSyncCatchUpHeightDelta": 10000000000
  },
  "Bloom": {
    "IndexLevelBucketSizes": [4, 8, 8]
  },
  "Mining": {
    "Enabled": false,
    "Coinbase": "${FEE_RECIPIENT}",
    "ExtraData": "${GRAFITTI}"
  },
  "Db": {
    "CacheIndexAndFilterBlocks": false
  },
  "TxPool": {
    "Size": 2048
  },
  "KeyStore": {
    "KeyStoreDirectory": "$HOME/nethermind/keystore"
  },
  "Merge": {
    "Enabled": true,
    "TerminalTotalDifficulty": "58750000000000000000000"
  }
}
EOF

# Merge base configuration with custom settings
merge_client_config "Nethermind" "main" "$PROJECT_ROOT/configs/nethermind/nethermind_base.cfg" "$NETHERMIND_DIR/nethermind_custom.cfg" "$NETHERMIND_DIR/nethermind.cfg"

# Clean up temporary files
rm -rf ./tmp/

# Create systemd service
EXEC_START="/usr/bin/env HOME=$HOME XDG_DATA_HOME=$HOME/.local/share $NETHERMIND_DIR/Nethermind.Runner --config $NETHERMIND_DIR/nethermind.cfg --KeyStore.KeyStoreDirectory $HOME/nethermind/keystore --JsonRpc.JwtSecretFile $HOME/secrets/jwt.hex --JsonRpc.EngineHost $LH --JsonRpc.EnginePort 8551"

create_systemd_service "eth1" "Nethermind Ethereum Execution Client" "$EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "eth1"

log_installation_complete "Nethermind" "eth1"
log_info "Configuration file: $NETHERMIND_DIR/nethermind.cfg"
log_info "To check status: sudo systemctl status eth1"
log_info "To view logs: journalctl -fu eth1"

# Display sync information
cat << EOF

=== Nethermind Sync Information ===
Nethermind will automatically start syncing when the service is started.
Initial sync may take 1-3 days depending on your hardware and network.

Key features:
- Fast sync enabled for quicker initial synchronization
- JSON-RPC API available on port 8545
- WebSocket API available on port 8546
- Engine API for consensus client communication on port 8551
- P2P networking on port 30303

EOF
