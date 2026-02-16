#!/bin/bash

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults
# Run as root or with sudo (re-execs with sudo if needed). Ends with mandatory reboot.

set -Eeuo pipefail

# Source required files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/exports.sh"
source "$SCRIPT_DIR/lib/common_functions.sh"

# Require root - re-exec with sudo if running as non-root
require_sudo_or_root "$@"

log_info "Starting system setup - Phase 1..."
log_info "Using configuration: user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry"

check_system_compatibility

# Lockout prevention: collect and back up authorized_keys from all sources (root, SUDO_USER)
# Must have keys somewhere before we create new user and harden SSH
COLLECTED_KEYS_FILE=""
COLLECTED_KEYS_FILE=$(collect_and_backup_authorized_keys) || true
if [[ -z "$COLLECTED_KEYS_FILE" ]] || [[ ! -s "$COLLECTED_KEYS_FILE" ]]; then
    log_error "CRITICAL: No SSH keys found in /root/.ssh/authorized_keys or \$SUDO_USER's ~/.ssh/authorized_keys"
    log_error "Add your key first: ssh-copy-id root@<your-server-ip>"
    log_error "Or if using sudo: ssh-copy-id <your-user>@<your-server-ip>"
    log_error "Without this, you will be locked out after reboot."
    exit 1
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

# Harden SSH (after user exists with keys)
configure_ssh "$YourSSHPortNumber" "$SCRIPT_DIR"

# Firewall, fail2ban, AIDE
log_info "Running consolidated security setup..."
chmod +x "$SCRIPT_DIR/install/security/consolidated_security.sh"
"$SCRIPT_DIR/install/security/consolidated_security.sh"

# OS hardening: sysctl, shared memory, disable unnecessary services
apply_network_security
setup_security_monitoring

# Generate and save handoff information (auto-detects server IP)
generate_handoff_info "$LOGIN_UNAME" "" "" "$YourSSHPortNumber"

log_info "=== SETUP COMPLETE ==="
log_info "Reboot required: sudo reboot"
log_info "Handoff info saved to /root/handoff_info.txt"
