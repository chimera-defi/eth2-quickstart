#!/bin/bash
# Regression tests for check_service_status().
#
# Guards a SIGPIPE/pipefail race: `systemctl list-unit-files | grep -q ...` looks
# harmless, but grep -q exits at its first match and closes the pipe. systemctl then
# dies with SIGPIPE (exit 141), and `set -o pipefail` surfaces 141 as the pipeline's
# status — so an INSTALLED unit intermittently reports as "not_installed".
#
# That misreport feeds lib/install_planner.sh, so ensure.sh/plan.sh could classify a
# fully provisioned host as needing Phase 2, and doctor.sh could report a healthy
# service as absent. Measured on a live node before the fix: 23/40 calls wrong.
#
# Every other test in this suite stubs check_service_status out, so nothing exercised
# the real implementation. These tests do.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=../../lib/common_functions.sh
source "$PROJECT_ROOT/lib/common_functions.sh"

test_count=0
pass_count=0
fail_count=0

SANDBOX="$(mktemp -d)"
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

run_test() {
    local test_name="$1"
    local test_func="$2"

    test_count=$((test_count + 1))
    echo ""
    echo "=== Test $test_count: $test_name ==="

    local _rc
    set +e
    ( set -Eeuo pipefail; "$test_func" )
    _rc=$?
    set -e
    if [[ $_rc -eq 0 ]]; then
        echo "✅ PASS: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo "❌ FAIL: $test_name"
        fail_count=$((fail_count + 1))
    fi
}

# Build a systemctl stub. The listing is deliberately far larger than a pipe buffer
# (64 KiB on Linux) and puts the unit of interest FIRST, so any consumer that exits
# early leaves the writer blocked mid-write — the exact condition that produced SIGPIPE.
# STUB_ACTIVE / STUB_ENABLED select the is-active / is-enabled outcome.
write_systemctl_stub() {
    cat > "$SANDBOX/systemctl" <<'STUB'
#!/bin/bash
case "${1:-}" in
    list-unit-files)
        echo "UNIT FILE                                  STATE"
        echo "eth1.service                               enabled"
        awk 'BEGIN { for (i = 0; i < 20000; i++) printf "filler-%05d.service                       enabled\n", i }'
        echo "1 unit files listed."
        ;;
    is-active)
        [[ "${STUB_ACTIVE:-1}" == "1" ]] && exit 0
        exit 3
        ;;
    is-enabled)
        [[ "${STUB_ENABLED:-1}" == "1" ]] && exit 0
        exit 1
        ;;
esac
exit 0
STUB
    chmod +x "$SANDBOX/systemctl"
}

# An installed unit must never intermittently read as not_installed. Repeat enough
# times that a race shows up: pre-fix this failed well over half the time.
test_installed_unit_is_stable() {
    local i status wrong=0
    for i in $(seq 1 40); do
        status="$(PATH="$SANDBOX:$PATH" check_service_status eth1)"
        if [[ "$status" == "not_installed" ]]; then
            wrong=$((wrong + 1))
        fi
    done

    if (( wrong > 0 )); then
        echo "  ERROR: eth1 reported not_installed in $wrong/40 calls (unit IS present)"
        return 1
    fi
    return 0
}

test_running_unit_reports_running() {
    local status
    status="$(PATH="$SANDBOX:$PATH" STUB_ACTIVE=1 check_service_status eth1)"
    [[ "$status" == "running" ]] || { echo "  ERROR: expected running, got '$status'"; return 1; }
}

test_stopped_but_enabled_unit() {
    local status
    status="$(PATH="$SANDBOX:$PATH" STUB_ACTIVE=0 STUB_ENABLED=1 check_service_status eth1)"
    [[ "$status" == "stopped" ]] || { echo "  ERROR: expected stopped, got '$status'"; return 1; }
}

test_disabled_unit() {
    local status
    status="$(PATH="$SANDBOX:$PATH" STUB_ACTIVE=0 STUB_ENABLED=0 check_service_status eth1)"
    [[ "$status" == "disabled" ]] || { echo "  ERROR: expected disabled, got '$status'"; return 1; }
}

# A unit genuinely absent from the listing must still report not_installed.
test_absent_unit_reports_not_installed() {
    local status
    status="$(PATH="$SANDBOX:$PATH" check_service_status definitely-not-a-real-unit)"
    [[ "$status" == "not_installed" ]] || { echo "  ERROR: expected not_installed, got '$status'"; return 1; }
}

# "eth1" must not be satisfied by "eth1Xservice" — the unescaped dot in the original
# pattern made `.` match any character.
test_unit_name_dot_is_literal() {
    cat > "$SANDBOX/systemctl" <<'STUB'
#!/bin/bash
case "${1:-}" in
    list-unit-files)
        echo "UNIT FILE                                  STATE"
        echo "eth1Xservice                               enabled"
        ;;
esac
exit 0
STUB
    chmod +x "$SANDBOX/systemctl"

    local status
    status="$(PATH="$SANDBOX:$PATH" check_service_status eth1)"
    write_systemctl_stub
    [[ "$status" == "not_installed" ]] || {
        echo "  ERROR: 'eth1Xservice' wrongly matched unit 'eth1' (got '$status')"
        return 1
    }
}

echo "Running check_service_status regression tests..."
write_systemctl_stub

run_test "installed unit never intermittently reads as not_installed" test_installed_unit_is_stable
run_test "active unit reports running" test_running_unit_reports_running
run_test "inactive but enabled unit reports stopped" test_stopped_but_enabled_unit
run_test "inactive and disabled unit reports disabled" test_disabled_unit
run_test "absent unit reports not_installed" test_absent_unit_reports_not_installed
run_test "unit-name dot is matched literally" test_unit_name_dot_is_literal

echo ""
echo "=== Test Summary ==="
echo "Total tests: $test_count"
echo "Passed: $pass_count"
echo "Failed: $fail_count"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
echo "All tests passed!"
