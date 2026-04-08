#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPAIR_SCRIPT="$PROJECT_ROOT/install/utils/repair.sh"
REFRESH_SCRIPT="$PROJECT_ROOT/install/utils/refresh.sh"

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

sample_payload() {
    cat <<'EOF'
{
  "summary": {"status": "warn"},
  "issues": [
    {
      "kind": "restart_service",
      "severity": "fail",
      "summary": "cl is installed but not running",
      "suggested_action": "Restart cl and inspect logs if it fails again",
      "service": "cl"
    },
    {
      "kind": "service_flag_mismatch",
      "severity": "fail",
      "summary": "Service unit arguments do not match the installed binary",
      "suggested_action": "Review the unit/config against the installed version before restarting or updating",
      "service": "commit-boost-pbs"
    }
  ],
  "repair_preview": [
    {
      "action": "restart_service",
      "safe": true,
      "command": "sudo systemctl restart cl",
      "service": "cl"
    },
    {
      "action": "service_flag_mismatch",
      "safe": false,
      "command": "./scripts/eth2qs.sh update-all --git-only --backup",
      "service": "commit-boost-pbs"
    }
  ]
}
EOF
}

test_preview_lists_safe_restart_candidate() {
    local output
    output="$(REPAIR_STATS_PAYLOAD="$(sample_payload)" "$REPAIR_SCRIPT")"
    grep -Fq "Safe auto-repair candidates:" <<<"$output" &&
        grep -Fq "sudo systemctl restart cl" <<<"$output"
}

test_apply_requires_confirm() {
    if REPAIR_STATS_PAYLOAD="$(sample_payload)" "$REPAIR_SCRIPT" --apply >/tmp/repair_apply_no_confirm.out 2>&1; then
        return 1
    fi
    grep -Fq "without --confirm" /tmp/repair_apply_no_confirm.out
}

test_apply_only_executes_allowlisted_safe_restart_commands() {
    local temp_dir sudo_log
    temp_dir="$(mktemp -d)"
    sudo_log="$temp_dir/sudo.log"

    cat >"$temp_dir/sudo" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$SUDO_LOG"
EOF
    chmod +x "$temp_dir/sudo"

    cat >"$temp_dir/systemctl" <<'EOF'
#!/bin/bash
if [[ "$1" == "list-unit-files" ]]; then
    printf '%s\n' 'cl.service enabled'
    exit 0
fi
exit 0
EOF
    chmod +x "$temp_dir/systemctl"

    if ! PATH="$temp_dir:$PATH" \
        SUDO_LOG="$sudo_log" \
        REPAIR_STATS_PAYLOAD="$(sample_payload)" \
        REPAIR_SKIP_POST_STATS=true \
        "$REPAIR_SCRIPT" --apply --confirm >/tmp/repair_apply_confirm.out 2>&1; then
        rm -rf "$temp_dir"
        return 1
    fi

    grep -Fq "systemctl restart cl" "$sudo_log" &&
        ! grep -Fq "update-all" "$sudo_log"
    local status=$?
    rm -rf "$temp_dir"
    return $status
}

test_refresh_supports_smart_mode() {
    grep -Fq -- '--smart' "$REFRESH_SCRIPT" &&
        grep -Fq 'repair.sh' "$REFRESH_SCRIPT"
}

echo "=========================================="
echo "Repair Safe Actions Test Suite"
echo "=========================================="

run_test "repair preview lists safe restart candidates" test_preview_lists_safe_restart_candidate
run_test "repair apply requires confirm" test_apply_requires_confirm
run_test "repair apply only executes allowlisted safe restart commands" test_apply_only_executes_allowlisted_safe_restart_commands
run_test "refresh script supports smart mode" test_refresh_supports_smart_mode

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
