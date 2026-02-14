#!/bin/bash
# E2E Test - Executes run_1.sh (Phase 1) or run_2.sh (Phase 2) and verifies results
# Phase 1 = run_1.sh (system setup, root). Phase 2 = run_2.sh (client install, testuser).
# Run inside Docker with systemd. Requires PHASE=1|2 set by run_e2e.sh.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

LOG_PREFIX="E2E"
PHASE="${PHASE:-}"

if [[ -z "$PHASE" ]] || [[ "$PHASE" != "1" && "$PHASE" != "2" ]]; then
    log_error "PHASE=1 or PHASE=2 required (set by run_e2e.sh)"
    exit 1
fi

# run_1.sh = Phase 1, run_2.sh = Phase 2
log_header "run_${PHASE}.sh - E2E"
log_info "Running as: $(whoami)"

if ! command -v systemctl &>/dev/null; then
    log_error "systemctl not found - run container with systemd init"
    exit 1
fi

cd "$PROJECT_ROOT"

# =============================================================================
# PHASE 1: run_1.sh (system setup)
# =============================================================================
if [[ "$PHASE" == "1" ]]; then
    if ! is_root; then
        log_error "Phase 1 E2E must run as root"
        exit 1
    fi

    source "$PROJECT_ROOT/exports.sh"

    log_header "Executing run_1.sh"
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical

    "$PROJECT_ROOT/install/utils/debconf_preseed.sh"
    mkdir -p /root/.ssh
    if [[ ! -f /root/.ssh/authorized_keys ]]; then
        echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test-key-for-e2e" > /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    fi

    if ! "$PROJECT_ROOT/run_1.sh"; then
        record_test "run_1.sh execution" "FAIL"
        print_test_summary
        exit 1
    fi
    record_test "run_1.sh execution" "PASS"

    log_header "Verifying run_1.sh Results"
    if [[ -f /root/handoff_info.txt ]]; then
        record_test "Handoff info file created" "PASS"
        if grep -q "$LOGIN_UNAME" /root/handoff_info.txt; then record_test "Handoff contains username" "PASS"; else record_test "Handoff contains username" "FAIL"; fi
    else
        record_test "Handoff info file created" "FAIL"
    fi
    if id -u "$LOGIN_UNAME" &>/dev/null; then record_test "User '$LOGIN_UNAME' created" "PASS"; else record_test "User '$LOGIN_UNAME' created" "FAIL"; fi
    if sudo -u "$LOGIN_UNAME" sudo -n true 2>/dev/null; then record_test "User has sudo (NOPASSWD)" "PASS"; else record_test "User has sudo (NOPASSWD)" "FAIL"; fi
    if [[ -f /home/${LOGIN_UNAME}/.ssh/authorized_keys ]]; then record_test "SSH keys migrated to new user" "PASS"; else record_test "SSH keys migrated to new user" "FAIL"; fi
    if [[ -f /etc/ssh/sshd_config.backup ]]; then record_test "SSH config backed up" "PASS"; else record_test "SSH config backed up" "FAIL"; fi
    if [[ -f /etc/sysctl.d/99-eth2-hardening.conf ]]; then record_test "Network hardening applied" "PASS"; else record_test "Network hardening applied" "FAIL"; fi
    if [[ -f /usr/local/bin/security_monitor.sh ]]; then record_test "Security monitoring script installed" "PASS"; else record_test "Security monitoring script installed" "FAIL"; fi
    if ufw status 2>/dev/null | grep -q "Status: active"; then record_test "UFW firewall active" "PASS"; else record_test "UFW firewall active" "FAIL"; fi
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        record_test "Fail2ban service running" "PASS"
        if fail2ban-client status 2>/dev/null | grep -q "sshd"; then record_test "Fail2ban sshd jail active" "PASS"; else record_test "Fail2ban sshd jail active" "FAIL"; fi
    else
        record_test "Fail2ban service running" "FAIL"
    fi
    if command -v aide &>/dev/null; then
        record_test "AIDE installed" "PASS"
        if [[ -f /var/lib/aide/aide.db ]]; then record_test "AIDE database initialized" "PASS"; else record_test "AIDE database initialized" "FAIL"; fi
        if [[ -f /usr/local/bin/aide_check.sh ]] && [[ -x /usr/local/bin/aide_check.sh ]]; then
            record_test "AIDE check script installed" "PASS"
            if /usr/local/bin/aide_check.sh &>/dev/null; then record_test "AIDE check script runs" "PASS"; else record_test "AIDE check script runs" "FAIL"; fi
            if crontab -l 2>/dev/null | grep -Fq "/usr/local/bin/aide_check.sh"; then record_test "AIDE cron job scheduled" "PASS"; else record_test "AIDE cron job scheduled" "FAIL"; fi
        else
            record_test "AIDE check script installed" "FAIL"
        fi
    else
        record_test "AIDE installed" "FAIL"
    fi
fi

# =============================================================================
# PHASE 2: run_2.sh (client installation) - Full E2E like run_1
# =============================================================================
if [[ "$PHASE" == "2" ]]; then
    mkdir -p config
    echo "export LOGIN_UNAME='$(whoami)'" > config/user_config.env
    export CI_E2E=true
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical

    # Re-apply debconf preseed (like Phase 1) to prevent tzdata/postfix/cron hangs
    log_header "Pre-seeding debconf (prevent tty hangs)"
    sudo bash "$PROJECT_ROOT/install/utils/debconf_preseed.sh"

    # Step 1: Install dependencies (like run_2.sh when not --skip-deps)
    log_header "Installing dependencies"
    if ! ./install/utils/install_dependencies.sh --production; then
        record_test "install_dependencies" "FAIL"
        print_test_summary
        exit 1
    fi
    record_test "install_dependencies" "PASS"

    # Step 2: Run ALL client install scripts (including Grandine, ETHGas - try build-from-source)
    log_header "Installing all clients (16 scripts)"
    install_fail=0
    idx=0
    total=${#CLIENT_SCRIPTS[@]}
    for script in "${CLIENT_SCRIPTS[@]}"; do
        [[ -f "$PROJECT_ROOT/$script" ]] || continue
        idx=$((idx + 1))
        log_info "  [$idx/$total] $(basename "$script")..."
        script_log="/tmp/e2e_client_$$_${idx}.log"
        set +e
        "$PROJECT_ROOT/$script" 2>&1 | tee "$script_log"
        exit_code=${PIPESTATUS[0]}
        set -e
        if [[ $exit_code -ne 0 ]]; then
            record_test "Install $(basename "$script")" "FAIL"
            dump_log_tail "$script_log" 30 "    "
            install_fail=$((install_fail + 1))
        else
            record_test "Install $(basename "$script")" "PASS"
        fi
        rm -f "$script_log"
    done
    if [[ $install_fail -gt 0 ]]; then
        log_error "$install_fail client(s) failed to install"
        print_test_summary
        exit 1
    fi

    # Step 3: Run run_2.sh with flags (tests the run_2 flow)
    log_header "Executing run_2.sh (flag flow)"
    run2_log="/tmp/run2_e2e_$$.log"
    if ! run_script_with_log "$run2_log" ./run_2.sh --execution=geth --consensus=prysm --mev=mev-boost --skip-deps; then
        record_test "run_2.sh execution" "FAIL"
        dump_log_tail "$run2_log" 50 "  "
        rm -f "$run2_log"
        print_test_summary
        exit 1
    fi
    rm -f "$run2_log"
    record_test "run_2.sh execution" "PASS"

    log_header "Verifying client installs"

    # Ensure ~/.cargo/bin exists for Reth (prebuilt installs there)
    mkdir -p "$HOME/.cargo/bin"

    verify_installed "Geth" command -v geth
    verify_installed "Besu" test -f "$HOME/besu/bin/besu"
    verify_installed "Erigon" test -f "$HOME/erigon/erigon"
    verify_installed "Nethermind" test -f "$HOME/nethermind/Nethermind.Runner"
    verify_installed "Nimbus-eth1" test -f "$HOME/nimbus-eth1/nimbus" -o -f "$HOME/nimbus-eth1/build/nimbus" -o -f "$HOME/nimbus-eth1/nimbus-eth1"
    verify_installed "Ethrex" test -f "$HOME/ethrex/ethrex"
    verify_installed "Prysm" test -f "$HOME/prysm/prysm.sh"
    verify_installed "Lighthouse" test -f "$HOME/lighthouse/lighthouse"
    verify_installed "Lodestar" command -v lodestar
    verify_installed "Teku" test -f "$HOME/teku/bin/teku"
    verify_installed "Nimbus" test -f "$HOME/nimbus/build/nimbus_beacon_node"
    verify_installed "Grandine" test -f "$HOME/grandine/target/release/grandine"
    verify_installed "MEV-Boost" test -f "$HOME/mev-boost/mev-boost"
    verify_installed "Commit-Boost" test -f "$HOME/commit-boost/commit-boost-pbs"
    verify_installed "ETHGas" test -f "$HOME/ethgas/target/release/ethgas_commit"
    verify_installed "Reth" test -f "$HOME/.cargo/bin/reth"
    verify_installed "JWT secret" test -f "$HOME/secrets/jwt.hex"
    verify_installed "eth1 systemd service" bash -c 'systemctl list-unit-files 2>/dev/null | grep -q "eth1.service"'
fi

# =============================================================================
# SUMMARY
# =============================================================================
print_test_summary
