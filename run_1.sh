#!/bin/bash

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults
# Run as root or with sudo (re-execs with sudo if needed). Ends with mandatory reboot.

set -Eeuo pipefail

# Source required files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/exports.sh"
source "$SCRIPT_DIR/lib/common_functions.sh"

# Help flag (before privilege checks so non-root users can inspect usage)
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            cat <<'EOF'
Usage: ./run_1.sh [OPTIONS]

Phase 1: system hardening and secure user setup.
Run as root (or via sudo), then reboot before Phase 2.

Options:
  --use-modular-hardening    Use the standalone modular hardening script
                             (allows independent hardening on existing servers)
  --preserve-ssh-port        Keep current SSH port (for use with modular hardening)
  --skip-user-creation       Skip user creation (for hardening existing servers)
  --help, -h                 Show this help message

Examples:
  # Standard Phase 1 setup
  sudo ./run_1.sh

  # Use modular hardening (recommended for existing servers)
  sudo ./run_1.sh --use-modular-hardening --preserve-ssh-port

  # Harden existing server without user creation
  sudo ./run_1.sh --use-modular-hardening --skip-user-creation --preserve-ssh-port

Note: For standalone server hardening without Phase 1 setup, you can also use:
  ./install/security/harden_server.sh --preserve-port --non-interactive
EOF
            exit 0
            ;;
    esac
done

# Parse additional flags
USE_MODULAR_HARDENING=false
PRESERVE_SSH_PORT=false
SKIP_USER_CREATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --use-modular-hardening)
            USE_MODULAR_HARDENING=true
            shift
            ;;
        --preserve-ssh-port)
            PRESERVE_SSH_PORT=true
            shift
            ;;
        --skip-user-creation)
            SKIP_USER_CREATION=true
            shift
            ;;
        *)
            # Skip unknown flags (they might be for require_sudo_or_root re-exec)
            shift
            ;;
    esac
done

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
# shellcheck disable=SC2154  # exported in exports.sh
log_info "Using configuration: user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry"

check_system_compatibility

# Prevent apt/dpkg from prompting (postfix, cron, tzdata, needrestart)
# Postfix is NOT needed for Ethereum nodes - we avoid it via --no-install-recommends
export DEBIAN_FRONTEND=noninteractive
export DEBIAN_PRIORITY=critical
export TZ=UTC
if [[ -f "$SCRIPT_DIR/install/utils/debconf_preseed.sh" ]]; then
    log_info "Pre-seeding debconf for non-interactive install..."
    chmod +x "$SCRIPT_DIR/install/utils/debconf_preseed.sh"
    "$SCRIPT_DIR/install/utils/debconf_preseed.sh"
fi

# Update system packages
log_info "Updating system packages..."
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y || log_warn "Some packages could not be removed"
log_info "System packages updated"

# Install all system-level dependencies as root (Phase 1)
# This avoids giving the eth user blanket sudo for apt-get
log_info "Installing system dependencies (Phase 1)..."
chmod +x "$SCRIPT_DIR/install/utils/install_dependencies.sh"
"$SCRIPT_DIR/install/utils/install_dependencies.sh" --phase1

# Create user with sudo + SSH key migration BEFORE hardening SSH
# SSH key-only auth (no password) - more secure
if [[ "$SKIP_USER_CREATION" != "true" ]]; then
    log_info "Setting up user: $LOGIN_UNAME"
    setup_secure_user "$LOGIN_UNAME" "" "$COLLECTED_KEYS_FILE"
    rm -f "$COLLECTED_KEYS_FILE"
else
    log_info "Skipping user creation (--skip-user-creation flag set)"
fi

# Preserve DEBIAN_* through sudo so Phase 2 apt/dpkg stay noninteractive (no tzdata/NTP prompts)
if [[ ! -f /etc/sudoers.d/99-noninteractive ]]; then
    echo 'Defaults env_keep += "DEBIAN_FRONTEND DEBIAN_PRIORITY TZ"' > /etc/sudoers.d/99-noninteractive
    chmod 440 /etc/sudoers.d/99-noninteractive
    log_info "Sudo configured for non-interactive apt"
fi

# Hardening: Use modular approach if requested, otherwise use existing inline approach
if [[ "$USE_MODULAR_HARDENING" == "true" ]]; then
    log_info "Using modular hardening approach..."
    
    # Build arguments for harden_server.sh
    HARDEN_ARGS=()
    HARDEN_ARGS+=(--non-interactive)  # run_1.sh is already interactive at the start
    
    if [[ "$PRESERVE_SSH_PORT" == "true" ]]; then
        HARDEN_ARGS+=(--preserve-port)
    fi
    
    # Call the standalone hardening script
    log_info "Calling standalone hardening script with: ${HARDEN_ARGS[*]}"
    chmod +x "$SCRIPT_DIR/install/security/harden_server.sh"
    
    # Set environment variables for the hardening script
    export PRESERVE_SSH_PORT="$PRESERVE_SSH_PORT"
    export SSH_PORT="$YourSSHPortNumber"
    
    if "$SCRIPT_DIR/install/security/harden_server.sh" "${HARDEN_ARGS[@]}"; then
        log_info "Modular hardening completed successfully"
    else
        log_error "Modular hardening failed"
        exit 1
    fi
else
    # Original inline hardening approach (backward compatible)
    log_info "Using standard hardening approach..."
    
    # Harden SSH (after user exists with keys)
    configure_ssh "$YourSSHPortNumber" "$SCRIPT_DIR"

    # Firewall, fail2ban, AIDE
    log_info "Running consolidated security setup..."
    chmod +x "$SCRIPT_DIR/install/security/consolidated_security.sh"
    "$SCRIPT_DIR/install/security/consolidated_security.sh"

    # OS hardening: sysctl, shared memory, disable unnecessary services
    apply_network_security
    setup_security_monitoring
fi

# Update AIDE db to include all files we just installed (security_monitor.sh, etc.)
# So the first aide_check won't report false changes
# This applies to both modular and standard hardening approaches
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
if [[ "$SKIP_USER_CREATION" != "true" ]]; then
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
else
    log_info "Skipping eth2-quickstart copy (user creation skipped)"
fi

# Generate and save handoff information (auto-detects server IP)
# Skip handoff generation if user creation was skipped (not applicable for existing servers)
if [[ "$SKIP_USER_CREATION" != "true" ]]; then
    generate_handoff_info "$LOGIN_UNAME" "" "" "$YourSSHPortNumber"
else
    log_info "Skipping handoff info generation (user creation skipped)"
    log_info "Server hardening completed on existing server"
    log_info "No reboot required for hardening-only mode"
fi

log_info "=== SETUP COMPLETE ==="

if [[ "$SKIP_USER_CREATION" != "true" ]]; then
    log_info "Reboot required: sudo reboot"
    log_info "Handoff info saved to /root/handoff_info.txt"
else
    log_info "Hardening complete - no reboot required (user creation skipped)"
fi

log_info "Log: $LOG_FILE (view: ./install/utils/view_logs.sh --run1)"
