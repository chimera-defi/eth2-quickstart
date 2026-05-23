#!/bin/bash

# Eth2 Quick Start — Validator Manager
# Interactive tool for validator operations: voluntary exits and EIP-7251 consolidations.
#
# Usage:
#   ./install/utils/validator_manage.sh [--exit | --consolidate] [--json]
#   ./install/utils/validator_manage.sh          # interactive menu
#
# WARNING: Voluntary exit is IRREVERSIBLE. Exited validators cannot re-enter the active set.

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
CONSOLIDATION_CONTRACT="0x00431F263cE400f4455c2dCf564e53007Ca4bbBb"

ACTION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --exit)        ACTION="exit" ;;
        --consolidate) ACTION="consolidate" ;;
        --help|-h)
            cat <<'EOF'
Usage: ./install/utils/validator_manage.sh [options]

Options:
  --exit          Initiate voluntary exit for one or more validators
  --consolidate   Consolidate two validators via EIP-7251
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
# HELPERS (shared with validator_list.sh logic, inlined to keep scripts standalone)
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

get_client_binary() {
    local client="$1"
    local exec_start
    exec_start=$(systemctl show validator --property=ExecStart --value 2>/dev/null || true)
    case "$client" in
        lighthouse)
            # ExecStart starts with the binary path
            echo "$exec_start" | awk '{print $1}' | head -1
            ;;
        prysm)
            echo "$exec_start" | awk '{print $1}' | head -1
            ;;
        teku)
            echo "$exec_start" | awk '{print $1}' | head -1
            ;;
        lodestar)
            echo "$exec_start" | awk '{print $1}' | head -1
            ;;
        *)
            echo ""
            ;;
    esac
}

# Fetches active validators from beacon node API, returns JSON array.
fetch_validators() {
    local beacon_url="$1"
    local response
    response=$(curl -sf --max-time 10 \
        "${beacon_url}/eth/v1/beacon/states/head/validators?status=active_ongoing" \
        2>/dev/null || true)
    if [[ -z "$response" ]]; then
        # Try without status filter as fallback
        response=$(curl -sf --max-time 10 \
            "${beacon_url}/eth/v1/beacon/states/head/validators" \
            2>/dev/null || true)
    fi
    echo "${response:-{\"data\":[]}}"
}

list_validators_interactive() {
    local beacon_url="$1"

    log_info "Fetching validators from beacon node..."

    local tmpfile
    tmpfile=$(mktemp /tmp/vmgr_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT

    fetch_validators "$beacon_url" > "$tmpfile"

    local count
    count=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print(len(d.get('data', [])))
" "$tmpfile" 2>/dev/null || echo 0)

    if [[ "$count" -eq 0 ]]; then
        log_warn "No active validators found on this node."
        return 1
    fi

    echo ""
    printf "%-6s %-98s %-20s %s\n" "Index" "Public Key" "Status" "Balance (ETH)"
    printf '%s\n' "$(printf '%.0s-' {1..140})"

    python3 - "$tmpfile" <<'EOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for v in data.get("data", []):
    idx    = v.get("index", "?")
    pubkey = v.get("validator", {}).get("pubkey", "?")
    status = v.get("status", "?")
    bal    = int(v.get("balance", 0)) / 1e9
    print(f"{idx:<6} {pubkey:<98} {status:<20} {bal:.6f}")
EOF
    printf '%s\n' "$(printf '%.0s-' {1..140})"
    printf "  %s active validator(s)\n\n" "$count"

    echo "$tmpfile"  # caller can read this file if needed
}

confirm_destructive() {
    local prompt="$1"
    echo ""
    echo -e "  ${RED}⚠  WARNING: ${prompt}${NC}"
    echo -e "  ${RED}   This action CANNOT be undone.${NC}"
    echo ""
    read -rp "  Type 'yes' to confirm: " answer
    [[ "$answer" == "yes" ]]
}

# =============================================================================
# VOLUNTARY EXIT
# =============================================================================

cmd_exit() {
    local client
    client=$(detect_client)
    local beacon_url
    beacon_url=$(detect_beacon_url)

    echo ""
    log_info "=== Voluntary Validator Exit ==="
    echo ""
    echo "  Client   : ${client}"
    echo "  Beacon   : ${beacon_url}"
    echo ""

    list_validators_interactive "$beacon_url" || return 1

    echo "  Enter validator indices or pubkeys to exit."
    echo "  Separate multiple with spaces. Enter 'all' to exit all."
    echo ""
    read -rp "  Selection: " selection

    if [[ -z "$selection" ]]; then
        log_warn "No selection made. Aborting."
        return 0
    fi

    if ! confirm_destructive "Voluntary exit is permanent. Validators cannot re-enter the active set."; then
        log_warn "Aborted by user."
        return 0
    fi

    echo ""
    _do_exit "$client" "$beacon_url" "$selection"
}

_do_exit() {
    local client="$1"
    local beacon_url="$2"
    local selection="$3"

    local bin
    bin=$(get_client_binary "$client")

    case "$client" in
        lighthouse)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Lighthouse binary path."
                return 1
            fi
            local wallet_dir
            wallet_dir=$(dirname "$bin")
            local pass_file="$HOME/secrets/pass.txt"

            if [[ "$selection" == "all" ]]; then
                log_info "Initiating exit for all validators..."
                "$bin" account validator exit \
                    --beacon-node "$beacon_url" \
                    --datadir "$wallet_dir" \
                    --password-file "$pass_file" \
                    --no-confirmation
            else
                for sel in $selection; do
                    log_info "Exiting validator: $sel"
                    "$bin" account validator exit \
                        --beacon-node "$beacon_url" \
                        --datadir "$wallet_dir" \
                        --password-file "$pass_file" \
                        --no-confirmation \
                        --pubkey "$sel" 2>/dev/null || \
                    "$bin" account validator exit \
                        --beacon-node "$beacon_url" \
                        --datadir "$wallet_dir" \
                        --password-file "$pass_file" \
                        --no-confirmation
                done
            fi
            ;;

        prysm)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Prysm binary path."
                return 1
            fi
            local prysm_dir
            prysm_dir=$(dirname "$bin")
            local pass_file="$HOME/secrets/pass.txt"
            log_info "Running Prysm voluntary exit..."
            "$bin" validator accounts voluntary-exit \
                --wallet-dir="$prysm_dir/wallet" \
                --wallet-password-file="$pass_file" \
                --beacon-rpc-provider="127.0.0.1:4000" \
                --accept-terms-of-use
            ;;

        teku)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Teku binary path."
                return 1
            fi
            local validator_data="$HOME/.local/share/teku/validator"
            log_info "Running Teku voluntary exit..."
            "$bin" voluntary-exit \
                --beacon-node-api-endpoint="$beacon_url" \
                --validator-keys="$validator_data/keys:$validator_data/passwords"
            ;;

        lodestar)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Lodestar binary path."
                return 1
            fi
            log_info "Running Lodestar voluntary exit..."
            "$bin" validator voluntary-exit \
                --beaconNodes="$beacon_url" \
                --dataDir="$HOME/lodestar"
            ;;

        nimbus)
            log_info "Running Nimbus voluntary exit..."
            local nimbus_bin
            nimbus_bin=$(command -v nimbus_beacon_node 2>/dev/null || \
                         find "$HOME/nimbus" -name "nimbus_beacon_node" -type f 2>/dev/null | head -1 || true)
            if [[ -z "$nimbus_bin" ]]; then
                log_error "Nimbus binary not found."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            "$nimbus_bin" deposits exit \
                --rest-url="$beacon_url" \
                --validator="$selection"
            ;;

        grandine)
            # Grandine exit via keymanager API (EIP-3030 DELETE /keystores triggers exit)
            log_warn "Grandine does not expose a standalone exit CLI."
            _print_manual_exit_instructions "$client" "$beacon_url"
            ;;

        *)
            log_warn "Unknown client '${client}'. Showing manual instructions."
            _print_manual_exit_instructions "$client" "$beacon_url"
            ;;
    esac
}

_print_manual_exit_instructions() {
    local client="$1"
    local beacon_url="$2"
    echo ""
    echo "  Manual exit steps for ${client}:"
    echo ""
    echo "  1. Query your validator index:"
    echo "     curl -s '${beacon_url}/eth/v1/beacon/states/head/validators?status=active' | python3 -m json.tool"
    echo ""
    echo "  2. Sign and broadcast a voluntary exit via the keymanager API:"
    echo "     POST ${beacon_url}/eth/v1/beacon/pool/voluntary_exits"
    echo "     (Requires a signed VoluntaryExit message — use your client's CLI or ethdo)"
    echo ""
    echo "  3. Using ethdo (universal tool):"
    echo "     ethdo validator exit --validator=<index_or_pubkey> --connection=${beacon_url} --passphrase=<wallet_passphrase>"
    echo ""
}

# =============================================================================
# EIP-7251 CONSOLIDATION
# =============================================================================

cmd_consolidate() {
    local beacon_url
    beacon_url=$(detect_beacon_url)

    echo ""
    log_info "=== EIP-7251 Validator Consolidation ==="
    echo ""
    cat <<'EOF'
  Consolidation merges two validators into one, combining their balances.
  The target validator will receive the source validator's stake.

  Prerequisites:
    • Both validators must have 0x01 withdrawal credentials pointing to an
      Ethereum address you control (the "withdrawal address").
    • The withdrawal address submits the consolidation transaction.
    • A dynamic fee must be paid to the consolidation contract.
    • After consolidation, the source validator is exited automatically.

  Contract: 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb (mainnet)

EOF

    list_validators_interactive "$beacon_url" || return 1

    echo "  Enter the SOURCE validator pubkey (the one to be merged and exited):"
    read -rp "  Source pubkey (0x...): " src_pubkey
    echo ""
    echo "  Enter the TARGET validator pubkey (the one that will receive the stake):"
    read -rp "  Target pubkey (0x...): " tgt_pubkey
    echo ""

    if [[ -z "$src_pubkey" || -z "$tgt_pubkey" ]]; then
        log_warn "Both pubkeys are required. Aborting."
        return 0
    fi

    # Normalize: ensure 0x prefix
    [[ "$src_pubkey" != 0x* ]] && src_pubkey="0x${src_pubkey}"
    [[ "$tgt_pubkey" != 0x* ]] && tgt_pubkey="0x${tgt_pubkey}"

    # Query current fee from consolidation contract
    local fee_hex=""
    local el_rpc="http://127.0.0.1:8545"
    fee_hex=$(curl -sf --max-time 5 \
        -X POST "$el_rpc" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"'"${CONSOLIDATION_CONTRACT}"'","data":"0x95600e7e"},"latest"],"id":1}' \
        2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result','0x0'))" 2>/dev/null || true)

    local fee_dec=0
    if [[ -n "$fee_hex" && "$fee_hex" != "0x" ]]; then
        fee_dec=$(python3 -c "print(int('${fee_hex}', 16))" 2>/dev/null || echo 0)
    fi
    local fee_eth
    fee_eth=$(python3 -c "print(f'{${fee_dec} / 1e18:.8f}')" 2>/dev/null || echo "unknown")

    echo "  Consolidation parameters:"
    echo "    Source pubkey : ${src_pubkey}"
    echo "    Target pubkey : ${tgt_pubkey}"
    echo "    Contract      : ${CONSOLIDATION_CONTRACT}"
    echo "    Required fee  : ~${fee_eth} ETH (${fee_dec} wei)"
    echo ""

    # Build the calldata: source_pubkey_bytes (48) + target_pubkey_bytes (48) = 96 bytes
    local src_hex="${src_pubkey#0x}"
    local tgt_hex="${tgt_pubkey#0x}"
    local calldata="0x${src_hex}${tgt_hex}"

    echo "  Transaction calldata:"
    echo "    ${calldata}"
    echo ""

    if command -v cast &>/dev/null; then
        echo "  Ready-to-run cast command (requires --private-key of the withdrawal address):"
        echo ""
        echo "    cast send ${CONSOLIDATION_CONTRACT} \\"
        echo "      --value ${fee_dec}wei \\"
        echo "      --data ${calldata} \\"
        echo "      --rpc-url ${el_rpc} \\"
        echo "      --private-key <YOUR_WITHDRAWAL_ADDRESS_PRIVATE_KEY>"
        echo ""
        echo "  Or, if using a hardware wallet via cast:"
        echo "    cast send ${CONSOLIDATION_CONTRACT} \\"
        echo "      --value ${fee_dec}wei \\"
        echo "      --data ${calldata} \\"
        echo "      --rpc-url ${el_rpc} \\"
        echo "      --ledger"
        echo ""

        if ! confirm_destructive "Consolidation permanently exits the source validator. Proceed with cast send?"; then
            log_warn "Aborted. Run the cast command above manually when ready."
            return 0
        fi

        read -rsp "  Private key of withdrawal address (input hidden): " priv_key
        echo ""
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

        log_info "Transaction submitted. Monitor the source validator status for an exit."
    else
        log_warn "'cast' (Foundry) is not installed. Run the transaction manually:"
        echo ""
        echo "  Install Foundry:  curl -L https://foundry.paradigm.xyz | bash && foundryup"
        echo ""
        echo "  Then run:"
        echo "    cast send ${CONSOLIDATION_CONTRACT} \\"
        echo "      --value ${fee_dec}wei \\"
        echo "      --data ${calldata} \\"
        echo "      --rpc-url ${el_rpc} \\"
        echo "      --private-key <YOUR_WITHDRAWAL_ADDRESS_PRIVATE_KEY>"
        echo ""
    fi
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

    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         Eth2 Quick Start — Validator Manager         ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    printf "  Client    : %s\n" "$client"
    printf "  Validator : %s\n" "$vc_status"
    printf "  Beacon    : %s\n" "$beacon_url"
    echo ""
    echo "  [1] List active validators"
    echo "  [2] Voluntary exit (irreversible)"
    echo "  [3] Consolidate validators (EIP-7251)"
    echo "  [q] Quit"
    echo ""
    read -rp "  Choice: " choice

    case "$choice" in
        1)
            "$SCRIPT_DIR/validator_list.sh"
            ;;
        2)
            cmd_exit
            ;;
        3)
            cmd_consolidate
            ;;
        q|Q|quit|exit)
            echo "  Bye."
            exit 0
            ;;
        *)
            log_warn "Invalid choice: ${choice}"
            show_menu
            ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    case "$ACTION" in
        exit)
            cmd_exit
            ;;
        consolidate)
            cmd_consolidate
            ;;
        "")
            show_menu
            ;;
    esac
}

main "$@"
