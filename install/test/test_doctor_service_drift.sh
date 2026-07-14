#!/bin/bash

set -Eeuo pipefail
# shellcheck disable=SC2317

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

    local _rc _e_was=0
    [[ $- == *e* ]] && _e_was=1
    set +e
    ( set -euo pipefail; "$test_func" )
    _rc=$?
    [[ $_e_was -eq 1 ]] && set -e
    if [[ $_rc -eq 0 ]]; then
        echo "PASS: $test_name"
        pass_count=$((pass_count + 1))
    else
        echo "FAIL: $test_name"
        fail_count=$((fail_count + 1))
    fi
}

# shellcheck disable=SC2317
setup_fake_repo() {
    local temp_root
    temp_root="$(mktemp -d)"
    mkdir -p "$temp_root/install/utils" "$temp_root/lib" "$temp_root/config" "$temp_root/bin"

    cp "$PROJECT_ROOT/install/utils/doctor.sh" "$temp_root/install/utils/doctor.sh"
    chmod +x "$temp_root/install/utils/doctor.sh"

    cat > "$temp_root/exports.sh" <<'EOF'
#!/bin/bash
export FEE_RECIPIENT="0xa1feaF41d843d53d0F6bEd86a8cF592cE21C409e"
EOF

    cat > "$temp_root/config/user_config.env" <<'EOF'
FEE_RECIPIENT="0xa1feaF41d843d53d0F6bEd86a8cF592cE21C409e"
EOF

    cat > "$temp_root/lib/common_functions.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
RED=''
GREEN=''
YELLOW=''
BLUE=''
NC=''
check_service_status() {
    case "$1" in
        eth1) printf '%s\n' "running" ;;
        cl|validator|mev|commit-boost-pbs|commit-boost-signer|fail2ban) printf '%s\n' "disabled" ;;
        *) printf '%s\n' "not_installed" ;;
    esac
}
check_port() { return 1; }
log_info() { printf '[INFO] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*"; }
log_error() { printf '[ERROR] %s\n' "$*" >&2; }
EOF

    cat > "$temp_root/bin/systemctl" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
if [[ "$1" == "cat" && "$2" == "eth1" ]]; then
    cat <<'UNIT'
[Service]
ExecStart=/root/ethrex/ethrex --network mainnet
UNIT
    exit 0
fi
if [[ "$1" == "show" && "$2" == "eth1" && "$3" == "-p" && "$4" == "MainPID" && "$5" == "--value" ]]; then
    printf '4242\n'
    exit 0
fi
if [[ "$1" == "show" ]]; then
    printf '\n'
    exit 0
fi
exit 0
EOF

    cat > "$temp_root/bin/ps" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
printf '/usr/bin/geth --datadir /root/.ethereum\n'
EOF

    cat > "$temp_root/bin/curl" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
exit 0
EOF

    cat > "$temp_root/bin/host" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
exit 0
EOF

    cat > "$temp_root/bin/nslookup" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
exit 0
EOF

    cat > "$temp_root/bin/ufw" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
printf 'Status: active\n'
EOF

    chmod +x \
        "$temp_root/exports.sh" \
        "$temp_root/lib/common_functions.sh" \
        "$temp_root/bin/systemctl" \
        "$temp_root/bin/ps" \
        "$temp_root/bin/curl" \
        "$temp_root/bin/host" \
        "$temp_root/bin/nslookup" \
        "$temp_root/bin/ufw"

    printf '%s\n' "$temp_root"
}

# shellcheck disable=SC2317
test_doctor_reports_service_unit_drift_in_json() {
    local temp_root output
    temp_root="$(setup_fake_repo)"

    # doctor.sh --json exits non-zero whenever the overall status is "fail" —
    # e.g. a small CI runner fails the disk-space minimum. This test only cares
    # about the service-unit-drift check, so capture the JSON regardless of exit
    # code rather than letting a failing environment check abort the assertion.
    output="$(PATH="$temp_root/bin:$PATH" "$temp_root/install/utils/doctor.sh" --json)" || true

    if ! jq -e '.checks[] | select(.name == "Execution client (eth1): Service unit drift detected" and .status == "warn") | .details == "Unit expects ethrex but runtime is geth"' >/dev/null <<< "$output"; then
        rm -rf "$temp_root"
        return 1
    fi

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Doctor Service Drift Test Suite"
echo "=========================================="

run_test "doctor reports service unit drift in json output" test_doctor_reports_service_unit_drift_in_json

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
