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
BEACON_QUERY_STATUS="ok"
MIN_BALANCE=""
MAX_BALANCE=""
WITHDRAWAL_TYPE=""
STATUS_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_OUTPUT=true ;;
        --min-balance)
            [[ $# -ge 2 ]] || { echo "Error: --min-balance requires a value (ETH)" >&2; exit 2; }
            MIN_BALANCE="$2"; shift ;;
        --max-balance)
            [[ $# -ge 2 ]] || { echo "Error: --max-balance requires a value (ETH)" >&2; exit 2; }
            MAX_BALANCE="$2"; shift ;;
        --withdrawal-type)
            [[ $# -ge 2 ]] || { echo "Error: --withdrawal-type requires a value (0x00|0x01|0x02)" >&2; exit 2; }
            WITHDRAWAL_TYPE="${2,,}"
            case "$WITHDRAWAL_TYPE" in
                0x00|0x01|0x02) ;;
                *) echo "Error: --withdrawal-type must be 0x00, 0x01, or 0x02" >&2; exit 2 ;;
            esac
            shift ;;
        --status)
            [[ $# -ge 2 ]] || { echo "Error: --status requires a value (e.g. active_ongoing)" >&2; exit 2; }
            STATUS_FILTER="$2"; shift ;;
        --help|-h)
            cat <<'EOF'
Usage: ./install/utils/validator_list.sh [options]
  --json                     Machine-readable JSON output
  --min-balance <eth>        Only validators with balance >= this (ETH)
  --max-balance <eth>        Only validators with balance <= this (ETH)
  --withdrawal-type <type>   Filter by withdrawal credentials prefix: 0x00 (BLS),
                             0x01 (execution address), 0x02 (compounding)
  --status <substr>          Filter by status substring (e.g. active_ongoing)
EOF
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
        BEACON_QUERY_STATUS="no_pubkeys"
        echo '{"data":[]}' > "$out_file"
        return
    fi

    # Build id= query string with 0x-prefixed pubkeys
    local ids
    ids=$(printf "0x%s," "${pubkeys[@]}")
    ids="${ids%,}"

    local response curl_rc=0
    response=$(curl -sS         --max-time 15         "${beacon_url}/eth/v1/beacon/states/head/validators?id=${ids}"         2>/dev/null) || curl_rc=$?

    if [[ $curl_rc -ne 0 || -z "$response" ]]; then
        BEACON_QUERY_STATUS="failed"
        echo '{"data":[]}' > "$out_file"
    else
        BEACON_QUERY_STATUS="ok"
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
    local generated_at_utc
    generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "Detected consensus client: ${client}"
        log_info "Beacon API: ${beacon_url}"
        log_info "Inventory snapshot: ${generated_at_utc}"
        log_info "Scanning for validator keystores..."
    fi

    mapfile -t pubkeys < <(find_pubkeys "$client")

    if [[ ${#pubkeys[@]} -eq 0 ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo '{"client":"'"$client"'","beacon_url":"'"$beacon_url"'","generated_at_utc":"'"$generated_at_utc"'","beacon_query_status":"no_keystores_found","validators":[],"error":"no_keystores_found"}'
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

    # Apply optional filters (balance / withdrawal type / status) to the beacon
    # data in place, so both table and JSON output reflect the same filtered set.
    if [[ -n "$MIN_BALANCE" || -n "$MAX_BALANCE" || -n "$WITHDRAWAL_TYPE" || -n "$STATUS_FILTER" ]]; then
        local filter_args=()
        [[ -n "$MIN_BALANCE" ]]     && filter_args+=(--min-balance "$MIN_BALANCE")
        [[ -n "$MAX_BALANCE" ]]     && filter_args+=(--max-balance "$MAX_BALANCE")
        [[ -n "$WITHDRAWAL_TYPE" ]] && filter_args+=(--withdrawal-type "$WITHDRAWAL_TYPE")
        [[ -n "$STATUS_FILTER" ]]   && filter_args+=(--status "$STATUS_FILTER")
        local filter_err
        if filter_err=$(python3 "$SCRIPT_DIR/validator_filter.py" "$tmpfile" "${filter_args[@]}" 2>&1 1>"${tmpfile}.f"); then
            mv "${tmpfile}.f" "$tmpfile"
        else
            rm -f "${tmpfile}.f"
            log_error "Validator filter failed (filters not applied): ${filter_err}"
            exit 1
        fi
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        python3 - "$tmpfile" "$client" "$beacon_url" "$generated_at_utc" "$BEACON_QUERY_STATUS" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    raw = json.load(f)
print(json.dumps({
    "client": sys.argv[2],
    "beacon_url": sys.argv[3],
    "generated_at_utc": sys.argv[4],
    "beacon_query_status": sys.argv[5],
    "validators": raw.get("data", [])
}, indent=2))
PYEOF
    else
        if [[ "$BEACON_QUERY_STATUS" == "failed" ]]; then
            log_warn "Beacon query failed; showing only local keystores that matched."
        fi
        print_table "$tmpfile"
    fi
}

main "$@"
