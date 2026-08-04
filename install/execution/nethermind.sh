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

# Validate mode controls before any download, extraction, or service side effect.
case "${NETHERMIND_FULL_HISTORY:-false}" in
    true|false) ;;
    *) log_error "NETHERMIND_FULL_HISTORY must be exactly true or false (got: ${NETHERMIND_FULL_HISTORY:-unset})"; exit 1 ;;
esac
case "${NETHERMIND_ALLOW_HISTORY_DOWNGRADE:-false}" in
    true|false) ;;
    *) log_error "NETHERMIND_ALLOW_HISTORY_DOWNGRADE must be exactly true or false (got: ${NETHERMIND_ALLOW_HISTORY_DOWNGRADE:-unset})"; exit 1 ;;
esac

# Get script directories
get_script_directories

log_installation_start "Nethermind"

# Check system requirements. Minimal-history nodes need substantially less disk than
# full-history nodes; inspect an existing config so reruns keep the right safety margin.
NETHERMIND_REQUIRED_DISK_GB=400
if [[ "${NETHERMIND_FULL_HISTORY:-false}" == "true" ]] ||
   [[ -d "$HOME/.local/share/nethermind/nethermind_db/mainnet" ]]; then
    NETHERMIND_REQUIRED_DISK_GB=2000
fi
check_system_requirements 16 "$NETHERMIND_REQUIRED_DISK_GB"


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
# `|| true` guards set -e: the substitution must not abort the install if detection
# fails — we degrade gracefully instead (besu.sh follows the same guarded pattern).
NETHERMIND_EXTERNAL_IP="$(detect_external_ip || true)"
if [[ -n "$NETHERMIND_EXTERNAL_IP" ]]; then
    NETHERMIND_EXTERNAL_IP_LINE="    \"ExternalIp\": \"${NETHERMIND_EXTERNAL_IP}\","
    log_info "Nethermind advertising external IP for P2P: ${NETHERMIND_EXTERNAL_IP}"
else
    NETHERMIND_EXTERNAL_IP_LINE=""
    log_warn "Could not detect external IP — omitting ExternalIp; nethermind will rely on its own NAT/discovery detection (may yield degraded peering)"
fi

# Fetch the latest finalized block to use as a real snap pivot (post-merge, so TTD is fixed).
# A zero pivot makes SnapSync degenerate to a full fast-sync from genesis.
# Each endpoint is validated independently: a 200-OK JSON-RPC error body (missing .result,
# or .result.number missing/empty) is treated as a failure and the next endpoint is tried.
# Transport failure (curl non-zero) also falls through to the next endpoint.
# If ALL endpoints fail, NETHERMIND_PIVOT_NUMBER stays 0 and NETHERMIND_PIVOT_HASH stays empty.
NETHERMIND_PIVOT_NUMBER=0
NETHERMIND_PIVOT_HASH=""
_nmd_pivot_rpc_data='{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["finalized",false],"id":1}'
for _nmd_url in "https://ethereum.publicnode.com" "https://rpc.flashbots.net"; do
    _nmd_json="$(curl -s --max-time 15 -H 'Content-Type: application/json' \
        --data "$_nmd_pivot_rpc_data" "$_nmd_url" 2>/dev/null || true)"
    # Validate: .result must exist and .result.number must be a non-empty hex string.
    # A JSON-RPC error body has no .result key; we use .get() so KeyError becomes empty string.
    _nmd_parsed="$(printf '%s' "$_nmd_json" | python3 -c \
        'import json,sys
r=(json.load(sys.stdin) if sys.stdin else {}).get("result") or {}
n=r.get("number",""); h=r.get("hash","")
print(str(int(n,16))+" "+h if n and h else "")
' 2>/dev/null || true)"
    if [[ -n "$_nmd_parsed" ]]; then
        NETHERMIND_PIVOT_NUMBER="${_nmd_parsed%% *}"
        NETHERMIND_PIVOT_HASH="${_nmd_parsed##* }"
        break
    fi
    log_warn "Nethermind pivot: endpoint ${_nmd_url} returned unusable response, trying next"
done

# Only write a pivot if we fetched a real, recent finalized block. On failure we OMIT
# PivotNumber/PivotHash rather than write 0 — a zero pivot degenerates SnapSync into a
# genesis fast-sync. With no pivot, SnapSync bootstraps from the consensus client's
# forkchoice once peers connect (safe fallback: dynamic value, sane default on failure).
NETHERMIND_PIVOT_BLOCK=""
if [[ "$NETHERMIND_PIVOT_NUMBER" =~ ^[0-9]+$ ]] && [[ "$NETHERMIND_PIVOT_NUMBER" -gt 0 ]] \
   && [[ "$NETHERMIND_PIVOT_HASH" =~ ^0x[0-9a-fA-F]{64}$ ]] \
   && [[ "$NETHERMIND_PIVOT_HASH" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]]; then
    NETHERMIND_PIVOT_BLOCK="    \"PivotNumber\": ${NETHERMIND_PIVOT_NUMBER},
    \"PivotHash\": \"${NETHERMIND_PIVOT_HASH}\","
    log_info "Nethermind snap pivot: block ${NETHERMIND_PIVOT_NUMBER} (${NETHERMIND_PIVOT_HASH})"
else
    log_warn "Could not fetch a finalized snap pivot — omitting PivotNumber/PivotHash; SnapSync will bootstrap its pivot from the consensus client forkchoice once peers connect (slower start, NOT a genesis fast-sync)"
fi

# History retention mode (see NETHERMIND_FULL_HISTORY in exports.sh).
#   Minimal (default): AncientBarriers >= pivot => no post-merge body/receipt backfill,
#     StoreReceipts=false => ~250-280 GiB staking node, NO historical RPC (old blocks null).
#   Full: AncientBarriers = the merge (15537394) + StoreReceipts=true => ~1.1 TiB with
#     full post-merge history; serves historical RPC (needed for a public DeFi/indexer RPC).
# Effective barrier is min(PivotNumber, barrier), so 99999999 => download only from pivot.
#
# Re-running the installer must not silently turn an existing datadir into a
# mixed database. When no explicit mode-change opt-in is supplied, preserve the
# mode recorded in the existing config and keep its receipt behavior.
NETHERMIND_HISTORY_MODE="${NETHERMIND_FULL_HISTORY:-false}"
NETHERMIND_ALLOW_MODE_CHANGE="${NETHERMIND_ALLOW_HISTORY_DOWNGRADE:-false}"
NETHERMIND_EXISTING_DB="$HOME/.local/share/nethermind/nethermind_db/mainnet"
NETHERMIND_EXISTING_CONFIG="$NETHERMIND_DIR/nethermind.cfg"
if [[ -d "$NETHERMIND_EXISTING_DB" && "$NETHERMIND_ALLOW_MODE_CHANGE" == "true" ]]; then
    log_error "Refusing to change Nethermind history mode while an existing datadir is present. Wipe/rebuild the datadir first, then rerun with NETHERMIND_ALLOW_HISTORY_DOWNGRADE=true."
    exit 1
fi
if [[ -d "$NETHERMIND_EXISTING_DB" && -f "$NETHERMIND_EXISTING_CONFIG" ]]; then
    if grep -Eq '"StoreReceipts"[[:space:]]*:[[:space:]]*true' "$NETHERMIND_EXISTING_CONFIG"; then
        if [[ "$NETHERMIND_HISTORY_MODE" != "true" ]]; then
            log_warn "Existing full-history datadir detected; preserving receipt storage. Set NETHERMIND_ALLOW_HISTORY_DOWNGRADE=true only when intentionally rebuilding/replacing that datadir."
        fi
        NETHERMIND_HISTORY_MODE=true
    elif grep -Eq '"StoreReceipts"[[:space:]]*:[[:space:]]*false' "$NETHERMIND_EXISTING_CONFIG"; then
        if [[ "$NETHERMIND_HISTORY_MODE" != "false" ]]; then
            log_warn "Existing minimal-history datadir detected; retaining minimal mode. Wipe/rebuild the datadir before enabling full history."
        fi
        NETHERMIND_HISTORY_MODE=false
    else
        log_warn "Existing Nethermind config has no recognizable receipt mode; preserving full receipt storage until the datadir is rebuilt"
        NETHERMIND_HISTORY_MODE=true
    fi
elif [[ -d "$NETHERMIND_EXISTING_DB" ]]; then
    log_warn "Existing Nethermind datadir has no config to identify its history mode; preserving receipt storage until the datadir is rebuilt"
    NETHERMIND_HISTORY_MODE=true
fi

if [[ "$NETHERMIND_HISTORY_MODE" == "true" ]]; then
    NM_STORE_RECEIPTS=true
    NM_ANCIENT_BARRIER=15537394
    log_info "Nethermind history: FULL post-merge (~1.1 TiB) — serves historical RPC"
else
    NM_STORE_RECEIPTS=false
    NM_ANCIENT_BARRIER=99999999
    log_info "Nethermind history: MINIMAL staking node (~250-280 GiB) — no historical RPC; set NETHERMIND_FULL_HISTORY=true for a full-history/RPC node"
fi

# Create custom configuration with variables
cat > "$NETHERMIND_DIR/nethermind_custom.cfg" << EOF
{
  "Init": {
    "WebSocketsEnabled": true,
    "StoreReceipts": ${NM_STORE_RECEIPTS},
    "IsMining": false,
    "BaseDbPath": "$HOME/.local/share/nethermind/nethermind_db/mainnet",
    "LogFileName": "mainnet.logs.txt",
    "MemoryHint": ${NETHERMIND_CACHE}000000
  },
  "Receipt": {
    "StoreReceipts": ${NM_STORE_RECEIPTS}
  },
  "Network": {
    "DiscoveryPort": 30303,
${NETHERMIND_EXTERNAL_IP_LINE}
    "P2PPort": 30303
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
    "EnabledModules": ["Eth", "Net", "Web3"]
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
    "FastSync": true,
    "SnapSync": true,
${NETHERMIND_PIVOT_BLOCK}
    "PivotTotalDifficulty": "58750003716598352816469",
    "FastBlocks": true,
    "UseGethLimitsInFastBlocks": false,
    "AncientBodiesBarrier": ${NM_ANCIENT_BARRIER},
    "AncientReceiptsBarrier": ${NM_ANCIENT_BARRIER},
    "FastSyncCatchUpHeightDelta": 10000000000
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

# Apply the generated configuration to the running service. The shared helper
# intentionally uses `start`, which is a no-op for an already-active unit; restart
# explicitly so a rerun cannot leave the previous history mode in memory.
if sudo systemctl is-active --quiet eth1; then
    log_info "Nethermind is already active; restarting it to load the generated configuration"
    sudo systemctl restart eth1
    if ! sudo systemctl is-active --quiet eth1; then
        log_error "Nethermind failed after configuration restart"
        sudo systemctl status eth1 --no-pager -l 2>/dev/null | sed 's/^/  /' || true
        sudo journalctl -u eth1 -n 80 --no-pager 2>/dev/null | sed 's/^/  /' || true
        exit 1
    fi
else
    enable_and_start_systemd_service "eth1"
fi

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
