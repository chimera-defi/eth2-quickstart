#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/lib/test_harness.sh"

setup_fake_repo() {
    local temp_root
    temp_root="$(mktemp -d)"
    mkdir -p "$temp_root/install/utils" "$temp_root/lib"

    cp "$PROJECT_ROOT/install/utils/plan.sh" "$temp_root/install/utils/plan.sh"
    chmod +x "$temp_root/install/utils/plan.sh"

    cat > "$temp_root/lib/common_functions.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
check_service_status() { printf '%s\n' "not_installed"; }
EOF

    cat > "$temp_root/lib/install_planner.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
planner_load_config() { :; }
planner_configured_chain() { printf '%s\n' "${TEST_CHAIN:-ethereum}"; }
planner_operator_user_exists() { return 0; }
planner_collect_service_states() {
    PLAN_SERVICE_NAMES=("eth1" "cl")
    PLAN_SERVICE_STATUSES=("running" "not_installed")
    PLAN_CORE_EXPECTED=2
    PLAN_CORE_INSTALLED=1
    PLAN_CORE_RUNNING=1
}
planner_determine_next_action() {
    PLAN_STATE="${TEST_PLAN_STATE:-partial_install_review}"
    PLAN_NEXT_ACTION="${TEST_PLAN_NEXT_ACTION:-review}"
    PLAN_REASON="${TEST_PLAN_REASON:-default reason}"
}
planner_prepare_context() {
    planner_load_config "${1:-.}"
    CHAIN_VALUE="${2:-$(planner_configured_chain)}"
    OPERATOR_USER="${LOGIN_UNAME:-eth}"
    CURRENT_USER="test-user"
    IS_ROOT=false
    OPERATOR_EXISTS=true
    planner_collect_service_states "$CHAIN_VALUE"
    planner_determine_next_action "$CHAIN_VALUE" "$IS_ROOT" "$OPERATOR_EXISTS" "$PLAN_CORE_INSTALLED" "$PLAN_CORE_EXPECTED"
}
EOF

    chmod +x "$temp_root/lib/common_functions.sh" "$temp_root/lib/install_planner.sh"
    printf '%s\n' "$temp_root"
}

test_json_shape_is_valid() {
    local temp_root output
    temp_root="$(setup_fake_repo)"
    output="$(TEST_CHAIN=monad TEST_PLAN_STATE=needs_monad_install TEST_PLAN_NEXT_ACTION=monad_install "$temp_root/install/utils/plan.sh" --json)"

    if ! python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["chain"]=="monad"; assert data["next_action"]=="monad_install"; assert data["service_states"]["eth1"]=="running"; assert data["service_states"]["cl"]=="not_installed"' <<< "$output"; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

test_json_reason_is_escaped() {
    local temp_root output
    temp_root="$(setup_fake_repo)"
    output="$(TEST_PLAN_REASON=$'quote \" line\nbreak' "$temp_root/install/utils/plan.sh" --json)"

    if ! python3 -c 'import json,sys; data=json.load(sys.stdin); assert data["reason"] == "quote \\\" line\\nbreak".encode("utf-8").decode("unicode_escape")' <<< "$output"; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Plan JSON Test Suite"
echo "=========================================="

run_test "plan json is valid and contains expected keys" test_json_shape_is_valid
run_test "plan json escapes quoted multiline reason strings" test_json_reason_is_escaped

print_summary
