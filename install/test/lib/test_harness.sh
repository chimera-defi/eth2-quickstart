#!/bin/bash
# Shared test harness for install/test/ test suites.
# Source this file to get run_test() and print_summary().
#
# Usage:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test_harness.sh"
#   run_test "description" test_function_name
#   ...
#   print_summary

_harness_test_count=0
_harness_pass_count=0
_harness_fail_count=0

run_test() {
    local test_name="$1"
    local test_func="$2"

    _harness_test_count=$((_harness_test_count + 1))
    echo ""
    echo "=== Test $_harness_test_count: $test_name ==="

    if "$test_func"; then
        echo "PASS: $test_name"
        _harness_pass_count=$((_harness_pass_count + 1))
    else
        echo "FAIL: $test_name"
        _harness_fail_count=$((_harness_fail_count + 1))
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total tests: $_harness_test_count"
    echo "Passed: $_harness_pass_count"
    echo "Failed: $_harness_fail_count"

    if [[ $_harness_fail_count -eq 0 ]]; then
        echo ""
        echo "All tests passed!"
        exit 0
    fi

    exit 1
}
