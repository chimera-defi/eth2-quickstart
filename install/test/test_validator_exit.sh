#!/bin/bash

set -Eeuo pipefail
# shellcheck disable=SC2317

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local test_name="$1"
    local test_func="$2"

    TEST_COUNT=$((TEST_COUNT + 1))
    echo ""
    echo "=== Test $TEST_COUNT: $test_name ==="

    # Run the test with -e active as a PLAIN subshell statement. Invoking it
    # via `if "$test_func"` disables set -e inside the function, so a failing
    # assertion would not fail the test (the function returns its last
    # command's status, usually the cleanup `rm -rf`). Save/restore errexit.
    local _rc _e_was=0
    [[ $- == *e* ]] && _e_was=1
    set +e
    ( set -euo pipefail; "$test_func" )
    _rc=$?
    [[ $_e_was -eq 1 ]] && set -e
    if [[ $_rc -eq 0 ]]; then
        echo "PASS: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $test_name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

test_yes_skips_prompt() {
    local temp_root temp_manage temp_list output
    temp_root="$(mktemp -d)"
    temp_manage="$temp_root/validator_manage.sh"
    temp_list="$temp_root/validator_list.sh"

    cat > "$temp_manage" <<'EOF'
#!/bin/bash
echo "MANAGE:$*"
EOF
    chmod +x "$temp_manage"

    cat > "$temp_list" <<'EOF'
#!/bin/bash
echo "LIST:$*"
EOF
    chmod +x "$temp_list"

    output="$(bash -c '
        source "$1"
        SCRIPT_DIR="$2"
        ROOT_DIR="$3"
        main --yes
    ' _ "$PROJECT_ROOT/install/utils/validator_exit.sh" "$temp_root" "$PROJECT_ROOT")"

    rm -rf "$temp_root"
    [[ "$output" == *"MANAGE:--exit"* ]]
    [[ "$output" != *"Proceed to the interactive exit flow"* ]]
}

echo "=========================================="
echo "Validator Exit Test Suite"
echo "=========================================="

run_test "--yes skips prompt and execs exit flow" test_yes_skips_prompt

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TEST_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo ""
    echo "All tests passed!"
    exit 0
fi

exit 1
