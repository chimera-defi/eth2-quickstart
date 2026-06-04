#!/bin/bash

# Eth2 Quick Start — Validator List
# Lists validator keys managed by the local validator client,
# cross-referenced with the beacon node API for live status and balance.
#
# Usage: ./install/utils/validator_list.sh [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

# shellcheck source=../../lib/common_functions.sh
source "$ROOT_DIR/lib/common_functions.sh"
# shellcheck source=../../exports.sh
if [[ -f "$ROOT_DIR/exports.sh" ]]; then
    source "$ROOT_DIR/exports.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT_DIR/config/user_config.env" 2>/dev/null || true
fi

JSON_OUTPUT=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true ;;
        --help|-h)
            echo "Usage: ./install/utils/validator_list.sh [--json]"
            echo "  --json    Machine-readable JSON output"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

# =============================================================================
# CLIENT DETECTION
# =============================================================================

detect_client() {
    local exec_start
    exec_start=$(systemctl show validator --property=ExecStart --value 2>/dev/null || true)
    if [[ -z "$exec_start" ]]; then
        echo "unknown"
        return
    fi
    if echo "$exec_start"   | grep -qi "lighthouse"; then echo "lighthouse"
    elif echo "$exec_start" | grep -qi "prysm";      then echo "prysm"
    elif echo "$exec_start" | grep -qi "teku";       then echo "teku"
    elif echo "$exec_start" | grep -qi "lodestar";   then echo "lodestar"
    elif echo "$exec_start" | grep -qi "nimbus";     then echo "nimbus"
    elif echo "$exec_start" | grep -qi "grandine";   then echo "grandine"
    else echo "unknown"
    fi
}

# Returns the beacon REST API URL for the detected consensus client.
detect_beacon_url() {
    local exec_start
    exec_start=$(systemctl show cl --property=ExecStart --value 2>/dev/null || true)
    local port="5052"
    if echo "$exec_start" | grep -qi "teku"; then
        port="5051"
    elif echo "$exec_start" | grep -qi "lodestar"; then
        port="9596"
    fi
    echo "http://127.0.0.1:${port}"
}

# =============================================================================
# KEYSTORE DISCOVERY
# =============================================================================

# Searches well-known client keystore directories for EIP-2335 keystore files.
# Prints one pubkey per line (without 0x prefix).
find_pubkeys() {
    local client="$1"
    local search_dirs=()

    case "$client" in
        lighthouse)
            search_dirs=(
                "$HOME/.lighthouse/mainnet/validators"
                "$HOME/.lighthouse/validators"
                "$HOME/lighthouse/validators"
            )
            ;;
        prysm)
            search_dirs=(
                "$HOME/prysm"
                "$HOME/.ethereum/prysm"
            )
            ;;
        teku)
            search_dirs=(
                "$HOME/.local/share/teku/validator/keys"
                "$HOME/teku/validator/keys"
            )
            ;;
        lodestar)
            # Path set by lodestar.sh: $HOME/.local/share/lodestar/validators/keystores
            search_dirs=(
                "$HOME/.local/share/lodestar/validators/keystores"
                "$HOME/lodestar/keystores"
            )
            ;;
        nimbus)
            # Path set by nimbus.sh: $HOME/.local/share/nimbus/validators
            search_dirs=(
                "$HOME/.local/share/nimbus/validators"
                "$HOME/nimbus/validators"
            )
            ;;
        grandine)
            search_dirs=(
                "$HOME/.local/share/grandine/validator/keystores"
                "$HOME/grandine/validators"
            )
            ;;
        *)
            # Fallback: scan all known locations
            search_dirs=(
                "$HOME/.lighthouse/mainnet/validators"
                "$HOME/.lighthouse/validators"
                "$HOME/lighthouse/validators"
                "$HOME/.local/share/teku/validator/keys"
                "$HOME/.local/share/lodestar/validators/keystores"
                "$HOME/.local/share/nimbus/validators"
                "$HOME/.local/share/grandine/validator/keystores"
            )
            ;;
    esac

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' f; do
            local pubkey
            pubkey=$(python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get('pubkey', ''))
except Exception:
    pass
" "$f" 2>/dev/null || true)
            [[ -n "$pubkey" ]] && echo "$pubkey"
        done < <(find "$dir" -maxdepth 4 -name "*.json" -print0 2>/dev/null)
    done | sort -u
}

# =============================================================================
# BEACON API QUERY
# =============================================================================

# Queries beacon node for a list of validator pubkeys (max ~100 at a time to
# stay within URL length limits). Writes merged JSON to the given output file.
query_beacon_validators() {
    local beacon_url="$1"
    local out_file="$2"
    shift 2
    local pubkeys=("$@")

    if [[ ${#pubkeys[@]} -eq 0 ]]; then
        echo '{"data":[]}' > "$out_file"
        return
    fi

    # Build id= query string with 0x-prefixed pubkeys
    local ids
    ids=$(printf "0x%s," "${pubkeys[@]}")
    ids="${ids%,}"

    local response
    response=$(curl -sf \
        --max-time 15 \
        "${beacon_url}/eth/v1/beacon/states/head/validators?id=${ids}" \
        2>/dev/null || true)

    if [[ -z "$response" ]]; then
        echo '{"data":[]}' > "$out_file"
    else
        echo "$response" > "$out_file"
    fi
}

# =============================================================================
# DISPLAY
# =============================================================================

print_table() {
    local data_file="$1"

    python3 - "$data_file" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    raw = json.load(f)

rows = raw.get("data", [])
if not rows:
    print("  No validator data returned from beacon node.")
    print("  The node may still be syncing or no keys are imported yet.")
    sys.exit(0)

hdr = f"{'Index':<12} {'Public Key':<98} {'Status':<22} {'Balance (ETH)':<16} {'WCred'} Eff. Balance (ETH)"
print()
print(hdr)
print("-" * len(hdr))
for v in rows:
    idx    = v.get("index", "?")
    pubkey = v.get("validator", {}).get("pubkey", "?")
    status = v.get("status", "?")
    bal    = int(v.get("balance", 0)) / 1e9
    cred   = v.get("validator", {}).get("withdrawal_credentials", "") or ""
    wcred  = cred[:4].lower() if cred.startswith("0x") and len(cred) >= 4 else "?"
    eff    = int(v.get("validator", {}).get("effective_balance", 0)) / 1e9
    print(f"{idx:<12} {pubkey:<98} {status:<22} {bal:<16.6f} {wcred:<8} {eff:.6f}")
print("-" * len(hdr))
print(f"  {len(rows)} validator(s)")
print()
PYEOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local client
    client=$(detect_client)
    local beacon_url
    beacon_url=$(detect_beacon_url)

    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "Detected consensus client: ${client}"
        log_info "Beacon API: ${beacon_url}"
        log_info "Scanning for validator keystores..."
    fi

    mapfile -t pubkeys < <(find_pubkeys "$client")

    if [[ ${#pubkeys[@]} -eq 0 ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo '{"client":"'"$client"'","beacon_url":"'"$beacon_url"'","validators":[],"error":"no_keystores_found"}'
        else
            log_warn "No keystore files found for client '${client}'."
            echo "  Import validator keys first, then re-run this command."
        fi
        return
    fi

    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "Found ${#pubkeys[@]} keystore(s). Querying beacon node..."
    fi

    local tmpfile
    tmpfile=$(mktemp /tmp/vlist_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT

    query_beacon_validators "$beacon_url" "$tmpfile" "${pubkeys[@]}"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        python3 - "$tmpfile" "$client" "$beacon_url" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    raw = json.load(f)
print(json.dumps({
    "client": sys.argv[2],
    "beacon_url": sys.argv[3],
    "validators": raw.get("data", [])
}, indent=2))
PYEOF
    else
        print_table "$tmpfile"
    fi
}

main "$@"
