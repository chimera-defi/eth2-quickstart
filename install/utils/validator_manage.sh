#!/bin/bash

# Eth2 Quick Start — Validator Manager
# Interactive tool for local validator operations: voluntary exits and EIP-7251
# consolidations. Operates only on validators managed by this node.
#
# Usage:
#   ./install/utils/validator_manage.sh            # interactive menu
#   ./install/utils/validator_manage.sh --exit     # go straight to exit flow
#   ./install/utils/validator_manage.sh --consolidate
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
DEFAULT_CONSOLIDATION_CONTRACT_MAINNET="0x00431F263cE400f4455c2dCf564e53007Ca4bbBb"
CONSOLIDATION_CHAIN="${CONSOLIDATION_CHAIN:-${ETH_NETWORK:-mainnet}}"
if [[ -z "${CONSOLIDATION_CONTRACT:-}" && "${CONSOLIDATION_CHAIN,,}" == "mainnet" ]]; then
    CONSOLIDATION_CONTRACT="$DEFAULT_CONSOLIDATION_CONTRACT_MAINNET"
fi

ACTION=""
CONSOLIDATE_DRY_RUN=false

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --exit)        ACTION="exit" ;;
            --consolidate) ACTION="consolidate" ;;
            --dry-run)     CONSOLIDATE_DRY_RUN=true ;;
            --help|-h)
                cat <<'EOF'
Usage: ./install/utils/validator_manage.sh [options]

Options:
  --exit          Initiate voluntary exit for one or more local validators
  --consolidate   Consolidate two local validators via EIP-7251
  --dry-run       Preview consolidation without importing keys or sending TXs
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
fi

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

resolve_prysm_beacon_rpc_provider() {
    local beacon_url="$1"

    if [[ -n "${PRYSM_BEACON_RPC_PROVIDER:-}" ]]; then
        printf '%s\n' "$PRYSM_BEACON_RPC_PROVIDER"
        return 0
    fi

    local host_port="${beacon_url#*://}"
    host_port="${host_port%%/*}"
    local host="${host_port%:*}"
    if [[ "$host" == "$host_port" ]]; then
        host="127.0.0.1"
    fi

    printf '%s:4000\n' "$host"
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
    idx = v.get("index", "?")
    pubkey = v.get("validator", {}).get("pubkey", "?")
    status = v.get("status", "?")
    bal = int(v.get("balance", 0)) / 1e9
    cred = v.get("validator", {}).get("withdrawal_credentials", "") or ""
    wcred = cred[:4].lower() if cred.startswith("0x") and len(cred) >= 4 else "?"
    print(f"  {idx:<10} {pubkey:<98} {status:<22} {bal:.6f} {wcred}")
print("  " + "-" * (len(hdr) - 2))
print(f"  {len(rows)} validator(s)\n")
PYEOF
}

validate_consolidation_selection() {
    local data_file="$1"
    local source_pubkey="$2"
    local target_pubkey="$3"

    python3 - "$data_file" "$source_pubkey" "$target_pubkey" <<'PYEOF'
import json, sys

data_file, source_pubkey, target_pubkey = sys.argv[1:4]
source_pubkey = source_pubkey.strip().lower()
target_pubkey = target_pubkey.strip().lower()
if not source_pubkey.startswith('0x'):
    source_pubkey = '0x' + source_pubkey
if not target_pubkey.startswith('0x'):
    target_pubkey = '0x' + target_pubkey

with open(data_file) as fh:
    raw = json.load(fh)
rows = raw.get('validators', [])
inventory = set()
for row in rows:
    pubkey = str(row.get('validator', {}).get('pubkey', '')).strip().lower()
    if pubkey:
        inventory.add(pubkey if pubkey.startswith('0x') else '0x' + pubkey)

errors = []
if source_pubkey == target_pubkey:
    errors.append('Source and target pubkeys must be different.')
if source_pubkey not in inventory:
    errors.append(f'Source pubkey not found in local inventory: {source_pubkey}')
if target_pubkey not in inventory:
    errors.append(f'Target pubkey not found in local inventory: {target_pubkey}')

if errors:
    for error in errors:
        sys.stderr.write(error + '\n')
    sys.exit(1)
PYEOF
}

resolve_selection_to_pubkeys() {
    local data_file="$1"
    local selection="$2"

    python3 - "$data_file" "$selection" <<'PYEOF'
import json, sys

data_file, selection = sys.argv[1:3]
with open(data_file) as fh:
    raw = json.load(fh)
rows = raw.get('validators', [])
by_index = {}
by_pubkey = {}
ordered = []
for row in rows:
    idx = str(row.get('index', '')).strip()
    pubkey = str(row.get('validator', {}).get('pubkey', '')).strip()
    if pubkey:
        normalized = pubkey if pubkey.startswith('0x') else f'0x{pubkey}'
        by_pubkey[normalized.lower()] = normalized
        ordered.append(normalized)
    if idx and idx not in ('None', '?') and pubkey:
        by_index[idx] = by_pubkey[normalized.lower()]

sel = selection.strip()
if sel.lower() == 'all':
    print(','.join(ordered))
    sys.exit(0)

items = [item for item in sel.replace(',', ' ').split() if item]
resolved = []
seen = set()
missing = []
for item in items:
    pubkey = by_index.get(item)
    if pubkey is None:
        pubkey = by_pubkey.get(item.lower())
    if pubkey is None:
        missing.append(item)
        continue
    key = pubkey.lower()
    if key not in seen:
        seen.add(key)
        resolved.append(pubkey)

if missing:
    sys.stderr.write('Unknown validator selection token(s): %s\n' % ', '.join(missing))
    sys.stderr.write('Use the displayed index or pubkey for a local validator.\n')
    sys.exit(1)

print(','.join(resolved))
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

    local resolved_pubkeys
    if ! resolved_pubkeys=$(resolve_selection_to_pubkeys "$tmpfile" "$selection"); then
        return 1
    fi
    if [[ -z "$resolved_pubkeys" ]]; then
        log_warn "No validators resolved from the selected input. Aborting."
        return 0
    fi

    if ! confirm_destructive "Voluntary exit is permanent. Validators cannot re-enter the active set."; then
        log_warn "Aborted by user."
        return 0
    fi

    printf "\n"
    _do_exit "$client" "$beacon_url" "$bin" "$resolved_pubkeys"
}

_do_exit() {
    local client="$1"
    local beacon_url="$2"
    local bin="$3"
    local pubkey_csv="$4"

    if [[ -z "$pubkey_csv" ]]; then
        log_error "No resolved validator pubkeys were provided."
        return 1
    fi

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
            log_info "Initiating exit for: $pubkey_csv"
            "$bin" account validator exit                 --beacon-node "$beacon_url"                 --no-confirmation                 --password-file "$pass_file"                 --pubkeys "$pubkey_csv"
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
            local prysm_beacon_rpc_provider
            prysm_beacon_rpc_provider=$(resolve_prysm_beacon_rpc_provider "$beacon_url")
            log_info "Running Prysm voluntary exit..."
            # shellcheck disable=SC2086
            "$bin" validator accounts voluntary-exit                 --wallet-dir="$prysm_dir/wallet"                 --wallet-password-file="$pass_file"                 --beacon-rpc-provider="$prysm_beacon_rpc_provider"                 --accept-terms-of-use                 --pubkeys="$pubkey_csv"
            ;;

        teku)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Teku binary path."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            local validator_keys="$HOME/.local/share/teku/validator"
            log_info "Running Teku voluntary exit..."
            "$bin" voluntary-exit                 --beacon-node-api-endpoint="$beacon_url"                 --validator-public-key="$pubkey_csv"                 --validator-keys="$validator_keys/keys:$validator_keys/passwords"
            ;;

        lodestar)
            if [[ -z "$bin" ]]; then
                log_error "Could not determine Lodestar binary path."
                _print_manual_exit_instructions "$client" "$beacon_url"
                return 1
            fi
            log_info "Running Lodestar voluntary exit..."
            # shellcheck disable=SC2086
            "$bin" validator voluntary-exit                 --beaconNodes="$beacon_url"                 --dataDir="$HOME/.local/share/lodestar"                 --pubkeys="$pubkey_csv"
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
            local sel
            IFS=',' read -r -a pubkeys <<< "$pubkey_csv"
            for sel in "${pubkeys[@]}"; do
                [[ -n "$sel" ]] || continue
                "$nimbus_bin" deposits exit                     --rest-url="$beacon_url"                     --validator="$sel"
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

resolve_consolidation_contract() {
    local contract="${CONSOLIDATION_CONTRACT:-}"
    if [[ -n "$contract" ]]; then
        printf '%s\n' "$contract"
        return 0
    fi

    if [[ "${CONSOLIDATION_CHAIN,,}" == "mainnet" ]]; then
        printf '%s\n' "$DEFAULT_CONSOLIDATION_CONTRACT_MAINNET"
        return 0
    fi

    log_error "No consolidation contract is configured for chain '${CONSOLIDATION_CHAIN}'. Set CONSOLIDATION_CONTRACT in config/user_config.env or exports.sh before using a non-mainnet network."
    return 1
}

query_execution_chain_id_hex() {
    local el_rpc="$1"
    curl -sf --max-time 5         -X POST "$el_rpc"         -H "Content-Type: application/json"         -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'         2>/dev/null | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('result', '0x0'))
except Exception:
    print('0x0')
"
}

prepare_consolidation_signer() {
    local priv_key="$1"
    local keystore_dir="$2"
    local password_file="$3"

    if ! command -v cast &>/dev/null; then
        log_warn "'cast' not found. Install Foundry: curl -L https://foundry.paradigm.xyz | bash && foundryup"
        return 1
    fi

    local wallet_password
    wallet_password=$(python3 -c "import secrets; print(secrets.token_hex(16))")

    local account_name
    account_name="consolidation-$(date +%s)-$$"

    if ! printf '%s\n%s\n' "$priv_key" "$wallet_password" | cast wallet import --interactive --keystore-dir "$keystore_dir" "$account_name" >/dev/null; then
        log_error "Failed to import the withdrawal key into a temporary keystore."
        return 1
    fi

    printf '%s' "$wallet_password" > "$password_file"

    local keystore_path
    keystore_path=$(find "$keystore_dir" -maxdepth 1 -type f -name '*.json' -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
    if [[ -z "$keystore_path" ]]; then
        log_error "Temporary keystore import completed but no keystore file was found."
        return 1
    fi

    printf '%s\n' "$keystore_path"
}

cmd_consolidate() {
    local beacon_url
    beacon_url=$(detect_beacon_url)
    local el_rpc="http://127.0.0.1:8545"
    local consolidation_contract
    consolidation_contract=$(resolve_consolidation_contract) || return 1

    printf "
"
    log_info "=== EIP-7251 Validator Consolidation ==="
    printf "
"
    cat <<EOF
  Consolidation merges two validators, moving the source stake into the target.
  After consolidation the source validator exits automatically.

  Prerequisites:
    • Both validators must have 0x01 withdrawal credentials pointing to an
      Ethereum address YOU control (the withdrawal address sends the TX).
    • A dynamic fee is paid to the consolidation contract.
    • The withdrawal key is imported into a temporary keystore so it does not
      appear in the send command line.

  Chain    : ${CONSOLIDATION_CHAIN}
  Contract : ${consolidation_contract}

EOF

    local tmpfile
    tmpfile=$(mktemp /tmp/vmgr_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$tmpfile'" EXIT

    load_local_validators "$tmpfile" || return 0
    print_local_validators "$tmpfile"

    printf "  Enter the SOURCE validator pubkey (will be exited):
"
    read -rp "  Source pubkey (0x...): " src_pubkey
    printf "
  Enter the TARGET validator pubkey (receives the stake):
"
    read -rp "  Target pubkey (0x...): " tgt_pubkey
    printf "
"

    if [[ -z "$src_pubkey" || -z "$tgt_pubkey" ]]; then
        log_warn "Both pubkeys are required. Aborting."
        return 0
    fi

    # Normalise: ensure 0x prefix, strip spaces
    src_pubkey="${src_pubkey// /}"
    tgt_pubkey="${tgt_pubkey// /}"
    [[ "$src_pubkey" != 0x* ]] && src_pubkey="0x${src_pubkey}"
    [[ "$tgt_pubkey" != 0x* ]] && tgt_pubkey="0x${tgt_pubkey}"

    if ! validate_consolidation_selection "$tmpfile" "$src_pubkey" "$tgt_pubkey"; then
        return 1
    fi

    local chain_id_hex
    chain_id_hex=$(query_execution_chain_id_hex "$el_rpc") || chain_id_hex="0x0"
    local chain_id_dec
    chain_id_dec=$(python3 -c "print(int('${chain_id_hex}', 16))" 2>/dev/null || echo 0)

    if [[ "$consolidation_contract" == "$DEFAULT_CONSOLIDATION_CONTRACT_MAINNET" && "$chain_id_dec" -ne 1 ]]; then
        log_error "Mainnet consolidation contract requires chainId 1, but the connected execution layer reported chainId ${chain_id_dec}. Set CONSOLIDATION_CHAIN/CONSOLIDATION_CONTRACT explicitly before using a non-mainnet network."
        return 1
    fi

    log_info "Connected execution chainId: ${chain_id_dec}"

    # Query current fee from the consolidation contract (selector: fee() = 0x95600e7e)
    local fee_hex
    local fee_body
    fee_body=$(cat <<EOF
{"jsonrpc":"2.0","method":"eth_call","params":[{"to":"${consolidation_contract}","data":"0x95600e7e"},"latest"],"id":1}
EOF
)
    fee_hex=$(curl -sf --max-time 5         -X POST "$el_rpc"         -H "Content-Type: application/json"         -d "$fee_body"         2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('result', '0x0'))
" 2>/dev/null || echo "0x0")

    local fee_dec=0
    if [[ -n "$fee_hex" && "$fee_hex" != "0x" && "$fee_hex" != "0x0" ]]; then
        fee_dec=$(python3 -c "print(int('${fee_hex}', 16))" 2>/dev/null || echo 0)
    fi
    local fee_eth
    fee_eth=$(python3 -c "print(f'{${fee_dec} / 1e18:.8f}')" 2>/dev/null || echo "unknown")

    # Calldata: source_pubkey_bytes (48) + target_pubkey_bytes (48) = 96 bytes total
    local src_hex="${src_pubkey#0x}"
    local tgt_hex="${tgt_pubkey#0x}"
    local calldata="0x${src_hex}${tgt_hex}"

    printf "  Consolidation parameters:
"
    printf "    Source  : %s
" "$src_pubkey"
    printf "    Target  : %s
" "$tgt_pubkey"
    printf "    Chain   : %s
" "$CONSOLIDATION_CHAIN"
    printf "    Contract: %s
" "$consolidation_contract"
    printf "    Fee     : ~%s ETH (%s wei)

" "$fee_eth" "$fee_dec"
    printf "  Calldata: %s

" "$calldata"

    printf "  Command to run (imports the withdrawal key into a temporary keystore):

"
    printf "    cast wallet import --interactive --keystore-dir <TEMP_DIR> <ACCOUNT_NAME>
"
    printf "    cast send %s \
" "$consolidation_contract"
    printf "      --value %swei \
" "$fee_dec"
    printf "      --data %s \
" "$calldata"
    printf "      --rpc-url %s \
" "$el_rpc"
    printf "      --keystore <TEMP_KEYSTORE> \
"
    printf "      --password-file <TEMP_PASSWORD_FILE>

"

    if [[ "$CONSOLIDATE_DRY_RUN" == "true" ]]; then
        log_info "Dry run requested. No keystore import or transaction will be sent."
        return 0
    fi

    if ! confirm_destructive "Consolidation permanently exits the source validator."; then
        log_warn "Aborted. Run the temp-keystore flow above manually when ready."
        return 0
    fi

    read -rsp "  Private key of withdrawal address (hidden; imported into a temp keystore): " priv_key
    printf "
"
    if [[ -z "$priv_key" ]]; then
        log_warn "No private key provided. Aborting."
        return 0
    fi

    local signer_keystore_dir
    signer_keystore_dir=$(mktemp -d /tmp/vmgr_keystore_XXXXXX)
    local signer_password_file
    signer_password_file="$signer_keystore_dir/password.txt"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpfile' '$signer_keystore_dir'" EXIT

    local signer_keystore_path
    signer_keystore_path=$(prepare_consolidation_signer "$priv_key" "$signer_keystore_dir" "$signer_password_file") || return 1

    log_info "Submitting consolidation transaction via temporary keystore..."
    cast send "${consolidation_contract}"         --value "${fee_dec}wei"         --data "${calldata}"         --rpc-url "${el_rpc}"         --keystore "${signer_keystore_path}"         --password-file "${signer_password_file}"

    log_info "Transaction submitted. Monitor the source validator for a pending exit."
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
    printf "  [q] Quit\n\n"
    read -rp "  Choice: " choice

    case "$choice" in
        1) "$SCRIPT_DIR/validator_list.sh" ;;
        2) cmd_exit ;;
        3) cmd_consolidate ;;
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
        "")          show_menu ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
