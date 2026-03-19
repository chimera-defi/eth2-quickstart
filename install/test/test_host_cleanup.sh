#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PURGE_SCRIPT="$PROJECT_ROOT/install/utils/purge_ethereum_data.sh"
WRAPPER_SCRIPT="$PROJECT_ROOT/scripts/eth2qs.sh"

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

test_purge_script_supports_host_mode() {
    grep -Fq -- '--host' "$PURGE_SCRIPT" &&
        grep -Fq '/root/.ethereum' "$PURGE_SCRIPT" &&
        grep -Fq '/root/.eth2/network-keys' "$PURGE_SCRIPT"
}

test_wrapper_exposes_cleanup_host() {
    grep -Fq 'cleanup-host)' "$WRAPPER_SCRIPT" &&
        grep -Fq 'cleanup-host [args...]' "$WRAPPER_SCRIPT" &&
        grep -Fq 'purge_ethereum_data.sh" --host "$@"' "$WRAPPER_SCRIPT"
}

echo "=========================================="
echo "Host Cleanup Test Suite"
echo "=========================================="

run_test "purge script supports host cleanup mode and preserves root secrets" test_purge_script_supports_host_mode
run_test "wrapper exposes cleanup-host command" test_wrapper_exposes_cleanup_host

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
