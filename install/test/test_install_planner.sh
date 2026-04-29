#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../lib/install_planner.sh
source "$PROJECT_ROOT/lib/install_planner.sh"

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
        echo "✅ PASS: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo "❌ FAIL: $test_name"
        fail_count=$((fail_count + 1))
    fi
}

assert_plan() {
    local chain="$1"
    local is_root="$2"
    local operator_exists="$3"
    local installed_count="$4"
    local expected_count="$5"
    local expected_state="$6"
    local expected_action="$7"

    planner_determine_next_action "$chain" "$is_root" "$operator_exists" "$installed_count" "$expected_count"
    [[ "$PLAN_STATE" == "$expected_state" ]] && [[ "$PLAN_NEXT_ACTION" == "$expected_action" ]]
}

test_needs_phase1() {
    assert_plan "ethereum" "true" "false" 0 2 "needs_phase1" "phase1"
}

test_needs_relogin() {
    assert_plan "ethereum" "true" "true" 0 2 "needs_relogin" "relogin"
}

test_needs_phase2() {
    assert_plan "ethereum" "false" "true" 0 2 "needs_phase2" "phase2"
}

test_needs_monad_install() {
    assert_plan "monad" "false" "true" 0 3 "needs_monad_install" "monad_install"
}

test_installed_state() {
    assert_plan "ethereum" "false" "true" 2 2 "installed" "noop"
}

test_partial_review_state() {
    assert_plan "ethereum" "false" "true" 1 2 "partial_install_review" "review"
}

test_ensure_requires_confirm() {
    local output
    if output="$("$PROJECT_ROOT/install/utils/ensure.sh" --apply 2>&1)"; then
        echo "  ERROR: ensure --apply should require --confirm"
        return 1
    fi

    if grep -q -- "--confirm" <<< "$output"; then
        return 0
    fi

    echo "  ERROR: missing --confirm guidance in ensure output"
    return 1
}

echo "=========================================="
echo "Install Planner Test Suite"
echo "=========================================="

run_test "ethereum root without operator -> phase1" test_needs_phase1
run_test "ethereum root with operator -> relogin" test_needs_relogin
run_test "ethereum non-root -> phase2" test_needs_phase2
run_test "monad non-root -> monad_install" test_needs_monad_install
run_test "fully installed stack -> noop" test_installed_state
run_test "partial install -> review" test_partial_review_state
run_test "ensure apply requires confirm" test_ensure_requires_confirm

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"

if [[ $fail_count -eq 0 ]]; then
    echo ""
    echo "✅ All tests passed!"
    exit 0
fi

exit 1
