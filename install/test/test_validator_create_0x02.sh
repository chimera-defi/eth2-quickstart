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

    if "$test_func"; then
        echo "PASS: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $test_name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

setup_fake_env() {
    local temp_root
    temp_root="$(mktemp -d)"
    mkdir -p "$temp_root/bin"

    cat > "$temp_root/bin/deposit.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
: "${MOCK_DEPOSIT_LOG:?missing MOCK_DEPOSIT_LOG}"
echo "[MOCK] deposit.sh $*" >> "$MOCK_DEPOSIT_LOG"
EOF
    chmod +x "$temp_root/bin/deposit.sh"

    cat > "$temp_root/validator_list.sh" <<'EOF'
#!/bin/bash
echo "LIST:$*"
EOF
    chmod +x "$temp_root/validator_list.sh"

    printf '%s\n' "$temp_root"
}

# shellcheck disable=SC2317
test_preview_mentions_compounding_credentials() {
    local temp_root output
    temp_root="$(setup_fake_env)"

    output="$(bash -c '
        source "$1"
        SCRIPT_DIR="$2"
        ROOT_DIR="$3"
        set --
        main
    ' _ "$PROJECT_ROOT/install/utils/validator_create_0x02.sh" "$temp_root" "$PROJECT_ROOT")"

    printf '%s\n' "$output" | grep -q "0x02 Validator Entry Checklist"
    printf '%s\n' "$output" | grep -q "compounding / 0x02"
    printf '%s\n' "$output" | grep -q "LIST:"
    if printf '%s\n' "$output" | grep -q "standard / 0x01"; then
        return 1
    fi

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_launch_uses_deposit_with_compounding() {
    local temp_root output deposit_log
    temp_root="$(setup_fake_env)"
    deposit_log="$temp_root/deposit.log"

    output="$(MOCK_DEPOSIT_LOG="$deposit_log" PATH="$temp_root/bin:$PATH" bash -c '
        source "$1"
        SCRIPT_DIR="$2"
        ROOT_DIR="$3"
        set --
        main --launch
    ' _ "$PROJECT_ROOT/install/utils/validator_create_0x02.sh" "$temp_root" "$PROJECT_ROOT")"

    printf '%s\n' "$output" | grep -q "Launching local deposit CLI"
    grep -F -q "[MOCK] deposit.sh new-mnemonic" "$deposit_log"
    grep -F -q -- "--compounding" "$deposit_log"

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Validator 0x02 Creation Test Suite"
echo "=========================================="

run_test "preview mentions compounding credentials" test_preview_mentions_compounding_credentials
run_test "launch uses deposit with compounding" test_launch_uses_deposit_with_compounding

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