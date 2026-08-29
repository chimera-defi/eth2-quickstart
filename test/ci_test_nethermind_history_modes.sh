#!/bin/bash
# Regression fixtures for the Nethermind history-mode matrix (issue #230 item 1).
#
# install/execution/nethermind.sh has non-trivial, security-relevant logic around
# NETHERMIND_FULL_HISTORY / NETHERMIND_ALLOW_HISTORY_DOWNGRADE: input validation that must run
# before any download/side effect, a fail-closed mode-change gate, mode resolution over an
# existing datadir (reading $HOME/nethermind/nethermind.cfg), disk-sizing, the generated
# nethermind_custom.cfg contents, and the eth1-restart-failure path. None of that was previously
# under shell-level test.
#
# Hermetic design (no network, no destructive filesystem operations):
#   For every case, new_sandbox() builds a throwaway `mktemp -d` PROJECT_ROOT containing the
#   REAL nethermind.sh (copied verbatim — this file never reimplements its logic, so the test
#   cannot silently drift from the code under test), the real configs/nethermind/, a minimal
#   test exports.sh, and a stub lib/common_functions.sh. run_in_sandbox() then execs the real
#   script under `env -i` with HOME redirected into the sandbox and stub curl/sudo/systemctl/
#   journalctl prepended to PATH, so nothing the script does can touch the real $HOME, the
#   network, or systemd.

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

REAL_NETHERMIND_SH="$PROJECT_ROOT/install/execution/nethermind.sh"
REAL_NETHERMIND_CONFIGS="$PROJECT_ROOT/configs/nethermind"

if [[ ! -f "$REAL_NETHERMIND_SH" ]]; then
    log_error "Cannot find $REAL_NETHERMIND_SH — has it moved?"
    exit 2
fi
if [[ ! -d "$REAL_NETHERMIND_CONFIGS" ]]; then
    log_error "Cannot find $REAL_NETHERMIND_CONFIGS — has it moved?"
    exit 2
fi

# =============================================================================
# SANDBOX LIFECYCLE
# =============================================================================

# All per-case sandboxes are created under one throwaway parent dir, so cleanup is a single
# `rm -rf` of that parent — no per-sandbox bookkeeping needed. That matters here because every
# call site uses `sandbox="$(new_sandbox)"`: command substitution runs new_sandbox in a
# subshell, so an array mutated *inside* new_sandbox (e.g. `SANDBOX_DIRS+=(...)`) would never
# be visible to this parent shell's trap — a real bug caught while writing this file (see the
# task report). Rooting everything under one dir sidesteps that class of bug entirely.
TEST_TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/nmd-history-modes.XXXXXX")"

cleanup_sandboxes() {
    [[ -n "$TEST_TMPROOT" && -d "$TEST_TMPROOT" ]] && rm -rf "$TEST_TMPROOT"
}
trap cleanup_sandboxes EXIT

# Writes a minimal test double for exports.sh: only the variables nethermind.sh reads directly
# and unconditionally. Deliberately does NOT set NETHERMIND_FULL_HISTORY or
# NETHERMIND_ALLOW_HISTORY_DOWNGRADE — the harness exports those per case (or leaves them unset
# to exercise nethermind.sh's own ${VAR:-false} default), unlike production exports.sh, which
# hardcodes both unconditionally (exports.sh lines 76-77).
write_fake_exports() {
    local target="$1"
    cat > "$target" <<'STUBEOF'
#!/bin/bash
# Test double for exports.sh — see test/ci_test_nethermind_history_modes.sh for why.
set -Eeuo pipefail
IFS=$'\n\t'

export LH='127.0.0.1'
export FEE_RECIPIENT='0x0000000000000000000000000000000000dEaD'
export GRAFITTI='test-fixture'
export NETHERMIND_CACHE=8192
export NETHERMIND_HTTP_PORT=8545
export NETHERMIND_WS_PORT=8546
export NETHERMIND_ENGINE_PORT=8551
STUBEOF
}

# Writes a stub lib/common_functions.sh defining every function nethermind.sh calls, with no
# network access and no destructive filesystem operation outside the sandbox HOME it runs
# under. Every call is recorded to $NMD_STUB_LOG as "fn|args" so tests can assert on what the
# real script would have done (e.g. that check_system_requirements was asked for the right
# disk size, or that no download function ran when validation should abort first).
write_stub_common_functions() {
    local target="$1"
    cat > "$target" <<'STUBEOF'
#!/bin/bash
# Hermetic stub for lib/common_functions.sh — see test/ci_test_nethermind_history_modes.sh.

NMD_STUB_LOG="${NMD_STUB_LOG:-/dev/null}"

_stub_log() {
    local fn="$1"
    shift
    # exports.sh sets IFS=$'\n\t'; without pinning IFS=' ' here, "$*" would join multi-arg
    # calls (e.g. check_system_requirements "16" "400") with a newline instead of a space.
    local IFS=' '
    printf '%s|%s\n' "$fn" "$*" >> "$NMD_STUB_LOG"
}

log_info() {
    _stub_log log_info "$@"
    echo "[INFO] $*"
}

log_warn() {
    _stub_log log_warn "$@"
    echo "[WARN] $*" >&2
}

log_error() {
    _stub_log log_error "$@"
    echo "[ERROR] $*" >&2
}

log_installation_start() {
    _stub_log log_installation_start "$@"
}

log_installation_complete() {
    _stub_log log_installation_complete "$@"
}

# Mirrors the real function's contract (derive from the caller's BASH_SOURCE, export
# SCRIPT_DIR/PROJECT_ROOT) without touching anything outside the sandbox.
get_script_directories() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local project_root
    project_root="$(cd "$script_dir/../.." && pwd)"
    export SCRIPT_DIR="$script_dir"
    export PROJECT_ROOT="$project_root"
    _stub_log get_script_directories "$SCRIPT_DIR $PROJECT_ROOT"
}

check_system_requirements() {
    _stub_log check_system_requirements "$@"
    return 0
}

setup_firewall_rules() {
    _stub_log setup_firewall_rules "$@"
    return 0
}

ensure_directory() {
    _stub_log ensure_directory "$@"
    mkdir -p "$1"
}

get_github_release_asset_url() {
    _stub_log get_github_release_asset_url "$@"
    echo "https://example.invalid/nethermind-1.99.0-deadbeef-linux-x64.zip"
}

download_file() {
    _stub_log download_file "$@"
    : > "$2"
}

# $2 is dest_dir; nethermind.sh chmod +x's Nethermind.Runner immediately after this call.
extract_archive() {
    _stub_log extract_archive "$@"
    mkdir -p "$2"
    : > "$2/Nethermind.Runner"
}

ensure_jwt_secret() {
    _stub_log ensure_jwt_secret "$@"
    mkdir -p "$(dirname "$1")"
    printf '%064d' 0 > "$1"
}

create_temp_config_dir() {
    _stub_log create_temp_config_dir "$@"
    mkdir -p ./tmp
    echo ./tmp
}

# No network: always "fails" to detect, matching the real function's safe degrade-gracefully
# contract (caller does `|| true` and treats empty as "could not detect").
detect_external_ip() {
    _stub_log detect_external_ip "$@"
    return 1
}

merge_client_config() {
    _stub_log merge_client_config "$@"
    : > "$5"
}

create_systemd_service() {
    _stub_log create_systemd_service "$@"
}

enable_and_start_systemd_service() {
    _stub_log enable_and_start_systemd_service "$@"
}
STUBEOF
}

# Writes stub curl/sudo/systemctl/journalctl binaries into $1, ahead of the real ones on PATH.
write_stub_bins() {
    local bindir="$1"

    cat > "$bindir/curl" <<'STUBEOF'
#!/bin/bash
# No-network stub. Always "fails" silently so nethermind.sh's snap-pivot fetch falls through
# both endpoints and the pivot is correctly omitted. That is expected, not a test failure —
# no case in this suite asserts on pivot values.
exit 1
STUBEOF

    cat > "$bindir/sudo" <<'STUBEOF'
#!/bin/bash
# No privilege escalation in the sandbox: exec the wrapped command directly so it resolves
# through the same sandboxed PATH as everything else — "sudo systemctl ..." reaches this
# directory's systemctl stub, never the real one.
exec "$@"
STUBEOF

    cat > "$bindir/journalctl" <<'STUBEOF'
#!/bin/bash
echo "[stub journalctl] $*"
exit 0
STUBEOF

    cat > "$bindir/systemctl" <<'STUBEOF'
#!/bin/bash
# Deterministic systemctl stub for the eth1 active/restart matrix (nethermind.sh lines
# 270-281). State lives in a file, not env vars, because every invocation from nethermind.sh
# is a fresh process. NMD_SYSTEMCTL_STATE_FILE seeds/tracks eth1's simulated state;
# NMD_RESTART_RESULT_STATE controls what state a `restart` leaves eth1 in (default: active,
# i.e. the restart succeeds).
: "${NMD_SYSTEMCTL_STATE_FILE:?NMD_SYSTEMCTL_STATE_FILE must be set}"
NMD_SYSTEMCTL_LOG="${NMD_SYSTEMCTL_LOG:-/dev/null}"
echo "systemctl $*" >> "$NMD_SYSTEMCTL_LOG"

_read_state() {
    cat "$NMD_SYSTEMCTL_STATE_FILE" 2>/dev/null || echo inactive
}

case "${1:-}" in
    is-active)
        state="$(_read_state)"
        echo "$state"
        if [[ "$state" == "active" ]]; then
            exit 0
        else
            exit 3
        fi
        ;;
    restart)
        echo "${NMD_RESTART_RESULT_STATE:-active}" > "$NMD_SYSTEMCTL_STATE_FILE"
        exit 0
        ;;
    start|enable)
        echo active > "$NMD_SYSTEMCTL_STATE_FILE"
        exit 0
        ;;
    stop)
        echo inactive > "$NMD_SYSTEMCTL_STATE_FILE"
        exit 0
        ;;
    status)
        echo "Stub status: $(_read_state)"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
STUBEOF

    chmod +x "$bindir/curl" "$bindir/sudo" "$bindir/journalctl" "$bindir/systemctl"
}

# Builds a fresh sandbox PROJECT_ROOT + HOME under TEST_TMPROOT. Echoes the sandbox root path.
new_sandbox() {
    local sandbox
    sandbox="$(mktemp -d "$TEST_TMPROOT/case.XXXXXX")"

    mkdir -p \
        "$sandbox/root/install/execution" \
        "$sandbox/root/configs/nethermind" \
        "$sandbox/root/lib" \
        "$sandbox/home" \
        "$sandbox/bin"

    cp "$REAL_NETHERMIND_SH" "$sandbox/root/install/execution/nethermind.sh"
    cp -r "$REAL_NETHERMIND_CONFIGS/." "$sandbox/root/configs/nethermind/"

    write_fake_exports "$sandbox/root/exports.sh"
    write_stub_common_functions "$sandbox/root/lib/common_functions.sh"
    write_stub_bins "$sandbox/bin"

    printf '%s' "$sandbox"
}

# Computes (as CASE_* globals) the per-run paths derived from a sandbox, without running
# anything. Call before run_in_sandbox when a case needs to seed state (e.g. the systemctl
# stub's initial active/inactive state) ahead of the actual invocation.
prepare_case_paths() {
    local sandbox="$1"
    CASE_HOME="$sandbox/home"
    CASE_NETHERMIND_DIR="$CASE_HOME/nethermind"
    CASE_STUB_LOG="$CASE_HOME/.stub_calls.log"
    CASE_SYSTEMCTL_LOG="$CASE_HOME/.systemctl_calls.log"
    CASE_SYSTEMCTL_STATE_FILE="$CASE_HOME/.systemctl_state"
    mkdir -p "$CASE_HOME"
}

# Runs the sandboxed nethermind.sh with the given extra KEY=VALUE env assignments (forwarded
# verbatim to `env`). Populates CASE_OUT (combined stdout+stderr) and CASE_EXIT, plus the
# CASE_* path globals from prepare_case_paths.
run_in_sandbox() {
    local sandbox="$1"
    shift
    prepare_case_paths "$sandbox"
    : > "$CASE_STUB_LOG"
    : > "$CASE_SYSTEMCTL_LOG"

    set +e
    CASE_OUT="$(
        env -i \
            HOME="$CASE_HOME" \
            PATH="$sandbox/bin:/usr/bin:/bin" \
            NMD_STUB_LOG="$CASE_STUB_LOG" \
            NMD_SYSTEMCTL_LOG="$CASE_SYSTEMCTL_LOG" \
            NMD_SYSTEMCTL_STATE_FILE="$CASE_SYSTEMCTL_STATE_FILE" \
            "$@" \
            bash "$sandbox/root/install/execution/nethermind.sh" 2>&1
    )"
    CASE_EXIT=$?
    set -e
}

# Creates the probed datadir ($HOME/.local/share/nethermind/nethermind_db/mainnet) and, unless
# $2 is the literal "NONE", a pre-existing nethermind.cfg at $HOME/nethermind/nethermind.cfg
# with $2 as its raw content.
seed_existing_datadir() {
    local sandbox="$1" cfg_content="$2"
    mkdir -p "$sandbox/home/.local/share/nethermind/nethermind_db/mainnet"
    if [[ "$cfg_content" != "NONE" ]]; then
        mkdir -p "$sandbox/home/nethermind"
        printf '%s' "$cfg_content" > "$sandbox/home/nethermind/nethermind.cfg"
    fi
}

# =============================================================================
# ASSERTION HELPERS
# =============================================================================

assert_exit_eq() {
    local expected="$1" actual="$2" name="$3"
    if [[ "$actual" -eq "$expected" ]]; then
        record_test "$name" "PASS"
    else
        record_test "$name (expected exit $expected, got $actual)" "FAIL"
        log_error "--- captured output ---"
        printf '%s\n' "$CASE_OUT" | sed 's/^/    /'
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" name="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        record_test "$name" "PASS"
    else
        record_test "$name (missing: $needle)" "FAIL"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" name="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        record_test "$name" "PASS"
    else
        record_test "$name (unexpectedly found: $needle)" "FAIL"
    fi
}

# Asserts nethermind_custom.cfg matches the resolved mode's documented shape (nethermind.sh
# lines 181-254): StoreReceipts in both the Init and Receipt blocks, and both
# AncientBodiesBarrier/AncientReceiptsBarrier.
assert_generated_cfg_mode() {
    local cfg_file="$1" mode="$2" label="$3"
    if [[ ! -f "$cfg_file" ]]; then
        record_test "$label: nethermind_custom.cfg was generated" "FAIL"
        return
    fi
    record_test "$label: nethermind_custom.cfg was generated" "PASS"

    local want_store want_barrier
    if [[ "$mode" == "full" ]]; then
        want_store=true
        want_barrier=15537394
    else
        want_store=false
        want_barrier=99999999
    fi

    local store_count barrier_count
    store_count=$(grep -c "\"StoreReceipts\": ${want_store}" "$cfg_file" || true)
    barrier_count=$(grep -c "${want_barrier}" "$cfg_file" || true)

    if [[ "$store_count" -eq 2 ]]; then
        record_test "$label: StoreReceipts=$want_store in both Init and Receipt blocks" "PASS"
    else
        record_test "$label: StoreReceipts=$want_store in both Init and Receipt blocks (found $store_count)" "FAIL"
    fi

    if [[ "$barrier_count" -ge 2 ]]; then
        record_test "$label: Ancient*Barrier=$want_barrier set" "PASS"
    else
        record_test "$label: Ancient*Barrier=$want_barrier set (found $barrier_count)" "FAIL"
    fi
}

# =============================================================================
# A. INPUT VALIDATION (nethermind.sh lines 15-22) — before any download/side effect
# =============================================================================

test_full_history_validation() {
    local val
    for val in yes 1 TRUE; do
        local sandbox
        sandbox="$(new_sandbox)"
        run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=$val"
        assert_exit_eq 1 "$CASE_EXIT" "A1: NETHERMIND_FULL_HISTORY=$val is rejected"
        assert_contains "$CASE_OUT" "NETHERMIND_FULL_HISTORY" "A1: NETHERMIND_FULL_HISTORY=$val error names the variable"
        local stub_log_content
        stub_log_content="$(cat "$CASE_STUB_LOG" 2>/dev/null || true)"
        assert_not_contains "$stub_log_content" "download_file|" "A1: NETHERMIND_FULL_HISTORY=$val — validation aborts before any download"
        assert_not_contains "$stub_log_content" "get_github_release_asset_url|" "A1: NETHERMIND_FULL_HISTORY=$val — validation aborts before fetching a release URL"
    done

    # Deviation from a naive reading of the matrix: bash's ${VAR:-false} treats an
    # exported-but-empty string the same as unset (POSIX ":-" semantics — verified directly,
    # see this task's final report), so NETHERMIND_FULL_HISTORY="" silently resolves to
    # "false" and PROCEEDS rather than erroring. Not a nethermind.sh bug; pinning the actual
    # (safe, defaults-closed) behavior here instead of a wrong "exit 1" expectation.
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY="
    assert_exit_eq 0 "$CASE_EXIT" "A1b: NETHERMIND_FULL_HISTORY='' (exported empty) is treated as unset, not invalid"
}

test_allow_downgrade_validation() {
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox" "NETHERMIND_ALLOW_HISTORY_DOWNGRADE=maybe"
    assert_exit_eq 1 "$CASE_EXIT" "A2: NETHERMIND_ALLOW_HISTORY_DOWNGRADE=maybe is rejected"
    assert_contains "$CASE_OUT" "NETHERMIND_ALLOW_HISTORY_DOWNGRADE" "A2: error names NETHERMIND_ALLOW_HISTORY_DOWNGRADE"
}

test_defaults_both_unset() {
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox"
    assert_exit_eq 0 "$CASE_EXIT" "A3: both history vars unset defaults to false/false and proceeds"
    assert_contains "$CASE_OUT" "MINIMAL staking node" "A3: unset defaults resolve to minimal-history mode"
}

# =============================================================================
# B. MODE-CHANGE GATE (nethermind.sh lines 146-149) — intentional fail-closed behavior
# =============================================================================

test_mode_change_gate_refuses_with_datadir() {
    local sandbox
    sandbox="$(new_sandbox)"
    mkdir -p "$sandbox/home/.local/share/nethermind/nethermind_db/mainnet"
    run_in_sandbox "$sandbox" "NETHERMIND_ALLOW_HISTORY_DOWNGRADE=true"
    assert_exit_eq 1 "$CASE_EXIT" "B4: existing datadir + ALLOW_HISTORY_DOWNGRADE=true is refused"
    assert_contains "$CASE_OUT" "Refusing to change Nethermind history mode" "B4: refusal names the reason"
}

test_mode_change_gate_allows_without_datadir() {
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox" "NETHERMIND_ALLOW_HISTORY_DOWNGRADE=true" "NETHERMIND_FULL_HISTORY=true"
    assert_exit_eq 0 "$CASE_EXIT" "B5: no existing datadir + ALLOW_HISTORY_DOWNGRADE=true proceeds"
    assert_not_contains "$CASE_OUT" "Refusing to change Nethermind history mode" "B5: mode-change gate does not fire without a datadir"
}

# =============================================================================
# C. MODE RESOLUTION OVER AN EXISTING DATADIR (ALLOW=false, nethermind.sh lines 150-168)
# =============================================================================

test_existing_full_history_preserved_over_full_history_false() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" '{"Init": {"StoreReceipts": true}}'
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=false"
    assert_exit_eq 0 "$CASE_EXIT" "C6: existing full-history datadir + FULL_HISTORY=false proceeds"
    assert_contains "$CASE_OUT" "preserving receipt storage" "C6: warns about preserving receipt storage"
    assert_contains "$CASE_OUT" "Nethermind history: FULL post-merge" "C6: resolves to full mode"
    assert_generated_cfg_mode "$CASE_NETHERMIND_DIR/nethermind_custom.cfg" full "C6"
}

test_existing_full_history_kept_with_full_history_true_no_warning() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" '{"Init": {"StoreReceipts": true}}'
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=true"
    assert_exit_eq 0 "$CASE_EXIT" "C7: existing full-history datadir + FULL_HISTORY=true proceeds"
    assert_not_contains "$CASE_OUT" "preserving receipt storage" "C7: no downgrade warning when mode already matches"
    assert_contains "$CASE_OUT" "Nethermind history: FULL post-merge" "C7: resolves to full mode"
}

test_existing_minimal_history_overrides_full_history_true() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" '{"Init": {"StoreReceipts": false}}'
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=true"
    assert_exit_eq 0 "$CASE_EXIT" "C8: existing minimal-history datadir + FULL_HISTORY=true proceeds"
    assert_contains "$CASE_OUT" "retaining minimal mode" "C8: warns about retaining minimal mode"
    assert_contains "$CASE_OUT" "Nethermind history: MINIMAL staking node" "C8: resolves to minimal mode"
    assert_generated_cfg_mode "$CASE_NETHERMIND_DIR/nethermind_custom.cfg" minimal "C8"
}

test_existing_minimal_history_kept_with_full_history_false_no_warning() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" '{"Init": {"StoreReceipts": false}}'
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=false"
    assert_exit_eq 0 "$CASE_EXIT" "C9: existing minimal-history datadir + FULL_HISTORY=false proceeds"
    assert_not_contains "$CASE_OUT" "retaining minimal mode" "C9: no warning when mode already matches"
    assert_contains "$CASE_OUT" "Nethermind history: MINIMAL staking node" "C9: resolves to minimal mode"
}

test_existing_unrecognizable_config_defaults_full() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" '{"Init": {"SomeOtherKey": true}}'
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=false"
    assert_exit_eq 0 "$CASE_EXIT" "C10: existing config with no recognizable receipt mode proceeds"
    assert_contains "$CASE_OUT" "no recognizable receipt mode" "C10: warns about unrecognizable config"
    assert_contains "$CASE_OUT" "Nethermind history: FULL post-merge" "C10: defaults to full mode"
}

test_existing_datadir_no_config_defaults_full() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" "NONE"
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=false"
    assert_exit_eq 0 "$CASE_EXIT" "C11: existing datadir with no config proceeds"
    assert_contains "$CASE_OUT" "no config to identify its history mode" "C11: warns about the missing config"
    assert_contains "$CASE_OUT" "Nethermind history: FULL post-merge" "C11: defaults to full mode"
}

# =============================================================================
# D. FRESH INSTALLS + E. GENERATED-CONFIG ASSERTIONS + F. DISK SIZING
# =============================================================================

test_fresh_install_minimal_default() {
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=false" "NETHERMIND_ALLOW_HISTORY_DOWNGRADE=false"
    assert_exit_eq 0 "$CASE_EXIT" "D12: fresh install, FULL_HISTORY=false"
    assert_contains "$CASE_OUT" "Nethermind history: MINIMAL staking node" "D12: resolves to minimal mode"
    assert_contains "$(cat "$CASE_STUB_LOG" 2>/dev/null || true)" "check_system_requirements|16 400" "F14: fresh + FULL_HISTORY=false requires 400GB disk"
    assert_generated_cfg_mode "$CASE_NETHERMIND_DIR/nethermind_custom.cfg" minimal "D12/E"
}

test_fresh_install_full_history_opt_in() {
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=true" "NETHERMIND_ALLOW_HISTORY_DOWNGRADE=false"
    assert_exit_eq 0 "$CASE_EXIT" "D13: fresh install, FULL_HISTORY=true"
    assert_contains "$CASE_OUT" "Nethermind history: FULL post-merge" "D13: resolves to full mode"
    assert_contains "$(cat "$CASE_STUB_LOG" 2>/dev/null || true)" "check_system_requirements|16 2000" "F15a: fresh + FULL_HISTORY=true requires 2000GB disk"
    assert_generated_cfg_mode "$CASE_NETHERMIND_DIR/nethermind_custom.cfg" full "D13/E"
}

test_disk_sizing_existing_datadir_forces_2000gb() {
    local sandbox
    sandbox="$(new_sandbox)"
    seed_existing_datadir "$sandbox" '{"Init": {"StoreReceipts": false}}'
    run_in_sandbox "$sandbox" "NETHERMIND_FULL_HISTORY=false"
    assert_exit_eq 0 "$CASE_EXIT" "F15b: existing datadir + FULL_HISTORY=false proceeds"
    assert_contains "$(cat "$CASE_STUB_LOG" 2>/dev/null || true)" "check_system_requirements|16 2000" "F15b: any existing datadir requires 2000GB disk regardless of resolved mode"
}

# =============================================================================
# G. ACTIVE-SERVICE RESTART FAILURE HANDLING (nethermind.sh lines 270-281)
# =============================================================================

test_active_service_restart_succeeds() {
    local sandbox
    sandbox="$(new_sandbox)"
    prepare_case_paths "$sandbox"
    echo active > "$CASE_SYSTEMCTL_STATE_FILE"
    run_in_sandbox "$sandbox" "NMD_RESTART_RESULT_STATE=active"
    assert_exit_eq 0 "$CASE_EXIT" "G16: active service, restart succeeds"
    assert_contains "$CASE_OUT" "restarting it to load the generated configuration" "G16: takes the restart path"
    local systemctl_log_content stub_log_content
    systemctl_log_content="$(cat "$CASE_SYSTEMCTL_LOG" 2>/dev/null || true)"
    stub_log_content="$(cat "$CASE_STUB_LOG" 2>/dev/null || true)"
    assert_contains "$systemctl_log_content" "restart" "G16: systemctl restart was invoked"
    assert_not_contains "$stub_log_content" "enable_and_start_systemd_service|" "G16: does not fall back to enable_and_start"
}

test_active_service_restart_fails() {
    local sandbox
    sandbox="$(new_sandbox)"
    prepare_case_paths "$sandbox"
    echo active > "$CASE_SYSTEMCTL_STATE_FILE"
    run_in_sandbox "$sandbox" "NMD_RESTART_RESULT_STATE=inactive"
    assert_exit_eq 1 "$CASE_EXIT" "G17: active service, restart leaves it inactive"
    assert_contains "$CASE_OUT" "Nethermind failed after configuration restart" "G17: reports the restart failure"
}

test_inactive_service_uses_enable_and_start() {
    local sandbox
    sandbox="$(new_sandbox)"
    run_in_sandbox "$sandbox"
    assert_exit_eq 0 "$CASE_EXIT" "G18: inactive service, fresh install"
    assert_contains "$(cat "$CASE_STUB_LOG" 2>/dev/null || true)" "enable_and_start_systemd_service|eth1" "G18: takes the enable_and_start path"
    assert_not_contains "$(cat "$CASE_SYSTEMCTL_LOG" 2>/dev/null || true)" "restart" "G18: never calls systemctl restart"
}

# =============================================================================
# RUN
# =============================================================================

log_header "Nethermind history-mode regression fixtures (issue #230 item 1)"

test_full_history_validation
test_allow_downgrade_validation
test_defaults_both_unset

test_mode_change_gate_refuses_with_datadir
test_mode_change_gate_allows_without_datadir

test_existing_full_history_preserved_over_full_history_false
test_existing_full_history_kept_with_full_history_true_no_warning
test_existing_minimal_history_overrides_full_history_true
test_existing_minimal_history_kept_with_full_history_false_no_warning
test_existing_unrecognizable_config_defaults_full
test_existing_datadir_no_config_defaults_full

test_fresh_install_minimal_default
test_fresh_install_full_history_opt_in
test_disk_sizing_existing_datadir_forces_2000gb

test_active_service_restart_succeeds
test_active_service_restart_fails
test_inactive_service_uses_enable_and_start

print_test_summary
