#!/bin/bash

# Eth2 Quick Start — Validator List
# Lists all validator keys managed by the local validator client,
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
    if echo "$exec_start" | grep -qi "lighthouse"; then
        echo "lighthouse"
    elif echo "$exec_start" | grep -qi "prysm"; then
        echo "prysm"
    elif echo "$exec_start" | grep -qi "teku"; then
        echo "teku"
    elif echo "$exec_start" | grep -qi "lodestar"; then
        echo "lodestar"
    elif echo "$exec_start" | grep -qi "nimbus"; then
        echo "nimbus"
    elif echo "$exec_start" | grep -qi "grandine"; then
        echo "grandine"
    else
        echo "unknown"
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
            search_dirs=(
                "$HOME/lodestar/keystores"
                "$HOME/.lodestar/keystores"
            )
            ;;
        nimbus)
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
            # Fallback: scan all likely locations
            search_dirs=(
                "$HOME/.lighthouse/mainnet/validators"
                "$HOME/.lighthouse/validators"
                "$HOME/lighthouse/validators"
                "$HOME/.local/share/teku/validator/keys"
                "$HOME/lodestar/keystores"
                "$HOME/grandine/validators"
                "$HOME/nimbus/validators"
            )
            ;;
    esac

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        # Find JSON keystores with a pubkey field (EIP-2335)
        while IFS= read -r -d '' f; do
            local pubkey
            pubkey=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('pubkey',''))" "$f" 2>/dev/null || true)
            [[ -n "$pubkey" ]] && echo "$pubkey"
        done < <(find "$dir" -maxdepth 4 -name "*.json" -print0 2>/dev/null)
    done | sort -u
}

# =============================================================================
# BEACON API QUERY
# =============================================================================

# Queries beacon node for one or more validator pubkeys.
# Accepts pubkeys as newline-separated stdin.
# Outputs raw JSON from the beacon API.
query_beacon_validators() {
    local beacon_url="$1"
    shift
    local pubkeys=("$@")

    if [[ ${#pubkeys[@]} -eq 0 ]]; then
        echo '{"data":[]}'
        return
    fi

    # Build comma-separated id list
    local ids
    ids=$(IFS=,; echo "${pubkeys[*]/#/0x}")

    local response
    response=$(curl -sf \
        --max-time 10 \
        "${beacon_url}/eth/v1/beacon/states/head/validators?id=${ids}" \
        2>/dev/null || true)

    if [[ -z "$response" ]]; then
        echo '{"data":[]}'
    else
        echo "$response"
    fi
}

# =============================================================================
# DISPLAY
# =============================================================================

gwei_to_eth() {
    python3 -c "print(f'{int(\"$1\") / 1e9:.6f}')" 2>/dev/null || echo "?"
}

print_table() {
    local data="$1"

    local count
    count=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(len(d.get('data',[])))" "$data" 2>/dev/null || echo 0)

    if [[ "$count" -eq 0 ]]; then
        log_warn "No validators found via beacon API. They may be pending or the node may still be syncing."
        return
    fi

    printf "\n%-12s %-98s %-15s %-15s %s\n" \
        "Index" "Public Key" "Status" "Balance (ETH)" "Eff. Balance (ETH)"
    printf '%s\n' "$(printf '%.0s-' {1..155})"

    python3 - "$data" <<'EOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

for v in data.get("data", []):
    idx   = v.get("index", "?")
    pubk  = v.get("validator", {}).get("pubkey", "?")
    short = pubk[:10] + "..." + pubk[-8:] if len(pubk) > 18 else pubk
    full  = pubk
    status = v.get("status", "?")
    bal    = int(v.get("balance", 0)) / 1e9
    eff    = int(v.get("validator", {}).get("effective_balance", 0)) / 1e9
    print(f"{idx:<12} {full:<98} {status:<15} {bal:<15.6f} {eff:.6f}")
EOF
    printf '%s\n' "$(printf '%.0s-' {1..155})"
    printf "  %d validator(s) found\n\n" "$count"
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
            echo "  Searched in the standard keystore directories."
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

    query_beacon_validators "$beacon_url" "${pubkeys[@]}" > "$tmpfile"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        python3 - "$tmpfile" "$client" "$beacon_url" <<'EOF'
import json, sys
with open(sys.argv[1]) as f:
    raw = json.load(f)
out = {
    "client": sys.argv[2],
    "beacon_url": sys.argv[3],
    "validators": raw.get("data", [])
}
print(json.dumps(out, indent=2))
EOF
    else
        print_table "$tmpfile"
    fi
}

main "$@"
