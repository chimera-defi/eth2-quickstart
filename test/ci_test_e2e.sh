#!/bin/bash
# E2E Test - Executes run_1.sh or run_2.sh and verifies results
# Run inside Docker with systemd: docker exec <container> /workspace/test/ci_test_e2e.sh
# Requires: PHASE=1 (root) or PHASE=2 (testuser) set by run_e2e.sh

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

log_header "Phase $PHASE End-to-End Test"
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
        grep -q "$LOGIN_UNAME" /root/handoff_info.txt && record_test "Handoff contains username" "PASS" || record_test "Handoff contains username" "FAIL"
    else
        record_test "Handoff info file created" "FAIL"
    fi
    id -u "$LOGIN_UNAME" &>/dev/null && record_test "User '$LOGIN_UNAME' created" "PASS" || record_test "User '$LOGIN_UNAME' created" "FAIL"
    sudo -u "$LOGIN_UNAME" sudo -n true 2>/dev/null && record_test "User has sudo (NOPASSWD)" "PASS" || record_test "User has sudo (NOPASSWD)" "FAIL"
    [[ -f /home/${LOGIN_UNAME}/.ssh/authorized_keys ]] && record_test "SSH keys migrated to new user" "PASS" || record_test "SSH keys migrated to new user" "FAIL"
    [[ -f /etc/ssh/sshd_config.backup ]] && record_test "SSH config backed up" "PASS" || record_test "SSH config backed up" "FAIL"
    [[ -f /etc/sysctl.d/99-eth2-hardening.conf ]] && record_test "Network hardening applied" "PASS" || record_test "Network hardening applied" "FAIL"
    [[ -f /usr/local/bin/security_monitor.sh ]] && record_test "Security monitoring script installed" "PASS" || record_test "Security monitoring script installed" "FAIL"
    ufw status 2>/dev/null | grep -q "Status: active" && record_test "UFW firewall active" "PASS" || record_test "UFW firewall active" "FAIL"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        record_test "Fail2ban service running" "PASS"
        fail2ban-client status 2>/dev/null | grep -q "sshd" && record_test "Fail2ban sshd jail active" "PASS" || record_test "Fail2ban sshd jail active" "FAIL"
    else
        record_test "Fail2ban service running" "FAIL"
    fi
    if command -v aide &>/dev/null; then
        record_test "AIDE installed" "PASS"
        [[ -f /var/lib/aide/aide.db ]] && record_test "AIDE database initialized" "PASS" || record_test "AIDE database initialized" "FAIL"
        if [[ -f /usr/local/bin/aide_check.sh ]] && [[ -x /usr/local/bin/aide_check.sh ]]; then
            record_test "AIDE check script installed" "PASS"
            /usr/local/bin/aide_check.sh &>/dev/null && record_test "AIDE check script runs" "PASS" || record_test "AIDE check script runs" "FAIL"
            crontab -l 2>/dev/null | grep -Fq "/usr/local/bin/aide_check.sh" && record_test "AIDE cron job scheduled" "PASS" || record_test "AIDE cron job scheduled" "FAIL"
        else
            record_test "AIDE check script installed" "FAIL"
        fi
    else
        record_test "AIDE installed" "FAIL"
    fi
fi

# =============================================================================
# PHASE 2: run_2.sh (client installation)
# =============================================================================
if [[ "$PHASE" == "2" ]]; then
    mkdir -p config
    echo "export LOGIN_UNAME='$(whoami)'" > config/user_config.env

    log_header "Executing run_2.sh"
    export CI_E2E=true
    export DEBIAN_FRONTEND=noninteractive

    run2_log="/tmp/run2_e2e_$$.log"
    if run_script_with_log "$run2_log" ./run_2.sh --execution=geth --consensus=prysm --mev=mev-boost --skip-deps; then
        record_test "run_2.sh execution" "PASS"
    else
        record_test "run_2.sh execution" "FAIL"
        dump_log_tail "$run2_log" 50 "  "
        rm -f "$run2_log"
        print_test_summary
        exit 1
    fi
    rm -f "$run2_log"

    log_header "Verifying run_2.sh Results"
    command -v geth &>/dev/null && record_test "Geth binary installed" "PASS" || record_test "Geth binary installed" "FAIL"
    [[ -f "$HOME/prysm/prysm.sh" ]] && record_test "Prysm installed" "PASS" || record_test "Prysm installed" "FAIL"
    [[ -f "$HOME/mev-boost/mev-boost" ]] && record_test "MEV-Boost installed" "PASS" || record_test "MEV-Boost installed" "FAIL"
    [[ -f "$HOME/secrets/jwt.hex" ]] && record_test "JWT secret exists" "PASS" || record_test "JWT secret exists" "FAIL"
    systemctl list-unit-files 2>/dev/null | grep -q "eth1.service" && record_test "eth1 systemd service created" "PASS" || record_test "eth1 systemd service created" "FAIL"
fi

# =============================================================================
# SUMMARY
# =============================================================================
print_test_summary
