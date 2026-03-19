#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATS_SCRIPT="$PROJECT_ROOT/install/utils/stats.sh"

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

# shellcheck disable=SC2317
test_stats_does_not_invoke_prysm_bootstrap_script() {
    local pattern="\\\$HOME/prysm/prysm\\.sh.*(beacon-chain|validator).*(-version|--version)"
    ! grep -Eq "$pattern" "$STATS_SCRIPT"
}

# shellcheck disable=SC2317
test_stats_uses_local_prysm_binary_discovery() {
    grep -Fq 'find_prysm_binary' "$STATS_SCRIPT" &&
        grep -Fq 'bootstrap script present, local binary not downloaded' "$STATS_SCRIPT"
}

echo "=========================================="
echo "Stats Read-Only Test Suite"
echo "=========================================="

run_test "stats does not invoke prysm bootstrap script for version checks" test_stats_does_not_invoke_prysm_bootstrap_script
run_test "stats uses local Prysm binary discovery only" test_stats_uses_local_prysm_binary_discovery

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
