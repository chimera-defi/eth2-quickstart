#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

# shellcheck source=../../lib/common_functions.sh
source "$ROOT_DIR/lib/common_functions.sh"
# shellcheck source=../../lib/install_planner.sh
source "$ROOT_DIR/lib/install_planner.sh"

APPLY=false
JSON_OUTPUT=false
CHAIN_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            APPLY=true
            ;;
        --json)
            JSON_OUTPUT=true
            ;;
        --chain)
            CHAIN_OVERRIDE="${2:-}"
            shift
            ;;
        --help|-h)
            cat <<'EOF'
Usage: ./install/utils/ensure.sh [--apply] [--json] [--chain ethereum|monad]

Preview or execute the next safe install step for this host.
By default this prints a plan only. Use --apply to execute the next action.
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

planner_load_config "$ROOT_DIR"
CHAIN_VALUE="${CHAIN_OVERRIDE:-$(planner_configured_chain)}"
OPERATOR_USER="${LOGIN_UNAME:-eth}"
CURRENT_USER="$(id -un)"
IS_ROOT=false
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
fi

if planner_operator_user_exists "$OPERATOR_USER"; then
    OPERATOR_EXISTS=true
else
    OPERATOR_EXISTS=false
fi

planner_collect_service_states "$CHAIN_VALUE"
planner_determine_next_action "$CHAIN_VALUE" "$IS_ROOT" "$OPERATOR_EXISTS" "$PLAN_CORE_INSTALLED" "$PLAN_CORE_EXPECTED"

if [[ "$JSON_OUTPUT" == "true" ]] && [[ "$APPLY" == "false" ]]; then
    if [[ -n "$CHAIN_OVERRIDE" ]]; then
        exec "$ROOT_DIR/install/utils/plan.sh" --json --chain "$CHAIN_OVERRIDE"
    fi
    exec "$ROOT_DIR/install/utils/plan.sh" --json
fi

echo "State:       $PLAN_STATE"
echo "Next action: $PLAN_NEXT_ACTION"
echo "Reason:      $PLAN_REASON"

if [[ "$APPLY" == "false" ]]; then
    echo ""
    echo "Preview only. Re-run with --apply to execute the next safe action."
    exit 0
fi

case "$PLAN_NEXT_ACTION" in
    noop)
        log_info "No install action required."
        ;;
    phase1)
        log_info "Running Phase 1 hardening..."
        exec "$ROOT_DIR/run_1.sh"
        ;;
    phase2)
        log_info "Running Ethereum Phase 2 install..."
        exec "$ROOT_DIR/run_2.sh"
        ;;
    monad_install)
        log_info "Running Monad install flow..."
        exec "$ROOT_DIR/monad_install.sh"
        ;;
    relogin)
        log_warn "Phase 1 appears complete. Reboot/login as '${OPERATOR_USER}' before continuing."
        exit 1
        ;;
    review)
        log_warn "Install state is partial or unsupported. Review with doctor/stats/logs before continuing."
        exit 1
        ;;
    *)
        log_error "Unsupported next action: $PLAN_NEXT_ACTION"
        exit 1
        ;;
esac
