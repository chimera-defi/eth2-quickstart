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

    cp "$PROJECT_ROOT/install/utils/ensure.sh" "$temp_root/install/utils/ensure.sh"
    chmod +x "$temp_root/install/utils/ensure.sh"

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
planner_operator_user_exists() { return 1; }
planner_collect_service_states() {
    PLAN_SERVICE_NAMES=()
    PLAN_SERVICE_STATUSES=()
    PLAN_CORE_EXPECTED=0
    PLAN_CORE_INSTALLED=0
    PLAN_CORE_RUNNING=0
}
planner_determine_next_action() {
    PLAN_STATE="${TEST_PLAN_STATE:-test_state}"
    PLAN_NEXT_ACTION="${TEST_PLAN_NEXT_ACTION:-noop}"
    PLAN_REASON="${TEST_PLAN_REASON:-test reason}"
}
EOF

    cat > "$temp_root/install/utils/plan.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
printf '{ "stub": true }\n'
EOF

    cat > "$temp_root/run_1.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
printf 'phase1\n' > "$TEST_MARKER_FILE"
EOF

    cat > "$temp_root/run_2.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
printf 'phase2\n' > "$TEST_MARKER_FILE"
EOF

    cat > "$temp_root/monad_install.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
printf 'monad\n' > "$TEST_MARKER_FILE"
EOF

    chmod +x \
        "$temp_root/lib/common_functions.sh" \
        "$temp_root/lib/install_planner.sh" \
        "$temp_root/install/utils/plan.sh" \
        "$temp_root/run_1.sh" \
        "$temp_root/run_2.sh" \
        "$temp_root/monad_install.sh"

    printf '%s\n' "$temp_root"
}

test_preview_only_does_not_execute() {
    local temp_root output marker_file
    temp_root="$(setup_fake_repo)"
    marker_file="$temp_root/marker.txt"

    output="$(TEST_PLAN_NEXT_ACTION=phase1 TEST_MARKER_FILE="$marker_file" "$temp_root/install/utils/ensure.sh" 2>&1)"
    if [[ "$output" != *"Preview only."* ]] || [[ -f "$marker_file" ]]; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

test_apply_requires_confirm() {
    local temp_root output marker_file
    temp_root="$(setup_fake_repo)"
    marker_file="$temp_root/marker.txt"

    if output="$(TEST_PLAN_NEXT_ACTION=phase1 TEST_MARKER_FILE="$marker_file" "$temp_root/install/utils/ensure.sh" --apply 2>&1)"; then
        rm -rf "$temp_root"
        echo "  ERROR: ensure --apply should fail without --confirm"
        return 1
    fi

    if [[ "$output" != *"--confirm"* ]] || [[ -f "$marker_file" ]]; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

test_apply_phase1_dispatch() {
    local temp_root marker_file
    temp_root="$(setup_fake_repo)"
    marker_file="$temp_root/marker.txt"

    TEST_PLAN_NEXT_ACTION=phase1 TEST_MARKER_FILE="$marker_file" \
        "$temp_root/install/utils/ensure.sh" --apply --confirm >/dev/null

    if ! grep -Fxq "phase1" "$marker_file"; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

test_apply_phase2_dispatch() {
    local temp_root marker_file
    temp_root="$(setup_fake_repo)"
    marker_file="$temp_root/marker.txt"

    TEST_PLAN_NEXT_ACTION=phase2 TEST_MARKER_FILE="$marker_file" \
        "$temp_root/install/utils/ensure.sh" --apply --confirm >/dev/null

    if ! grep -Fxq "phase2" "$marker_file"; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

test_apply_monad_dispatch() {
    local temp_root marker_file
    temp_root="$(setup_fake_repo)"
    marker_file="$temp_root/marker.txt"

    TEST_PLAN_NEXT_ACTION=monad_install TEST_MARKER_FILE="$marker_file" TEST_CHAIN=monad \
        "$temp_root/install/utils/ensure.sh" --apply --confirm >/dev/null

    if ! grep -Fxq "monad" "$marker_file"; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Ensure Dispatch Test Suite"
echo "=========================================="

run_test "preview only does not execute actions" test_preview_only_does_not_execute
run_test "apply requires confirm" test_apply_requires_confirm
run_test "phase1 apply dispatches run_1.sh" test_apply_phase1_dispatch
run_test "phase2 apply dispatches run_2.sh" test_apply_phase2_dispatch
run_test "monad apply dispatches monad_install.sh" test_apply_monad_dispatch

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
