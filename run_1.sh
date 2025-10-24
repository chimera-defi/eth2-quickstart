#!/bin/bash

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults

# Source required files
source ./exports.sh
source ./lib/utils.sh
source ./lib/common_functions.sh

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

log_info "✓ System packages updated"

# Setup SSH with security hardening
configure_ssh "$YourSSHPortNumber"

# Setup fail2ban
setup_fail2ban

# Generate secure password and setup user
log_info "Setting up user: $LOGIN_UNAME"
USER_PASSWORD=$(generate_secure_password 16)
setup_secure_user "$LOGIN_UNAME" "$USER_PASSWORD"
configure_sudo_nopasswd "$LOGIN_UNAME"

log_info "✓ User setup complete"

# Configure firewall
log_info "Configuring firewall..."
chmod +x ./install/security/firewall.sh
./install/security/firewall.sh

log_info "✓ Firewall configured"

# Disable shared memory for security
log_info "Disabling shared memory..."
append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'

log_info "✓ Shared memory disabled"

# Apply security configurations
log_info "Applying security configurations..."
secure_config_files
apply_network_security
setup_security_monitoring
setup_intrusion_detection

log_info "✓ Security configurations applied"

# Get server IP
log_info "Determining server IP..."
SERVER_IP=$(curl -s v4.ident.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

# Display system status
echo "=== SYSTEM STATUS ==="
echo "Network: $(ss -tulpn | wc -l) active connections"
echo "SSH: $(sshd -t 2>&1 | grep -c 'OK' || echo '0') config checks passed"
echo "Firewall: $(ufw status | grep -c 'Status: active' || echo '0') active"
echo

# Generate handoff information
generate_handoff_info "$LOGIN_UNAME" "$USER_PASSWORD" "$SERVER_IP"

# Save handoff info
cat > "/root/handoff_info.txt" << EOF
User: $LOGIN_UNAME
Password: $USER_PASSWORD
Server IP: $SERVER_IP
SSH Command: ssh $LOGIN_UNAME@$SERVER_IP
Next Step: ./run_2.sh
Generated: $(date)
EOF

chmod 600 "/root/handoff_info.txt"

log_info "=== SETUP COMPLETE ==="
log_info "Reboot required: sudo reboot"
log_info "After reboot: ssh $LOGIN_UNAME@$SERVER_IP"
log_info "Then run: ./run_2.sh"