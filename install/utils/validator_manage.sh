#!/bin/bash

# Eth2 Quick Start — Validator Manager
# Interactive tool for local validator operations: voluntary exits and EIP-7251
# consolidations. Operates only on validators managed by this node.
#
# Usage:
#   ./install/utils/validator_manage.sh            # interactive menu
#   ./install/utils/validator_manage.sh --exit     # go straight to exit flow
#   ./install/utils/validator_manage.sh --consolidate
#   ./install/utils/validator_manage.sh --eip7002-exit
#   ./install/utils/validator_manage.sh --withdraw-change
#
# WARNING: Voluntary exit is IRREVERSIBLE.

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

# EIP-7251 consolidation request contract (mainnet)
CONSOLIDATION_CONTRACT="0x0000BBdDc7CE488642fb579F8B00f3a590007251"
WITHDRAWAL_CONTRACT="0x00000961Ef480Eb55e80D19ad83579A64c007002"

ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --exit)        ACTION="exit" ;;
        --consolidate) ACTION="consolidate" ;;
        --eip7002-exit) ACTION="eip7002_exit" ;;
        --withdraw-change) ACTION="withdraw_change" ;;
        --help|-h)
            cat <<'EOF'
Usage: ./install/utils/validator_manage.sh [options]

Options:
  --exit          Initiate voluntary exit for one or more local validators
  --consolidate   Consolidate two local validators via EIP-7251
  --eip7002-exit  Trigger EIP-7002 exit/withdrawal
  --withdraw-change
                  Switch validator withdrawal credentials (0x00->0x01 and 0x01->0x02)
  --help          Show this help

Without options, an interactive menu is shown.

WARNING: Voluntary exit is permanent and irreversible.
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
    [[ -z "$exec_start" ]] && { echo "unknown"; return; }
    if echo "$exec_start"   | grep -qi "lighthouse"; then echo "lighthouse"
    elif echo "$exec_start" | grep -qi "prysm";      then echo "prysm"
    elif echo "$exec_start" | grep -qi "teku";       then echo "teku"
    elif echo "$exec_start" | grep -qi "lodestar";   then echo "lodestar"
    elif echo "$exec_start" | grep -qi "nimbus";     then echo "nimbus"
    elif echo "$exec_start" | grep -qi "grandine";   then echo "grandine"
    else echo "unknown"
    fi
}

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

# Returns the validator client binary path from the validator systemd service.
get_client_binary() {
    local exec_start
    exec_start=$(systemctl show validator --property=ExecStart --value 2>/dev/null || true)
    echo "$exec_start" | awk '{print $1}' | head -1
}

# =============================================================================
# LOCAL VALIDATOR LIST (delegates to validator_list.sh for correct discovery)
# =============================================================================

# Calls validator_list.sh --json, writes result to $1, prints table to stdout.
# Returns 1 if no local validators found.
load_local_validators() {
    local out_file="$1"

    if [[ ! -x "$SCRIPT_DIR/validator_list.sh" ]]; then
        log_error "validator_list.sh not found or not executable at $SCRIPT_DIR"
        return 1
    fi

    local json
    json=$("$SCRIPT_DIR/validator_list.sh" --json 2>/dev/null) || true

    if [[ -z "$json" ]]; then
        log_warn "No local validators found. Import keys and ensure the beacon node is synced."
        return 1
    fi

    # Write to file before counting — avoids argv length limits with large validator sets.
    echo "$json" > "$out_file"

    local count=0
    count=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(len(d.get('validators', [])))
" "$out_file" 2>/dev/null || echo 0)

    if [[ "$count" -eq 0 ]]; then
        log_warn "No local validators found. Import keys and ensure the beacon node is synced."
        return 1
    fi
    return 0
}

# Renders the validator table from the JSON file written by load_local_validators.
print_local_validators() {
    local data_file="$1"
    python3 - "$data_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
rows = d.get("validators", [])
if not rows:
    print("  (none)")
    sys.exit(0)
hdr = f"  {'Index':<10} {'Public Key':<98} {'Status':<22} Balance (ETH) {'WCred'}"
print()
print(hdr)
print("  " + "-" * (len(hdr) - 2))
for v in rows:
    idx    = v.get("index", "?")
    pubkey = v.get("validator", {}).get("pubkey", "?")
    status = v.get("status", "?")
    bal    = int(v.get("balance", 0)) / 1e9
    cred   = v.get("validator", {}).get("withdrawal_credentials", "") or ""
    wcred  = cred[:4].lower() if cred.startswith("0x") and len(cred) >= 4 else "?"
    print(f"  {idx:<10} {pubkey:<98} {status:<22} {bal:.6f} {wcred}")
print("  " + "-" * (len(hdr) - 2))
print(f"  {len(rows)} validator(s)\n")
PYEOF
}

# =============================================================================
# SHARED HELPERS
# =============================================================================

confirm_destructive() {
    local prompt="$1"
    printf "\n"
    printf "  %b⚠  WARNING: %s%b\n" "${RED}" "$prompt" "${NC}"
    printf "  %bThis action CANNOT be undone.%b\n\n" "${RED}" "${NC}"
    read -rp "  Type 'yes' to confirm: " answer
    [[ "$answer" == "yes" ]]
}

normalize_hex_input() {
    local value="$1"
    value="${value// /}"
    [[ -z "$value" ]] && return 0
    [[ "$value" == 0x* ]] || value="0x${value}"
    printf "%s" "$value"
}

query_system_contract_fee() {
    local contract="$1"
    local el_rpc="$2"
    local response
    local fee_hex="0x0"

    response=$(curl -sf --max-time 5 \
        -X POST "$el_rpc" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"${contract}\",\"data\":\"0x\"},\"latest\"],\"id\":1}") || { echo "0"; return 0; }

    fee_hex=$(printf "%s" "$response" | \
        python3 -c "import json, sys; d = json.load(sys.stdin); print(d.get('result', '0x0'))" 2>/dev/null || true)

    [[ -z "$fee_hex" || "$fee_hex" == "null" ]] && fee_hex="0x0"

    python3 -c "print(int('${fee_hex}', 16))" 2>/dev/null || echo 0
}

get_validator_pubkey() {
    local data_file="$1"
    local selector="$2"

    python3 - "$data_file" "$selector" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    data = json.load(f)
selector = sys.argv[2].strip().lower()

for v in data.get("validators", []):
    index = str(v.get("index", ""))
    pubkey = (v.get("validator", {}).get("pubkey", "") or "").lower()
    if selector == index.lower() or selector == pubkey:
        print(pubkey)
        sys.exit(0)

sys.exit(1)
PY
}

# =============================================================================
# VOLUNTARY EXIT
# =============================================================================

cmd_exit() {
    local client
    client=$(detect_client)
    local beacon_url
    beacon_url=$(detect_beacon_url)
    local bin
    bin=$(get_client_binary)

    printf "\n"
    log_info "=== Voluntary Validator Exit ==="
    printf "  Client : %s\n  Beacon : %s\n\n" "$client" "$beacon_url"

    local tmpfile
    tmpfile=$(mktemp /tmp/vmgr_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT

    load_local_validators "$tmpfile" || return 0
    print_local_validators "$tmpfile"

    printf "  Enter the validator index or pubkey to exit.\n"
    printf "  Separate multiple with spaces. Enter 'all' to exit all local validators.\n\n"
    read -rp "  Selection: " selection

    if [[ -z "$selection" ]]; then
        log_warn "No selection made. Aborting."
        return 0
    fi

    if ! confirm_destructive "Voluntary exit is permanent. Validators cannot re-enter the active set."; then
        log_warn "Aborted by user."
        return 0
    fi

    printf "\n"
    _do_exit "$client" "$beacon_url" "$bin" "$selection"
}

_do_exit() {
    local client="$1"
    local beacon_url="$2"
    local bin="$3"
    local selection="$4"

    case "$client" in
        lighthouse)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Lighthouse binary path."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            local pass_file="$HOME/secrets/pass.txt"
            # Lighthouse 4+: 'lighthouse account validator exit'
            # --pubkeys accepts comma-separated list of 0x-prefixed pubkeys or indices
            if [[ "$selection" == "all" ]]; then
                log_info "Initiating exit for all local validators..."
                "$bin" account validator exit \
                    --beacon-node "$beacon_url" \
                    --no-confirmation \
                    --password-file "$pass_file"
            else
                local pubkey_list
                pubkey_list=$(echo "$selection" | tr ' ' ',')
                log_info "Initiating exit for: $pubkey_list"
                "$bin" account validator exit \
                    --beacon-node "$beacon_url" \
                    --no-confirmation \
                    --password-file "$pass_file" \
                    --pubkeys "$pubkey_list"
            fi
            ;;

        prysm)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Prysm binary path."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            local prysm_dir
            prysm_dir=$(dirname "$bin")
            local pass_file="$HOME/secrets/pass.txt"
            # Prysm: --pubkeys accepts comma-separated 0x-prefixed pubkeys
            local pubkey_args=""
            if [[ "$selection" != "all" ]]; then
                pubkey_args="--pubkeys=$(echo "$selection" | tr ' ' ',')"
            fi
            log_info "Running Prysm voluntary exit..."
            # shellcheck disable=SC2086
            "$bin" validator accounts voluntary-exit \
                --wallet-dir="$prysm_dir/wallet" \
                --wallet-password-file="$pass_file" \
                --beacon-rpc-provider="127.0.0.1:4000" \
                --accept-terms-of-use \
                $pubkey_args
            ;;

        teku)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Teku binary path."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            local validator_keys="$HOME/.local/share/teku/validator"
            log_info "Running Teku voluntary exit..."
            if [[ "$selection" == "all" ]]; then
                "$bin" voluntary-exit \
                    --beacon-node-api-endpoint="$beacon_url" \
                    --validator-keys="$validator_keys/keys:$validator_keys/passwords"
            else
                "$bin" voluntary-exit \
                    --beacon-node-api-endpoint="$beacon_url" \
                    --validator-public-key="$(echo "$selection" | tr ' ' ',')" \
                    --validator-keys="$validator_keys/keys:$validator_keys/passwords"
            fi
            ;;

        lodestar)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Lodestar binary path."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            log_info "Running Lodestar voluntary exit..."
            local pubkey_args=""
            if [[ "$selection" != "all" ]]; then
                pubkey_args="--pubkeys=$(echo "$selection" | tr ' ' ',')"
            fi
            # shellcheck disable=SC2086
            "$bin" validator voluntary-exit \
                --beaconNodes="$beacon_url" \
                --dataDir="$HOME/.local/share/lodestar" \
                $pubkey_args
            ;;

        nimbus)
            # Exits use nimbus_beacon_node, not the validator client.
            # Derive it from the validator service binary path (same build dir), then
            # fall back to a search under the default nimbus home.
            local nimbus_bin=""
            if [[ -n "$bin" ]]; then
                local build_dir
                build_dir=$(dirname "$bin")
                [[ -x "$build_dir/nimbus_beacon_node" ]] && nimbus_bin="$build_dir/nimbus_beacon_node"
            fi
            if [[ -z "$nimbus_bin" ]]; then
                nimbus_bin=$(find "$HOME/nimbus/build" -name "nimbus_beacon_node" -type f 2>/dev/null | head -1 || true)
            fi
            if [[ -z "$nimbus_bin" ]]; then
                log_error "Nimbus beacon node binary not found."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            log_info "Running Nimbus voluntary exit..."
            for sel in $selection; do
                "$nimbus_bin" deposits exit \
                    --rest-url="$beacon_url" \
                    --validator="$sel"
            done
            ;;

        *)
            log_warn "Client '${client}' — showing manual exit instructions."
            _print_manual_exit_instructions "$client" "$beacon_url"
            ;;
    esac
}

_print_manual_exit_instructions() {
    local client="$1"
    local beacon_url="$2"
    printf "\n  Manual exit steps for %s:\n\n" "$client"
    printf "  Option A — ethdo (works with all clients):\n"
    printf "    ethdo validator exit --validator=<index_or_pubkey> \\\\\n"
    printf "      --connection=%s\n\n" "$beacon_url"
    printf "  Install ethdo:  go install github.com/wealdtech/ethdo@latest\n\n"
    printf "  Option B — Beacon API (requires signed VoluntaryExit message):\n"
    printf "    POST %s/eth/v1/beacon/pool/voluntary_exits\n\n" "$beacon_url"
}

# =============================================================================
# EIP-7251 CONSOLIDATION
# =============================================================================

cmd_consolidate() {
    local beacon_url
    beacon_url=$(detect_beacon_url)
    local el_rpc="http://127.0.0.1:8545"

    printf "\n"
    log_info "=== EIP-7251 Validator Consolidation ==="
    printf "\n"
    cat <<'EOF'
  Consolidation merges two validators, moving the source stake into the target.
  After consolidation the source validator exits automatically.

  Prerequisites:
    • Both validators must have 0x01 withdrawal credentials pointing to an
      Ethereum address YOU control (the withdrawal address sends the TX).
    • A dynamic fee is paid to the consolidation contract.

  Contract: 0x0000BBdDc7CE488642fb579F8B00f3a590007251 (mainnet)

EOF

    local tmpfile
    tmpfile=$(mktemp /tmp/vmgr_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT

    load_local_validators "$tmpfile" || return 0
    print_local_validators "$tmpfile"

    printf "  Enter the SOURCE validator pubkey (will be exited):\n"
    read -rp "  Source pubkey (0x...): " src_pubkey
    printf "\n  Enter the TARGET validator pubkey (receives the stake):\n"
    read -rp "  Target pubkey (0x...): " tgt_pubkey
    printf "\n"

    if [[ -z "$src_pubkey" || -z "$tgt_pubkey" ]]; then
        log_warn "Both pubkeys are required. Aborting."
        return 0
    fi

    # Normalise: ensure 0x prefix, strip spaces
    src_pubkey="${src_pubkey// /}"
    tgt_pubkey="${tgt_pubkey// /}"
    [[ "$src_pubkey" != 0x* ]] && src_pubkey="0x${src_pubkey}"
    [[ "$tgt_pubkey" != 0x* ]] && tgt_pubkey="0x${tgt_pubkey}"

    # Query current fee from the consolidation contract (empty calldata returns fee)
    local fee_dec
    fee_dec=$(query_system_contract_fee "$CONSOLIDATION_CONTRACT" "$el_rpc")
    local fee_eth
    fee_eth=$(python3 -c "print(${fee_dec} / 1e18)")

    # Calldata: source_pubkey_bytes (48) + target_pubkey_bytes (48) = 96 bytes total
    local src_hex="${src_pubkey#0x}"
    local tgt_hex="${tgt_pubkey#0x}"
    local calldata="0x${src_hex}${tgt_hex}"

    printf "  Consolidation parameters:\n"
    printf "    Source  : %s\n" "$src_pubkey"
    printf "    Target  : %s\n" "$tgt_pubkey"
    printf "    Contract: %s\n" "$CONSOLIDATION_CONTRACT"
    printf "    Fee     : ~%s ETH (%s wei)\n\n" "$fee_eth" "$fee_dec"
    printf "  Calldata: %s\n\n" "$calldata"

    printf "  Command to run (requires the withdrawal address private key):\n\n"
    printf "    cast send %s \\\\\n" "$CONSOLIDATION_CONTRACT"
    printf "      --value %swei \\\\\n" "$fee_dec"
    printf "      --data %s \\\\\n" "$calldata"
    printf "      --rpc-url %s \\\\\n" "$el_rpc"
    printf "      --private-key <WITHDRAWAL_ADDRESS_PRIVATE_KEY>\n\n"

    if ! command -v cast &>/dev/null; then
        log_warn "'cast' not found. Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
        return 0
    fi

    if ! confirm_destructive "Consolidation permanently exits the source validator."; then
        log_warn "Aborted. Run the cast command above manually when ready."
        return 0
    fi

    read -rsp "  Private key of withdrawal address (hidden): " priv_key
    printf "\n"
    if [[ -z "$priv_key" ]]; then
        log_warn "No private key provided. Aborting."
        return 0
    fi

    log_info "Submitting consolidation transaction..."
    cast send "${CONSOLIDATION_CONTRACT}" \
        --value "${fee_dec}wei" \
        --data "${calldata}" \
        --rpc-url "${el_rpc}" \
        --private-key "${priv_key}"

    log_info "Transaction submitted. Monitor the source validator for a pending exit."
}

# =============================================================================
# EIP-7002 EL-TRIGGERED EXIT/WITHDRAWAL
# =============================================================================

cmd_eip7002_exit() {
    local el_rpc="http://127.0.0.1:8545"
    local amount_hex
    local src_pubkey
    local amount_gwei
    local withdrawal_addr
    local fee_dec
    local fee_eth
    local calldata

    printf "\n"
    log_info "=== EIP-7002 Withdrawal/Exit Trigger ==="
    printf "\n"
    cat <<'EOF'
  This flow submits an EL-triggered withdrawal/exit via the official 7002 contract.

  Request payload format:
    validator_pubkey (48-byte) || amount (8-byte big-endian gwei)

  Amount = 0 indicates full exit.

  Contract: 0x00000961Ef480Eb55e80D19ad83579A64c007002 (mainnet)

EOF

    printf "  Enter the validator pubkey (0x...): "
    read -r src_pubkey
    printf "\n"
    printf "  Enter amount in gwei (0 = full exit): "
    read -r amount_gwei
    printf "\n"
    printf "  Enter the withdrawal address sender (for --from): "
    read -r withdrawal_addr

    src_pubkey=$(normalize_hex_input "$src_pubkey")
    if [[ -z "$src_pubkey" || ! "$src_pubkey" =~ ^0x[0-9A-Fa-f]{96}$ ]]; then
        log_warn "Invalid source pubkey format. Expected 0x + 96 hex chars."
        return 0
    fi
    if [[ -z "$withdrawal_addr" || ! "$withdrawal_addr" =~ ^0x[0-9A-Fa-f]{40}$ ]]; then
        log_warn "Invalid withdrawal address."
        return 0
    fi
    if [[ -z "$amount_gwei" ]]; then
        amount_gwei=0
    fi
    if [[ ! "$amount_gwei" =~ ^[0-9]+$ ]]; then
        log_warn "Amount must be a decimal non-negative integer (gwei)."
        return 0
    fi

    amount_hex=$(python3 -c "
import sys
amount = int(sys.argv[1])
if amount < 0 or amount >= (1 << 64):
    raise ValueError
print(f'{amount:016x}')
" "$amount_gwei" 2>/dev/null) || {
        log_warn "Amount must be a u64 gwei value (0 <= amount < 2^64)."
        return 0
    }

    fee_dec=$(query_system_contract_fee "$WITHDRAWAL_CONTRACT" "$el_rpc")
    fee_eth=$(python3 -c "print(${fee_dec} / 1e18)")
    calldata="0x${src_pubkey#0x}${amount_hex}"

    printf "\n  Command to run:\n\n"
    printf "    cast send %s \\\n" "$WITHDRAWAL_CONTRACT"
    printf "      --value %swei \\\n" "$fee_dec"
    printf "      --data %s \\\n" "$calldata"
    printf "      --rpc-url %s \\\n" "$el_rpc"
    printf "      --from %s\n\n" "$withdrawal_addr"
    printf "  Estimated fee: ~%s ETH (%s wei)\n\n" "$fee_eth" "$fee_dec"

    if ! command -v cast &>/dev/null; then
        log_warn "'cast' not found. Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
        return 0
    fi

    if ! confirm_destructive "This action submits an irreversible EL-triggered withdrawal/exit."; then
        log_warn "Aborted."
        return 0
    fi

    cast send "$WITHDRAWAL_CONTRACT" \
        --value "${fee_dec}wei" \
        --data "${calldata}" \
        --rpc-url "$el_rpc" \
        --from "$withdrawal_addr"
}

# =============================================================================
# WITHDRAWAL-CREDENTIAL CHANGE
# =============================================================================

cmd_withdraw_change() {
    local beacon_url
    beacon_url=$(detect_beacon_url)
    local el_rpc="http://127.0.0.1:8545"
    local selection
    local flow

    printf "\n"
    log_info "=== Withdrawal Credential Change ==="
    printf "\n"
    cat <<'EOF'
  Select one validator and perform one of:
    1) 0x00 -> 0x01 (BLS-to-execution credential change via ethdo)
    2) 0x01 -> 0x02 (self-consolidation, source == target)

EOF

    local tmpfile
    tmpfile=$(mktemp /tmp/vmgr_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT

    load_local_validators "$tmpfile" || return 0
    print_local_validators "$tmpfile"

    printf "  Enter validator index or pubkey to update:\n"
    read -rp "  Selection: " selection
    if [[ -z "$selection" ]]; then
        log_warn "No selection made. Aborting."
        return 0
    fi

    printf "\n  Choose flow:\n"
    printf "  [1] 0x00 -> 0x01 (ethdo credentials set)\n"
    printf "  [2] 0x01 -> 0x02 (self-consolidation)\n"
    read -rp "  Choice: " flow

    case "$flow" in
        1)
            local withdrawal_addr
            printf "\n  Enter new withdrawal address (0x...): "
            read -rp "" withdrawal_addr
            if [[ ! "$withdrawal_addr" =~ ^0x[0-9A-Fa-f]{40}$ ]]; then
                log_warn "Invalid withdrawal address."
                return 0
            fi
            if ! command -v ethdo &>/dev/null; then
                log_warn "'ethdo' not found. Install with: go install github.com/wealdtech/ethdo@latest"
                return 0
            fi

            printf "\n  Command to run:\n\n"
            printf "    ethdo validator credentials set --validator %s --withdrawal-address %s --connection %s\n\n" \
                "$selection" "$withdrawal_addr" "$beacon_url"

            if ! confirm_destructive "BLS-to-execution credential update cannot be reverted automatically."; then
                log_warn "Aborted."
                return 0
            fi

            log_info "Submitting withdrawal credentials update..."
            ethdo validator credentials set \
                --validator "$selection" \
                --withdrawal-address "$withdrawal_addr" \
                --connection "$beacon_url"
            ;;
        2)
            local source_pubkey
            local fee_dec
            local fee_eth
            local calldata
            local priv_key

            if [[ "$selection" == [0-9]* ]]; then
                source_pubkey=$(get_validator_pubkey "$tmpfile" "$selection") || {
                    log_warn "Could not resolve validator pubkey from selection: $selection"
                    return 0
                }
            else
                source_pubkey=$(normalize_hex_input "$selection")
            fi
            if [[ -z "$source_pubkey" || ! "$source_pubkey" =~ ^0x[0-9A-Fa-f]{96}$ ]]; then
                log_warn "Source pubkey could not be normalized to 0x + 96 hex chars."
                return 0
            fi

            fee_dec=$(query_system_contract_fee "$CONSOLIDATION_CONTRACT" "$el_rpc")
            fee_eth=$(python3 -c "print(${fee_dec} / 1e18)")
            calldata="0x${source_pubkey#0x}${source_pubkey#0x}"

            printf "\n  Self-consolidation command to run (source == target):\n\n"
            printf "    cast send %s \\\n" "$CONSOLIDATION_CONTRACT"
            printf "      --value %swei \\\n" "$fee_dec"
            printf "      --data %s \\\n" "$calldata"
            printf "      --rpc-url %s \\\n" "$el_rpc"
            printf "      --private-key <WITHDRAWAL_ADDRESS_PRIVATE_KEY>\n\n"
            printf "  Estimated fee: ~%s ETH (%s wei)\n\n" "$fee_eth" "$fee_dec"

            if ! command -v cast &>/dev/null; then
                log_warn "'cast' not found. Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
                return 0
            fi

            if ! confirm_destructive "Self-consolidation upgrades 0x01 withdrawal credentials to 0x02 and exits the source validator."; then
                log_warn "Aborted."
                return 0
            fi

            read -rsp "  Private key of withdrawal address (hidden): " priv_key
            printf "\n"
            if [[ -z "$priv_key" ]]; then
                log_warn "No private key provided. Aborting."
                return 0
            fi

            log_info "Submitting self-consolidation transaction..."
            cast send "$CONSOLIDATION_CONTRACT" \
                --value "${fee_dec}wei" \
                --data "${calldata}" \
                --rpc-url "$el_rpc" \
                --private-key "$priv_key"
            ;;
        *)
            log_warn "Invalid choice: $flow"
            return 0
            ;;
    esac
}

# =============================================================================
# INTERACTIVE MENU
# =============================================================================

show_menu() {
    local client
    client=$(detect_client)
    local beacon_url
    beacon_url=$(detect_beacon_url)
    local vc_status
    vc_status=$(systemctl is-active validator 2>/dev/null || echo "inactive")

    printf "\n"
    printf "╔══════════════════════════════════════════════════════╗\n"
    printf "║         Eth2 Quick Start — Validator Manager         ║\n"
    printf "╚══════════════════════════════════════════════════════╝\n\n"
    printf "  Client    : %s\n" "$client"
    printf "  Validator : %s\n" "$vc_status"
    printf "  Beacon    : %s\n\n" "$beacon_url"
    printf "  [1] List local validators\n"
    printf "  [2] Voluntary exit  (irreversible)\n"
    printf "  [3] Consolidate validators  (EIP-7251)\n"
    printf "  [4] EIP-7002 exit / withdrawal\n"
    printf "  [5] Withdrawal credential change\n"
    printf "  [q] Quit\n\n"
    read -rp "  Choice: " choice

    case "$choice" in
        1) "$SCRIPT_DIR/validator_list.sh" ;;
        2) cmd_exit ;;
        3) cmd_consolidate ;;
        4) cmd_eip7002_exit ;;
        5) cmd_withdraw_change ;;
        q|Q|quit) printf "  Bye.\n"; exit 0 ;;
        *) log_warn "Invalid choice: ${choice}"; show_menu ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    case "$ACTION" in
        exit)        cmd_exit ;;
        consolidate) cmd_consolidate ;;
        eip7002_exit) cmd_eip7002_exit ;;
        withdraw_change) cmd_withdraw_change ;;
        "")          show_menu ;;
    esac
}

main "$@"
