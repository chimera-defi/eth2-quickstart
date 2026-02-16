#!/bin/bash

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults
# Run as root or with sudo (re-execs with sudo if needed). Ends with mandatory reboot.

set -Eeuo pipefail

# Source required files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/exports.sh"
source "$SCRIPT_DIR/lib/common_functions.sh"

# Require root - re-exec with sudo if running as non-root (preserves SUDO_USER for key collection)
require_sudo_or_root "$@"

# Docker E2E: ensure keys exist before collect (is_docker only - never production)
ensure_docker_e2e_keys

# Strategy 1 (PR 90): CI/Docker - ensure keys exist when root has none (E2E only)
if [[ $EUID -eq 0 ]] && [[ ! -s /root/.ssh/authorized_keys ]] && { [[ "${CI:-}" == "true" ]] || is_docker; }; then
    mkdir -p /root/.ssh
    printf '%s\n' "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test-key-for-e2e" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    log_info "CI/Docker: ensuring E2E test keys exist"
fi

# Strategy 5 (PR 90): CI_KEYS_FILE bypass - when test passes pre-created keys, use them directly
# Lockout prevention: collect BEFORE exec redirect (so $(...) captures echo)
COLLECTED_KEYS_FILE=""
if [[ -n "${CI_KEYS_FILE:-}" && -f "${CI_KEYS_FILE}" && -s "${CI_KEYS_FILE}" ]]; then
    COLLECTED_KEYS_FILE="${CI_KEYS_FILE}"
    log_info "Using CI-provided keys file: $CI_KEYS_FILE"
else
    COLLECTED_KEYS_FILE=$(collect_and_backup_authorized_keys) || true
fi
if [[ -z "$COLLECTED_KEYS_FILE" ]] || [[ ! -s "$COLLECTED_KEYS_FILE" ]]; then
    log_error "CRITICAL: No SSH keys found (root, SUDO_USER, /home/*)"
    log_error "Diagnostics: root_exists=$([[ -f /root/.ssh/authorized_keys ]] && echo yes || echo no) root_size=$([[ -s /root/.ssh/authorized_keys ]] && wc -c < /root/.ssh/authorized_keys || echo 0) SUDO_USER=${SUDO_USER:-unset} CI=${CI:-unset}"
    log_error "Add your key first: ssh-copy-id root@<your-server-ip>"
    log_error "Or if using sudo: ssh-copy-id <your-user>@<your-server-ip>"
    log_error "Without this, you will be locked out after reboot."
    exit 1
fi

LOG_DIR="/var/log/eth2-quickstart"
LOG_FILE="$LOG_DIR/run_1_$(date +%Y%m%d_%H%M%S).log"
ensure_directory "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
log_info "Log file: $LOG_FILE"

log_info "Starting system setup - Phase 1..."
log_info "Using configuration: user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry"

check_system_compatibility

# Prevent apt/dpkg from prompting (postfix, cron, tzdata, needrestart)
# Postfix is NOT needed for Ethereum nodes - we avoid it via --no-install-recommends
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export TZ=UTC
if [[ -f "$SCRIPT_DIR/install/utils/debconf_preseed.sh" ]]; then
    log_info "Pre-seeding debconf for non-interactive install..."
    "$SCRIPT_DIR/install/utils/debconf_preseed.sh"
fi

# Update system packages
log_info "Updating system packages..."
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y || log_warn "Some packages could not be removed"
log_info "System packages updated"

# Create user with sudo + SSH key migration BEFORE hardening SSH
# SSH key-only auth (no password) - more secure
log_info "Setting up user: $LOGIN_UNAME"
setup_secure_user "$LOGIN_UNAME" "" "$COLLECTED_KEYS_FILE"
rm -f "$COLLECTED_KEYS_FILE"

# Preserve DEBIAN_* through sudo so Phase 2 apt/dpkg stay noninteractive (no tzdata/NTP prompts)
if [[ ! -f /etc/sudoers.d/99-noninteractive ]]; then
    echo 'Defaults env_keep += "DEBIAN_FRONTEND DEBIAN_PRIORITY TZ"' > /etc/sudoers.d/99-noninteractive
    chmod 440 /etc/sudoers.d/99-noninteractive
    log_info "Sudo configured for non-interactive apt"
fi

# Harden SSH (after user exists with keys)
configure_ssh "$YourSSHPortNumber" "$SCRIPT_DIR"

# Firewall, fail2ban, AIDE
log_info "Running consolidated security setup..."
chmod +x "$SCRIPT_DIR/install/security/consolidated_security.sh"
"$SCRIPT_DIR/install/security/consolidated_security.sh"

# OS hardening: sysctl, shared memory, disable unnecessary services
apply_network_security
setup_security_monitoring

# Update AIDE db to include all files we just installed (security_monitor.sh, etc.)
# So the first aide_check won't report false changes
if command -v aide &>/dev/null && [[ -f /var/lib/aide/aide.db ]]; then
    log_info "Updating AIDE database with installed files..."
    if aide --config=/etc/aide/aide.conf --update 2>/dev/null; then
        [[ -f /var/lib/aide/aide.db.new ]] && mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        log_info "AIDE database updated"
    else
        log_warn "AIDE update had issues - first aide_check may report changes"
    fi
fi

# Copy eth2-quickstart to new user's home so they can run Phase 2 after reboot
# Without this, the new user cannot find the folder (e.g. if it was in /root/.eth2-quickstart)
USER_INSTALL_DIR="/home/$LOGIN_UNAME/eth2-quickstart"
SCRIPT_REAL="$(realpath "$SCRIPT_DIR" 2>/dev/null || echo "$SCRIPT_DIR")"
DEST_REAL="$(realpath "$USER_INSTALL_DIR" 2>/dev/null || echo "$USER_INSTALL_DIR")"
if [[ "$SCRIPT_REAL" == "$DEST_REAL" ]]; then
    log_info "eth2-quickstart already at $USER_INSTALL_DIR (idempotent)"
    chown -R "$LOGIN_UNAME:$LOGIN_UNAME" "$USER_INSTALL_DIR"
else
    rm -rf "$USER_INSTALL_DIR"
    cp -a "$SCRIPT_DIR" "$USER_INSTALL_DIR"
    chown -R "$LOGIN_UNAME:$LOGIN_UNAME" "$USER_INSTALL_DIR"
    log_info "eth2-quickstart copied to ~/eth2-quickstart for user $LOGIN_UNAME"
fi

# Generate and save handoff information (auto-detects server IP)
generate_handoff_info "$LOGIN_UNAME" "" "" "$YourSSHPortNumber"

log_info "=== SETUP COMPLETE ==="
log_info "Reboot required: sudo reboot"
log_info "Handoff info saved to /root/handoff_info.txt"
log_info "Log: $LOG_FILE (view: ./install/utils/view_logs.sh --run1)"
