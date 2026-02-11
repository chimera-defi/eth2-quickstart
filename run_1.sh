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

# Use sane defaults - no need to validate since exports.sh has them
log_info "Using configuration: user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry"

# Basic system check (minimal)
check_system_compatibility

# Update system packages
log_info "Updating system packages..."
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y || log_warn "Some packages could not be removed"

log_info "System packages updated"

# Generate secure password and setup user BEFORE SSH hardening
# This ensures the new user exists and has SSH keys before we restrict access
log_info "Setting up user: $LOGIN_UNAME"
USER_PASSWORD=$(generate_secure_password 16)
setup_secure_user "$LOGIN_UNAME" "$USER_PASSWORD"
configure_sudo_nopasswd "$LOGIN_UNAME"

log_info "User setup complete"

# Setup SSH with security hardening (after user is created with keys)
configure_ssh "$YourSSHPortNumber" "$SCRIPT_DIR"

# Note: fail2ban is configured by consolidated_security.sh below

# Run consolidated security setup
log_info "Running consolidated security setup..."
chmod +x "$SCRIPT_DIR/install/security/consolidated_security.sh"
"$SCRIPT_DIR/install/security/consolidated_security.sh"

log_info "Consolidated security setup complete"

# Disable shared memory for security
log_info "Disabling shared memory..."
append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'

log_info "Shared memory disabled"

# Apply additional security configurations
# Note: AIDE/intrusion detection is already set up by consolidated_security.sh above
log_info "Applying additional security configurations..."
secure_config_files
apply_network_security
setup_security_monitoring

log_info "Security configurations applied"

# Get server IP
log_info "Determining server IP..."
SERVER_IP=$(curl -s v4.ident.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

# Generate and save handoff information
generate_handoff_info "$LOGIN_UNAME" "$USER_PASSWORD" "$SERVER_IP" "$YourSSHPortNumber"

log_info "=== SETUP COMPLETE ==="
log_info "Reboot required: sudo reboot"
log_info "Handoff info saved to /root/handoff_info.txt"
