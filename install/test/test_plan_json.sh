#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

test_count=0
pass_count=0
fail_count=0

run_test() {
    local test_name="$1"
    local test_func="$2"

    test_count=$((test_count + 1))
    echo ""
    echo "=== Test $test_count: $test_name ==="

    if "$test_func"; then
        echo "PASS: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo "FAIL: $test_name"
        fail_count=$((fail_count + 1))
    fi
}

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

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"

if [[ $fail_count -eq 0 ]]; then
    echo ""
    echo "All tests passed!"
    exit 0
fi

exit 1
