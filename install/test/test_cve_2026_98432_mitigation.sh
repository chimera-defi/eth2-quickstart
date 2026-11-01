#!/bin/bash

# Fixture tests for install/security/cve_2026_98432_mitigation.sh.
# Every run writes under a temp CVE_MITIGATION_ROOT with runtime calls skipped,
# so nothing on the host's /etc, sysctl, nft or systemd is touched.

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

new_root() {
    local root
    root=$(mktemp -d)
    mkdir -p "$root/etc"
    echo "$root"
}

run_mitigation() {
    local root="$1"
    shift
    CVE_MITIGATION_ROOT="$root" CVE_MITIGATION_SKIP_RUNTIME=true bash "$MITIGATION" "$@" >/dev/null
}

snapshot() {
    (cd "$1" && find . -type f -print0 | sort -z | xargs -0 sha256sum)
}

test_apply_writes_all_files() {
    local root
    root=$(new_root)
    run_mitigation "$root"
    grep -qx 'net.mptcp.enabled = 0' "$root/etc/sysctl.d/90-disable-mptcp.conf"
    grep -qx 'table ip cve_2026_98432' "$root/etc/nftables-cve-2026-98432.nft"
    grep -qx 'delete table ip cve_2026_98432' "$root/etc/nftables-cve-2026-98432.nft"
    grep -q 'type filter hook prerouting priority -300;' "$root/etc/nftables-cve-2026-98432.nft"
    grep -q 'meta l4proto tcp ip hdrlength gt 5 counter drop' "$root/etc/nftables-cve-2026-98432.nft"
    local unit="$root/etc/systemd/system/cve-2026-98432-nft.service"
    grep -qx 'Type=oneshot' "$unit"
    grep -qx 'RemainAfterExit=yes' "$unit"
    grep -qx 'ExecStart=/usr/sbin/nft -f /etc/nftables-cve-2026-98432.nft' "$unit"
    grep -qx 'ExecStop=/usr/sbin/nft delete table ip cve_2026_98432' "$unit"
    grep -qx 'Wants=network-pre.target' "$unit"
    grep -qx 'Before=network-pre.target network.target' "$unit"
    grep -qx 'WantedBy=multi-user.target' "$unit"
    local d
    for d in system user; do
        grep -qx '\[Manager\]' "$root/etc/systemd/$d.conf.d/90-godebug-mptcp.conf"
        grep -qx 'DefaultEnvironment="GODEBUG=multipathtcp=0"' "$root/etc/systemd/$d.conf.d/90-godebug-mptcp.conf"
    done
    grep -qx 'GODEBUG=multipathtcp=0' "$root/etc/environment"
    rm -rf "$root"
}

test_apply_is_idempotent() {
    local root before after
    root=$(new_root)
    printf 'PATH="/usr/bin:/bin"\n' > "$root/etc/environment"
    run_mitigation "$root"
    before=$(snapshot "$root")
    run_mitigation "$root"
    run_mitigation "$root"
    after=$(snapshot "$root")
    [[ "$before" == "$after" ]]
    [[ $(grep -c '^GODEBUG=' "$root/etc/environment") -eq 1 ]]
    grep -qx 'PATH="/usr/bin:/bin"' "$root/etc/environment"
    rm -rf "$root"
}

test_existing_godebug_is_appended() {
    local root
    root=$(new_root)
    printf 'GODEBUG=http2client=0\n' > "$root/etc/environment"
    run_mitigation "$root"
    grep -qx 'GODEBUG=http2client=0,multipathtcp=0' "$root/etc/environment"
    rm -rf "$root"
}

test_existing_quoted_godebug_is_appended() {
    local root
    root=$(new_root)
    printf 'GODEBUG="x509sha1=1"\n' > "$root/etc/environment"
    run_mitigation "$root"
    run_mitigation "$root"
    grep -qx 'GODEBUG="x509sha1=1,multipathtcp=0"' "$root/etc/environment"
    rm -rf "$root"
}

test_env_without_trailing_newline() {
    local root
    root=$(new_root)
    printf 'PATH="/usr/bin:/bin"' > "$root/etc/environment"
    run_mitigation "$root"
    [[ "$(cat "$root/etc/environment")" == $'PATH="/usr/bin:/bin"\nGODEBUG=multipathtcp=0' ]]
    rm -rf "$root"
}

test_commented_godebug_left_alone() {
    local root out
    root=$(new_root)
    printf 'GODEBUG=http2client=0 # keep\n' > "$root/etc/environment"
    out=$(CVE_MITIGATION_ROOT="$root" CVE_MITIGATION_SKIP_RUNTIME=true bash "$MITIGATION" 2>&1)
    [[ "$(cat "$root/etc/environment")" == 'GODEBUG=http2client=0 # keep' ]]
    grep -q 'cannot merge safely' <<< "$out"
    rm -rf "$root"
}

test_verify_reports_unknown_when_ss_fails() {
    local stub out
    stub=$(mktemp -d)
    printf '#!/bin/sh\nexit 1\n' > "$stub/ss"
    printf '#!/bin/sh\nexit 1\n' > "$stub/nft"
    chmod +x "$stub/ss" "$stub/nft"
    out=$(PATH="$stub:$PATH" bash "$MITIGATION" --verify 2>&1)
    grep -q 'MPTCP listeners: unknown' <<< "$out"
    if grep -q 'No MPTCP listeners open' <<< "$out"; then return 1; fi
    rm -rf "$stub"
}

test_conflicting_godebug_left_alone() {
    local root out
    root=$(new_root)
    printf 'GODEBUG=multipathtcp=1\n' > "$root/etc/environment"
    out=$(CVE_MITIGATION_ROOT="$root" CVE_MITIGATION_SKIP_RUNTIME=true bash "$MITIGATION" 2>&1)
    grep -qx 'GODEBUG=multipathtcp=1' "$root/etc/environment"
    grep -q 'different multipathtcp value' <<< "$out"
    rm -rf "$root"
}

test_opt_out_writes_nothing() {
    local root
    root=$(new_root)
    ENABLE_CVE_2026_98432_MITIGATION=false run_mitigation "$root"
    [[ -z "$(find "$root/etc" -type f)" ]]
    rm -rf "$root"
}

test_remove_undoes_apply() {
    local root
    root=$(new_root)
    printf 'LANG=C.UTF-8\nGODEBUG=http2client=0\n' > "$root/etc/environment"
    run_mitigation "$root"
    run_mitigation "$root" --remove
    [[ ! -e "$root/etc/sysctl.d/90-disable-mptcp.conf" ]]
    [[ ! -e "$root/etc/nftables-cve-2026-98432.nft" ]]
    [[ ! -e "$root/etc/systemd/system/cve-2026-98432-nft.service" ]]
    [[ ! -e "$root/etc/systemd/system.conf.d/90-godebug-mptcp.conf" ]]
    [[ ! -e "$root/etc/systemd/user.conf.d/90-godebug-mptcp.conf" ]]
    [[ "$(cat "$root/etc/environment")" == $'LANG=C.UTF-8\nGODEBUG=http2client=0' ]]
    rm -rf "$root"
}

test_remove_drops_sole_godebug_line() {
    local root
    root=$(new_root)
    run_mitigation "$root"
    run_mitigation "$root" --remove
    if grep -q '^GODEBUG=' "$root/etc/environment"; then return 1; fi
    rm -rf "$root"
}

test_generated_units_carry_godebug() {
    local out
    out=$(
        export HOME
        HOME=$(mktemp -d)
        # shellcheck source=../../exports.sh
        source "$PROJECT_ROOT/exports.sh"
        # shellcheck source=../../lib/common_functions.sh
        source "$PROJECT_ROOT/lib/common_functions.sh"
        sudo() { [[ "$1" == "mv" ]] && cat "$2" && return 0; return 0; }
        create_systemd_service eth1 "Geth" "/usr/bin/geth" eth
        ENABLE_CVE_2026_98432_MITIGATION=false
        create_systemd_service eth1 "Geth" "/usr/bin/geth" eth
        rm -rf "$HOME"
    )
    [[ $(grep -c '^Environment="GODEBUG=multipathtcp=0"$' <<< "$out") -eq 1 ]]
    # Environment line sits inside [Service], not after [Install]
    awk '/^\[Service\]/{s=1} /^\[Install\]/{s=0} /GODEBUG/{exit !s}' <<< "$out"
}

test_wired_into_phase1_and_exports() {
    # shellcheck disable=SC2016  # literal match
    grep -Fq 'export ENABLE_CVE_2026_98432_MITIGATION="${ENABLE_CVE_2026_98432_MITIGATION:-true}"' "$PROJECT_ROOT/exports.sh"
    grep -Fq 'install/security/cve_2026_98432_mitigation.sh' "$PROJECT_ROOT/run_1.sh"
    grep -Fq 'cve_2026_98432_mitigation.sh' "$PROJECT_ROOT/install/security/harden_server.sh"
}

test_shellcheck_clean() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        echo "shellcheck not installed; skipping"
        return 0
    fi
    shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 "$MITIGATION" "${BASH_SOURCE[0]}"
}

echo "=========================================="
echo "CVE-2026-98432 Mitigation Test Suite"
echo "=========================================="

run_test "apply writes sysctl, nft, unit and GODEBUG files" test_apply_writes_all_files
run_test "apply is idempotent across re-runs" test_apply_is_idempotent
run_test "existing GODEBUG gets ,multipathtcp=0 appended" test_existing_godebug_is_appended
run_test "existing quoted GODEBUG appended once" test_existing_quoted_godebug_is_appended
run_test "/etc/environment without trailing newline stays intact" test_env_without_trailing_newline
run_test "commented GODEBUG line is left alone with a warning" test_commented_godebug_left_alone
run_test "--verify reports unknown when ss fails" test_verify_reports_unknown_when_ss_fails
run_test "conflicting multipathtcp value is left alone with a warning" test_conflicting_godebug_left_alone
run_test "ENABLE_CVE_2026_98432_MITIGATION=false writes nothing" test_opt_out_writes_nothing
run_test "--remove undoes apply and keeps other GODEBUG settings" test_remove_undoes_apply
run_test "--remove drops a GODEBUG line it created" test_remove_drops_sole_godebug_line
run_test "generated systemd units carry GODEBUG (and honor opt-out)" test_generated_units_carry_godebug
run_test "wired into exports.sh, run_1.sh and harden_server.sh" test_wired_into_phase1_and_exports
run_test "shellcheck clean" test_shellcheck_clean

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
