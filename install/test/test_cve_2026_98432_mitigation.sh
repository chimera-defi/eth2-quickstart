#!/bin/bash

# Fixture tests for install/security/cve_2026_98432_mitigation.sh.
# Runs write under a temp CVE_MITIGATION_ROOT with runtime calls skipped, so the host's
# /etc, nft and systemd are never touched. The real Phase 1 run is asserted in
# test/ci_test_run_1_e2e.sh (--verify inside the systemd container).

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MITIGATION="$PROJECT_ROOT/install/security/cve_2026_98432_mitigation.sh"

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

mitigate() {
    local root="$1"
    shift
    CVE_MITIGATION_ROOT="$root" CVE_MITIGATION_SKIP_RUNTIME=true bash "$MITIGATION" "$@" >/dev/null
}

snapshot() {
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
}

test_apply_writes_layers() {
    local root unit d
    root=$(mktemp -d)
    mitigate "$root"
    grep -q 'meta l4proto tcp ip hdrlength gt 5 counter drop' "$root/etc/nftables-cve-2026-98432.nft"
    grep -qx 'delete table ip cve_2026_98432' "$root/etc/nftables-cve-2026-98432.nft"
    unit="$root/etc/systemd/system/cve-2026-98432-nft.service"
    grep -qx 'Before=network-pre.target network.target' "$unit"
    grep -qx 'After=nftables.service' "$unit"
    grep -qx 'PartOf=nftables.service' "$unit"
    grep -qx 'ReloadPropagatedFrom=nftables.service' "$unit"
    grep -qx 'ExecReload=/usr/sbin/nft -f /etc/nftables-cve-2026-98432.nft' "$unit"
    grep -qx 'WantedBy=multi-user.target nftables.service' "$unit"
    for d in system user; do
        grep -qx 'DefaultEnvironment="GODEBUG=multipathtcp=0"' "$root/etc/systemd/$d.conf.d/90-godebug-mptcp.conf"
    done
    rm -rf "$root"
}

test_apply_is_idempotent() {
    local root before
    root=$(mktemp -d)
    mitigate "$root"
    before=$(snapshot "$root")
    mitigate "$root"
    [[ "$before" == "$(snapshot "$root")" ]]
    rm -rf "$root"
}

test_opt_out_writes_nothing() {
    local root
    root=$(mktemp -d)
    ENABLE_CVE_2026_98432_MITIGATION=false mitigate "$root"
    [[ -z "$(find "$root" -type f)" ]]
    rm -rf "$root"
}

test_remove_undoes_apply() {
    local root
    root=$(mktemp -d)
    mkdir -p "$root/etc/sysctl.d"
    printf 'net.ipv4.tcp_syncookies = 1\nnet.mptcp.enabled = 0\n' > "$root/etc/sysctl.d/99-eth2-hardening.conf"
    mitigate "$root"
    mitigate "$root" --remove
    [[ "$(find "$root" -type f)" == "$root/etc/sysctl.d/99-eth2-hardening.conf" ]]
    [[ "$(cat "$root/etc/sysctl.d/99-eth2-hardening.conf")" == 'net.ipv4.tcp_syncookies = 1' ]]
    rm -rf "$root"
}

# create_systemd_service puts GODEBUG inside [Service] of every generated unit, unless opted out
test_generated_units_carry_godebug() {
    local out
    out=$(
        HOME=$(mktemp -d)
        export HOME
        # shellcheck source=../../exports.sh
        source "$PROJECT_ROOT/exports.sh"
        # shellcheck source=../../lib/common_functions.sh
        source "$PROJECT_ROOT/lib/common_functions.sh"
        sudo() { if [[ "$1" == "mv" ]]; then cat "$2"; fi; }
        create_systemd_service eth1 "Geth" "/usr/bin/geth" eth
        export ENABLE_CVE_2026_98432_MITIGATION=false
        create_systemd_service eth1 "Geth" "/usr/bin/geth" eth
        rm -rf "$HOME"
    )
    [[ $(grep -c '^Environment="GODEBUG=multipathtcp=0"$' <<< "$out") -eq 1 ]]
    awk '/^\[Service\]/{s=1} /^\[Install\]/{s=0} /GODEBUG/{exit !s}' <<< "$out"
}

test_shellcheck_clean() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck not installed; skipping"
        return 0
    fi
    # Repo exclusions (CLAUDE.md) minus SC2034, so unused variables still fail
    shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2031,SC2181 "$MITIGATION" "${BASH_SOURCE[0]}"
}

echo "=========================================="
echo "CVE-2026-98432 Mitigation Test Suite"
echo "=========================================="

run_test "apply writes nft rule, nftables-coordinated unit and GODEBUG drop-ins" test_apply_writes_layers
run_test "apply is idempotent" test_apply_is_idempotent
run_test "ENABLE_CVE_2026_98432_MITIGATION=false writes nothing" test_opt_out_writes_nothing
run_test "--remove deletes our files and only the mptcp sysctl line" test_remove_undoes_apply
run_test "generated systemd units carry GODEBUG (and honor opt-out)" test_generated_units_carry_godebug
run_test "shellcheck clean (SC2034 enforced)" test_shellcheck_clean

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
