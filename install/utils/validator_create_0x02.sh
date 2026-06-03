#!/bin/bash

# Eth2 Quick Start — 0x02 Validator Creation Helper
# Focused operator checklist and launcher for modern compounding validators.
# The script prints the checklist, shows the current local validator inventory,
# and can launch the official deposit CLI if one is available.
#
# Usage:
#   ./install/utils/validator_create_0x02.sh
#   ./install/utils/validator_create_0x02.sh --launch
#   ./scripts/eth2qs.sh validator-create-0x02 --launch

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

LAUNCH=false
TOOL="auto"
MODE="new-mnemonic"
CHAIN="mainnet"
FOLDER="$ROOT_DIR/validator_keys"
NUM_VALIDATORS=1
MNEMONIC_LANGUAGE="English"
EXECUTION_ADDRESS=""

usage() {
    cat <<'EOF'
Usage: ./install/utils/validator_create_0x02.sh [options]

Options:
  --launch                    Launch the detected deposit CLI interactively.
  --tool <auto|deposit|deposit-sh>
                              Select the deposit tool launcher.
  --mode <new-mnemonic|existing-mnemonic>
                              Select the deposit CLI subcommand.
  --chain <name>              Chain name passed to the deposit CLI (default: mainnet).
  --folder <path>             Output folder for keystores and deposit data.
  --num-validators <n>        Number of validators to create (default: 1).
  --mnemonic-language <lang>   Mnemonic language passed to the deposit CLI.
  --execution-address <addr>   Withdrawal address / execution address.
  --help                      Show this help.

This helper prints the offline key-generation checklist and, when launched,
starts the official deposit CLI so you can select 0x02 / compounding
withdrawal credentials during the CLI prompts.
EOF
}

show_entry_checklist() {
    cat <<'EOF'

=== 0x02 Validator Entry Checklist ===

- Use an offline or otherwise isolated machine for key generation.
- Generate a new mnemonic unless you intentionally want to derive from a
  secure existing mnemonic.
- Use a withdrawal address you control and can recover.
- Choose compounding / 0x02 withdrawal credentials in the deposit tool.
- Save the keystore passwords, mnemonic backup, and deposit_data file securely.
- Verify the deposit contract address before sending ETH.
- After deposit, import the keystores into the validator client on the node.

EOF
}

show_local_inventory() {
    if [[ ! -x "$SCRIPT_DIR/validator_list.sh" ]]; then
        return 0
    fi

    log_info "Current local validator inventory:"
    "$SCRIPT_DIR/validator_list.sh" || true
}

print_command_preview() {
    local launcher="deposit.sh"
    local launcher_detected
    if launcher_detected=$(find_deposit_launcher 2>/dev/null); then
        launcher="$launcher_detected"
    fi
    local cmd=("$launcher" "$MODE")
    cmd+=("--num_validators=$NUM_VALIDATORS")
    cmd+=("--mnemonic_language=$MNEMONIC_LANGUAGE")
    cmd+=("--chain=$CHAIN")
    cmd+=("--folder=$FOLDER")
    if [[ -n "$EXECUTION_ADDRESS" ]]; then
        cmd+=("--execution_address=$EXECUTION_ADDRESS")
    fi

    printf "\n"
    printf "Recommended command template:\n\n"
    printf "  %s\n\n" "${cmd[*]}"
    printf "If your installed deposit CLI asks for withdrawal credential type, select\n"
    printf "the compounding / 0x02 option.\n\n"
}

find_deposit_launcher() {
    case "$TOOL" in
        deposit)
            if command -v deposit >/dev/null 2>&1; then
                printf '%s\n' "deposit"
                return 0
            fi
            ;;
        deposit-sh)
            if command -v deposit.sh >/dev/null 2>&1; then
                printf '%s\n' "deposit.sh"
                return 0
            fi
            ;;
        auto)
            if command -v deposit >/dev/null 2>&1; then
                printf '%s\n' "deposit"
                return 0
            fi
            if command -v deposit.sh >/dev/null 2>&1; then
                printf '%s\n' "deposit.sh"
                return 0
            fi
            ;;
        *)
            log_error "Unknown tool selection: $TOOL"
            return 1
            ;;
    esac

    return 1
}

launch_deposit_tool() {
    local launcher
    launcher=$(find_deposit_launcher) || return 1

    local args=()
    args+=("$MODE")
    args+=("--num_validators=$NUM_VALIDATORS")
    args+=("--mnemonic_language=$MNEMONIC_LANGUAGE")
    args+=("--chain=$CHAIN")
    args+=("--folder=$FOLDER")
    if [[ -n "$EXECUTION_ADDRESS" ]]; then
        args+=("--execution_address=$EXECUTION_ADDRESS")
    fi

    log_info "Launching local deposit CLI: $launcher $MODE"
    exec "$launcher" "${args[@]}"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --launch)
                LAUNCH=true
                ;;
            --tool)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --tool" >&2; exit 1; }
                TOOL="$1"
                ;;
            --mode)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --mode" >&2; exit 1; }
                MODE="$1"
                ;;
            --chain)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --chain" >&2; exit 1; }
                CHAIN="$1"
                ;;
            --folder)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --folder" >&2; exit 1; }
                FOLDER="$1"
                ;;
            --num-validators|--num_validators)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --num-validators" >&2; exit 1; }
                NUM_VALIDATORS="$1"
                ;;
            --mnemonic-language|--mnemonic_language)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --mnemonic-language" >&2; exit 1; }
                MNEMONIC_LANGUAGE="$1"
                ;;
            --execution-address|--execution_address|--eth1_withdrawal_address|--eth1-withdrawal-address)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --execution-address" >&2; exit 1; }
                EXECUTION_ADDRESS="$1"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done

    show_entry_checklist
    show_local_inventory
    print_command_preview

    if [[ "$LAUNCH" != "true" ]]; then
        log_info "Run again with --launch to open the deposit CLI directly."
        exit 0
    fi

    if ! launch_deposit_tool; then
        log_error "No supported local deposit CLI was found."
        log_info "Install ethstaker-deposit-cli, then re-run this helper with --launch."
        exit 1
    fi
}

main "$@"
