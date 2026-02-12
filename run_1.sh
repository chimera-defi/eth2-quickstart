#!/bin/bash

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults
# MUST be run as root. Ends with mandatory reboot.

set -Eeuo pipefail

# Source required files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/exports.sh"
source "$SCRIPT_DIR/lib/common_functions.sh"

# Check if running as root
require_root

log_info "Starting system setup - Phase 1..."
log_info "Using configuration: user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry"

check_system_compatibility

# Update system packages
log_info "Updating system packages..."
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y || log_warn "Some packages could not be removed"
log_info "System packages updated"

# Create user with sudo + SSH key migration BEFORE hardening SSH
log_info "Setting up user: $LOGIN_UNAME"
USER_PASSWORD=$(generate_secure_password 16)
setup_secure_user "$LOGIN_UNAME" "$USER_PASSWORD"

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
generate_handoff_info "$LOGIN_UNAME" "$USER_PASSWORD" "" "$YourSSHPortNumber"

log_info "=== SETUP COMPLETE ==="
log_info "Reboot required: sudo reboot"
log_info "Handoff info saved to /root/handoff_info.txt"
