#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

# shellcheck source=../../lib/common_functions.sh
source "$ROOT_DIR/lib/common_functions.sh"
# shellcheck source=../../lib/install_planner.sh
source "$ROOT_DIR/lib/install_planner.sh"

JSON_OUTPUT=false
CHAIN_OVERRIDE=""
CHAIN_VALUE=""
OPERATOR_USER=""
CURRENT_USER=""
OPERATOR_EXISTS=false
IS_ROOT=false

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            ;;
        --chain)
            CHAIN_OVERRIDE="${2:-}"
            shift
            ;;
        --help|-h)
            cat <<'EOF'
Usage: ./install/utils/plan.sh [--json] [--chain ethereum|monad]

Detect the next safe install/operation step for this host.
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

planner_prepare_context "$ROOT_DIR" "$CHAIN_OVERRIDE"

if [[ "$JSON_OUTPUT" == "true" ]]; then
    printf '{\n'
    printf '  "chain": "%s",\n' "$(json_escape "$CHAIN_VALUE")"
    printf '  "current_user": "%s",\n' "$(json_escape "$CURRENT_USER")"
    printf '  "is_root": %s,\n' "$IS_ROOT"
    printf '  "operator_user": "%s",\n' "$(json_escape "$OPERATOR_USER")"
    printf '  "operator_user_exists": %s,\n' "$OPERATOR_EXISTS"
    printf '  "state": "%s",\n' "$(json_escape "$PLAN_STATE")"
    printf '  "next_action": "%s",\n' "$(json_escape "$PLAN_NEXT_ACTION")"
    printf '  "reason": "%s",\n' "$(json_escape "$PLAN_REASON")"
    printf '  "core_services_expected": %s,\n' "$PLAN_CORE_EXPECTED"
    printf '  "core_services_installed": %s,\n' "$PLAN_CORE_INSTALLED"
    printf '  "core_services_running": %s,\n' "$PLAN_CORE_RUNNING"
    printf '  "service_states": {\n'
    for i in "${!PLAN_SERVICE_NAMES[@]}"; do
        comma=","
        if [[ "$i" -eq $((${#PLAN_SERVICE_NAMES[@]} - 1)) ]]; then
            comma=""
        fi
        printf '    "%s": "%s"%s\n' \
            "$(json_escape "${PLAN_SERVICE_NAMES[$i]}")" \
            "$(json_escape "${PLAN_SERVICE_STATUSES[$i]}")" \
            "$comma"
    done
    printf '  }\n'
    printf '}\n'
    exit 0
fi

echo "Chain:            $CHAIN_VALUE"
echo "Current user:     $CURRENT_USER"
echo "Is root:          $IS_ROOT"
echo "Operator user:    $OPERATOR_USER"
echo "Operator exists:  $OPERATOR_EXISTS"
echo "State:            $PLAN_STATE"
echo "Next action:      $PLAN_NEXT_ACTION"
echo "Reason:           $PLAN_REASON"
echo "Core services:    $PLAN_CORE_INSTALLED/$PLAN_CORE_EXPECTED installed, $PLAN_CORE_RUNNING running"
echo ""
echo "Service states:"
for i in "${!PLAN_SERVICE_NAMES[@]}"; do
    printf '  - %s: %s\n' "${PLAN_SERVICE_NAMES[$i]}" "${PLAN_SERVICE_STATUSES[$i]}"
done
