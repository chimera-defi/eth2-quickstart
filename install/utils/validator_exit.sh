#!/bin/bash

# Eth2 Quick Start — Validator Exit Helper
# Focused wrapper for exiting local validators with a checklist for 0x00/0x01
# operators. Reuses the existing validator listing and exit flow.
#
# Usage:
#   ./install/utils/validator_exit.sh
#   ./scripts/eth2qs.sh validator-exit

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

AUTO_CONFIRM=false

usage() {
    cat <<'EOF'
Usage: ./install/utils/validator_exit.sh [--yes|-y]

Prints the exit checklist for 0x00/0x01 legacy validators and then hands off
to the existing interactive exit flow in validator_manage.sh.

Options:
  --yes, -y   Skip the confirmation prompt and enter the exit flow directly
EOF
}

show_exit_checklist() {
    cat <<'EOF'

=== Validator Exit Checklist ===

- Confirm the validator you are exiting is one you control.
- If the validator still uses 0x00 withdrawal credentials, update withdrawal
  credentials before you expect any funds to become withdrawable.
- 0x01 validators auto-sweep rewards above 32 ETH after withdrawals are enabled.
- Keep the validator online until the exit epoch is reached.
- After the validator becomes withdrawable, the remaining balance is swept to
  the configured withdrawal address automatically.
- Do not reuse the same validator key to stake again after the full exit.

EOF
}

show_local_inventory() {
    if [[ ! -x "$SCRIPT_DIR/validator_list.sh" ]]; then
        log_warn "validator_list.sh not found or not executable at $SCRIPT_DIR"
        return 0
    fi

    log_info "Current local validators:"
    "$SCRIPT_DIR/validator_list.sh" || true
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -y|--yes)
                AUTO_CONFIRM=true
                ;;
            "")
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done

    show_exit_checklist
    show_local_inventory

    if [[ ! -x "$SCRIPT_DIR/validator_manage.sh" ]]; then
        log_error "validator_manage.sh not found or not executable at $SCRIPT_DIR"
        exit 1
    fi

    if [[ "$AUTO_CONFIRM" == true ]]; then
        log_info "Skipping confirmation prompt because --yes was supplied."
        exec "$SCRIPT_DIR/validator_manage.sh" --exit
    fi

    printf '
'
    read -rp "Proceed to the interactive exit flow? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES)
            exec "$SCRIPT_DIR/validator_manage.sh" --exit
            ;;
        *)
            log_warn "Exit flow aborted."
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
