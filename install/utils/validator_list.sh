#!/bin/bash

# Eth2 Quick Start — Validator List
# Lists validator keys managed by the local validator client,
# cross-referenced with the beacon node API for live status and balance.
#
# Usage: ./install/utils/validator_list.sh [--json] [filters]

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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) JSON_OUTPUT=true ;;
            --min-balance)
                [[ $# -ge 2 ]] || { echo "Error: --min-balance requires a value (ETH)" >&2; exit 2; }
                MIN_BALANCE="$2"
                shift
                ;;
            --max-balance)
                [[ $# -ge 2 ]] || { echo "Error: --max-balance requires a value (ETH)" >&2; exit 2; }
                MAX_BALANCE="$2"
                shift
                ;;
            --withdrawal-type)
                [[ $# -ge 2 ]] || { echo "Error: --withdrawal-type requires a value (0x00|0x01|0x02)" >&2; exit 2; }
                WITHDRAWAL_TYPE="${2,,}"
                case "$WITHDRAWAL_TYPE" in
                    0x00|0x01|0x02) ;;
                    *) echo "Error: --withdrawal-type must be 0x00, 0x01, or 0x02" >&2; exit 2 ;;
                esac
                shift
                ;;
            --status)
                [[ $# -ge 2 ]] || { echo "Error: --status requires a value (e.g. active_ongoing)" >&2; exit 2; }
                STATUS_FILTER="$2"
                shift
                ;;
            --help|-h)
                cat <<'EOF'
Usage: ./install/utils/validator_list.sh [options]
  --json                     Machine-readable JSON output
  --min-balance <eth>        Only validators with balance >= this (ETH)
  --max-balance <eth>        Only validators with balance <= this (ETH)
  --withdrawal-type <type>   Filter by withdrawal credentials prefix: 0x00, 0x01, or 0x02
  --status <substr>          Filter by status substring (e.g. active_ongoing)
EOF
                exit 0
                ;;
            *) echo "Unknown option: $1" >&2; exit 1 ;;
        esac
        shift
    done
fi

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

normalize_pubkey() {
    local pubkey="${1// /}"
    pubkey="${pubkey#0x}"
    pubkey="${pubkey#0X}"
    printf '%s\n' "$pubkey"
}

find_prysm_pubkeys_via_cli() {
    local prysm_cli="$HOME/prysm/prysm.sh"
    local wallet_dir="$HOME/.eth2validators/prysm-wallet-v2"
    local password_file="$HOME/secrets/pass.txt"

    [[ -x "$prysm_cli" ]] || return 0
    [[ -d "$wallet_dir" ]] || return 0
    [[ -f "$password_file" ]] || return 0

    "$prysm_cli" validator accounts list         --wallet-dir "$wallet_dir"         --wallet-password-file "$password_file"         --accept-terms-of-use 2>/dev/null         | grep -oE '0x[0-9a-fA-F]{96}'         | sed 's/^0x//'         | sort -u
}

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
                "$HOME/.eth2validators/prysm-wallet-v2/direct/accounts"
                "$HOME/.eth2validators/prysm-wallet-v2"
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

    {
        for dir in "${search_dirs[@]}"; do
            [[ -d "$dir" ]] || continue
            while IFS= read -r -d '' f; do
                local pubkeys
                pubkeys=$(python3 -c "
import json, sys


def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            normalized_key = str(key).lower().replace('-', '_')
            if normalized_key in ('pubkey', 'pub_key', 'public_key', 'validator_pubkey') and isinstance(value, str):
                print(value)
            else:
                walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)

try:
    d = json.load(open(sys.argv[1]))
    walk(d)
except Exception:
    pass
" "$f" 2>/dev/null || true)
                while IFS= read -r pubkey; do
                    [[ -n "$pubkey" ]] && normalize_pubkey "$pubkey"
                done <<< "$pubkeys"
            done < <(find "$dir" -maxdepth 4 -name "*.json" -print0 2>/dev/null)
        done

        if [[ "$client" == "prysm" ]]; then
            find_prysm_pubkeys_via_cli
        fi
    } | sort -u
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

    local normalized_pubkeys=()
    local pubkey
    for pubkey in "${pubkeys[@]}"; do
        pubkey="$(normalize_pubkey "$pubkey")"
        [[ -n "$pubkey" ]] && normalized_pubkeys+=("$pubkey")
    done

    if [[ ${#normalized_pubkeys[@]} -eq 0 ]]; then
        BEACON_QUERY_STATUS="no_pubkeys"
        echo '{"data":[]}' > "$out_file"
        return
    fi

    # Build id= query string with 0x-prefixed pubkeys
    local ids
    ids=$(printf "0x%s," "${normalized_pubkeys[@]}")
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

query_beacon_validators_batched() {
    local beacon_url="$1"
    local out_file="$2"
    shift 2
    local pubkeys=("$@")

    if [[ ${#pubkeys[@]} -eq 0 ]]; then
        BEACON_QUERY_STATUS="no_pubkeys"
        echo '{"data":[]}' > "$out_file"
        return
    fi

    local batch_size=100
    local batch_dir
    batch_dir=$(mktemp -d /tmp/vlist_batches_XXXXXX)
    local batch_files=()
    local saw_success=false
    local saw_failure=false

    local start=0
    while [[ $start -lt ${#pubkeys[@]} ]]; do
        local batch=("${pubkeys[@]:start:batch_size}")
        local batch_file="$batch_dir/batch_${#batch_files[@]}.json"
        query_beacon_validators "$beacon_url" "$batch_file" "${batch[@]}"
        batch_files+=("$batch_file")
        if [[ "$BEACON_QUERY_STATUS" == "ok" ]]; then
            saw_success=true
        elif [[ "$BEACON_QUERY_STATUS" == "failed" ]]; then
            saw_failure=true
        fi
        start=$((start + batch_size))
    done

    python3 - "$out_file" "${batch_files[@]}" <<'PYEOF'
import json, sys
merged = []
for path in sys.argv[2:]:
    try:
        with open(path) as f:
            merged.extend(json.load(f).get('data', []))
    except Exception:
        pass
with open(sys.argv[1], 'w') as f:
    json.dump({'data': merged}, f)
PYEOF

    rm -rf "$batch_dir"

    if [[ "$saw_failure" == true && "$saw_success" == true ]]; then
        BEACON_QUERY_STATUS="partial"
    elif [[ "$saw_failure" == true ]]; then
        BEACON_QUERY_STATUS="failed"
    else
        BEACON_QUERY_STATUS="ok"
    fi
}

# =============================================================================
# DISPLAY
# =============================================================================

filter_validator_rows() {
    local input_file="$1"
    local output_file="$2"

    python3 - "$input_file" "$output_file" "$MIN_BALANCE" "$MAX_BALANCE" "$WITHDRAWAL_TYPE" "$STATUS_FILTER" <<'PYEOF'
from decimal import Decimal, InvalidOperation
import json
import sys

input_file, output_file, min_balance, max_balance, withdrawal_type, status_filter = sys.argv[1:7]

def parse_decimal(value, name):
    if not value:
        return None
    try:
        return Decimal(value)
    except InvalidOperation:
        raise SystemExit(f"Invalid {name}: {value!r}")

min_eth = parse_decimal(min_balance, "--min-balance")
max_eth = parse_decimal(max_balance, "--max-balance")
withdrawal_type = withdrawal_type.lower()
status_filter = status_filter.lower()

with open(input_file) as f:
    raw = json.load(f)

def balance_eth(row):
    try:
        return Decimal(str(row.get("balance", "0"))) / Decimal("1000000000")
    except InvalidOperation:
        return Decimal("0")

def matches(row):
    bal = balance_eth(row)
    if min_eth is not None and bal < min_eth:
        return False
    if max_eth is not None and bal > max_eth:
        return False
    if withdrawal_type:
        cred = (row.get("validator", {}).get("withdrawal_credentials", "") or "").lower()
        if not cred.startswith(withdrawal_type):
            return False
    if status_filter and status_filter not in str(row.get("status", "")).lower():
        return False
    return True

raw["data"] = [row for row in raw.get("data", []) if matches(row)]

with open(output_file, "w") as f:
    json.dump(raw, f)
PYEOF
}

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

    local tmpfile filtered_tmpfile
    tmpfile=$(mktemp /tmp/vlist_XXXXXX.json)
    filtered_tmpfile=$(mktemp /tmp/vlist_filtered_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile' '$filtered_tmpfile'" EXIT

    query_beacon_validators_batched "$beacon_url" "$tmpfile" "${pubkeys[@]}"
    filter_validator_rows "$tmpfile" "$filtered_tmpfile"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        python3 - "$filtered_tmpfile" "$client" "$beacon_url" "$generated_at_utc" "$BEACON_QUERY_STATUS" <<'PYEOF'
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
        if [[ "$BEACON_QUERY_STATUS" == "failed" || "$BEACON_QUERY_STATUS" == "partial" ]]; then
            log_warn "Beacon query returned incomplete data; showing what matched locally."
        fi
        print_table "$filtered_tmpfile"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
