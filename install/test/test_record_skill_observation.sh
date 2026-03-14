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

test_print_only_outputs_valid_json() {
    local output
    output="$("$PROJECT_ROOT/scripts/record_skill_observation.sh" \
        --skill eth2-quickstart \
        --task "test task" \
        --result success \
        --command "./scripts/eth2qs.sh plan --json" \
        --evidence "doctor ok" \
        --notes $'quoted \" note\nline' \
        --print-only)"

    jq -e '.skill == "eth2-quickstart" and .result == "success" and .command == "./scripts/eth2qs.sh plan --json" and .notes == "quoted \" note\nline"' >/dev/null <<< "$output"
}

test_append_writes_one_line() {
    local temp_file line_count
    temp_file="$(mktemp)"

    SKILL_OBSERVATIONS_FILE="$temp_file" "$PROJECT_ROOT/scripts/record_skill_observation.sh" \
        --skill eth2-quickstart \
        --task "failed planner run" \
        --result failure \
        --evidence "invalid json" >/dev/null

    line_count="$(wc -l < "$temp_file")"
    if [[ "$line_count" -ne 1 ]]; then
        rm -f "$temp_file"
        return 1
    fi

    jq -e '.result == "failure" and .task == "failed planner run"' >/dev/null < "$temp_file"
    rm -f "$temp_file"
}

echo "=========================================="
echo "Skill Observation Test Suite"
echo "=========================================="

run_test "print-only outputs valid json" test_print_only_outputs_valid_json
run_test "append writes a structured observation line" test_append_writes_one_line

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
