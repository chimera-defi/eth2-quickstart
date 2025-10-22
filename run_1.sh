#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults

# Source required files
source ./exports.sh
source ./lib/utils.sh
source ./lib/common_functions.sh

# Check if running as root
require_root

log_info "Starting system setup - Phase 1..."

# Validate critical configuration variables
log_info "Validating configuration..."
if [[ -z "$LOGIN_UNAME" || -z "$YourSSHPortNumber" || -z "$maxretry" ]]; then
    log_error "Critical configuration variables not set in exports.sh"
    exit 1
fi

# Validate username format
if [[ ! "$LOGIN_UNAME" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    log_error "Invalid username format: $LOGIN_UNAME (must start with letter, contain only lowercase letters, numbers, hyphens, underscores)"
    exit 1
fi

# Validate SSH port
if [[ ! "$YourSSHPortNumber" =~ ^[0-9]+$ ]] || [[ "$YourSSHPortNumber" -lt 1 ]] || [[ "$YourSSHPortNumber" -gt 65535 ]]; then
    log_error "Invalid SSH port: $YourSSHPortNumber (must be 1-65535)"
    exit 1
fi

log_info "Using configuration: user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry"

# Basic system check with error handling
if ! check_system_compatibility; then
    log_error "System compatibility check failed"
    exit 1
fi

# Update system packages with proper error handling
log_info "Updating system packages..."
if ! apt update -y; then
    log_error "Failed to update package lists"
    exit 1
fi

if ! apt upgrade -y; then
    log_error "Failed to upgrade packages"
    exit 1
fi

if ! apt full-upgrade -y; then
    log_error "Failed to perform full upgrade"
    exit 1
fi

# Handle autoremove gracefully
if ! apt autoremove -y; then
    log_warn "Some packages could not be removed (this is usually safe)"
fi

log_info "✓ System packages updated"

# Setup SSH with safe defaults
log_info "Configuring SSH..."

# Backup existing SSH config
if [[ -f /etc/ssh/sshd_config ]]; then
    if ! mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bkup; then
        log_error "Failed to backup existing SSH config"
        exit 1
    fi
    log_info "✓ SSH config backed up"
fi

# Copy new SSH config
if [[ ! -f ./sshd_config ]]; then
    log_error "SSH config file not found: ./sshd_config"
    exit 1
fi

if ! cp ./sshd_config /etc/ssh/sshd_config; then
    log_error "Failed to copy SSH config"
    exit 1
fi

# Copy back for reference (optional)
if ! cp /etc/ssh/sshd_config ./; then
    log_warn "Could not copy SSH config back (non-critical)"
fi

log_info "✓ SSH configured"

# Install and configure fail2ban
log_info "Setting up fail2ban..."
install_dependencies fail2ban

# Configure fail2ban with sane defaults
log_info "Configuring fail2ban rules..."
cat >> /etc/fail2ban/jail.local << EOF
[nginx-proxy]
enabled = true
port = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[sshd]
enabled = true
port = $YourSSHPortNumber
filter = sshd
logpath = /var/log/auth.log
maxretry = $maxretry
bantime = 3600
findtime = 600
EOF

if ! systemctl restart fail2ban; then
    log_error "Failed to restart fail2ban"
    exit 1
fi

log_info "✓ Fail2ban configured"

# Generate secure password and setup user
log_info "Setting up user: $LOGIN_UNAME"

# Generate secure password
if ! USER_PASSWORD=$(generate_secure_password 16); then
    log_error "Failed to generate secure password"
    exit 1
fi

# Setup user
if ! setup_secure_user "$LOGIN_UNAME" "$USER_PASSWORD"; then
    log_error "Failed to setup secure user"
    exit 1
fi

# Configure sudo
if ! configure_sudo_nopasswd "$LOGIN_UNAME"; then
    log_error "Failed to configure sudo for user"
    exit 1
fi

log_info "✓ User setup complete"

# Configure firewall
log_info "Configuring firewall..."
if [[ ! -f ./install/security/firewall.sh ]]; then
    log_error "Firewall script not found: ./install/security/firewall.sh"
    exit 1
fi

chmod +x ./install/security/firewall.sh
if ! ./install/security/firewall.sh; then
    log_error "Failed to configure firewall"
    exit 1
fi

log_info "✓ Firewall configured"

# Disable shared memory for security
log_info "Disabling shared memory..."

# Backup fstab before modification
if ! cp /etc/fstab /etc/fstab.bkup; then
    log_error "Failed to backup /etc/fstab"
    exit 1
fi

append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'

log_info "✓ Shared memory disabled"

# Apply security configurations
log_info "Applying security configurations..."

if ! secure_config_files; then
    log_error "Failed to secure configuration files"
    exit 1
fi

if ! apply_network_security; then
    log_error "Failed to apply network security"
    exit 1
fi

if ! setup_security_monitoring; then
    log_error "Failed to setup security monitoring"
    exit 1
fi

if ! setup_intrusion_detection; then
    log_error "Failed to setup intrusion detection"
    exit 1
fi

log_info "✓ Security configurations applied"

# Get server IP with validation
log_info "Determining server IP..."
SERVER_IP=""
for ip_service in "v4.ident.me" "ifconfig.me" "ipinfo.io/ip"; do
    if SERVER_IP=$(curl -s --connect-timeout 5 --max-time 10 "$ip_service" 2>/dev/null); then
        # Validate IP format
        if [[ "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log_info "✓ Server IP detected: $SERVER_IP"
            break
        fi
    fi
done

if [[ -z "$SERVER_IP" ]]; then
    log_warn "Could not determine server IP automatically"
    SERVER_IP="YOUR_SERVER_IP"
fi

# Display system status with error handling
log_info "=== SYSTEM STATUS ==="
{
    echo "Network: $(ss -tulpn 2>/dev/null | wc -l || echo 'N/A') active connections"
    echo "SSH: $(sshd -t 2>&1 | grep -c 'OK' || echo '0') config checks passed"
    echo "Firewall: $(ufw status 2>/dev/null | grep -c 'Status: active' || echo '0') active"
    echo "Memory: $(free -h | awk '/^Mem:/{print $3 "/" $2}' || echo 'N/A') used"
    echo "Disk: $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}' || echo 'N/A') used"
} | while read -r line; do
    log_info "$line"
done

# Generate secure handoff information
log_info "Generating secure handoff information..."

# Create secure handoff file with restricted permissions
HANDOFF_FILE="/root/handoff_info.txt"
{
    echo "# Ethereum Node Setup - Phase 1 Complete"
    echo "# Generated: $(date)"
    echo "# IMPORTANT: This file contains sensitive information"
    echo ""
    echo "USERNAME=$LOGIN_UNAME"
    echo "PASSWORD=$USER_PASSWORD"
    echo "SERVER_IP=$SERVER_IP"
    echo "SSH_COMMAND=ssh $LOGIN_UNAME@$SERVER_IP"
    echo "NEXT_STEP=./run_2.sh"
    echo ""
    echo "# Security Notes:"
    echo "# 1. Change password immediately after first login"
    echo "# 2. Consider setting up SSH key authentication"
    echo "# 3. User has sudo privileges without password prompt"
    echo "# 4. All Ethereum client data will be stored in /home/$LOGIN_UNAME"
} > "$HANDOFF_FILE"

if [[ -f "$HANDOFF_FILE" ]]; then
    chmod 600 "$HANDOFF_FILE"
    log_info "✓ Secure handoff information saved to: $HANDOFF_FILE"
else
    log_error "Failed to create handoff information file"
    exit 1
fi

# Display handoff information to user
log_info "=== SETUP COMPLETE ==="
log_info ""
log_info "🔐 LOGIN CREDENTIALS:"
log_info "   Username: $LOGIN_UNAME"
log_info "   Password: $USER_PASSWORD"
log_info "   Server IP: $SERVER_IP"
log_info ""
log_info "📋 NEXT STEPS:"
log_info "   1. Reboot the system: sudo reboot"
log_info "   2. SSH to server: ssh $LOGIN_UNAME@$SERVER_IP"
log_info "   3. Change password: passwd"
log_info "   4. Run phase 2: ./run_2.sh"
log_info ""
log_info "⚠️  SECURITY REMINDERS:"
log_info "   • Change the password immediately after first login"
log_info "   • Consider setting up SSH key authentication"
log_info "   • Handoff info saved to: $HANDOFF_FILE"
log_info ""
log_info "✅ Phase 1 setup completed successfully!"