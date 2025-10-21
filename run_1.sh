#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 1
# Initial system hardening and user setup

source ./exports.sh
source ./lib/utils.sh
source ./lib/common_functions.sh
require_root

log_info "Starting system setup - Phase 1..."

# Validate critical configuration variables
log_info "Validating configuration variables..."
if [[ -z "$LOGIN_UNAME" ]]; then
    log_error "LOGIN_UNAME is not set in exports.sh"
    exit 1
fi

if [[ -z "$YourSSHPortNumber" ]]; then
    log_error "YourSSHPortNumber is not set in exports.sh"
    exit 1
fi

if [[ -z "$maxretry" ]]; then
    log_error "maxretry is not set in exports.sh"
    exit 1
fi

# Validate username format
if ! validate_user_input "$LOGIN_UNAME" "^[a-zA-Z0-9_-]+$" 32; then
    log_error "Invalid username format: $LOGIN_UNAME"
    exit 1
fi

# Validate SSH port
if ! validate_user_input "$YourSSHPortNumber" "^[0-9]+$" 5; then
    log_error "Invalid SSH port: $YourSSHPortNumber"
    exit 1
fi

if [[ "$YourSSHPortNumber" -lt 1 || "$YourSSHPortNumber" -gt 65535 ]]; then
    log_error "SSH port out of range: $YourSSHPortNumber (must be 1-65535)"
    exit 1
fi

log_info "✓ Configuration validation passed"

# Check system compatibility first
if ! check_system_compatibility; then
    log_error "System compatibility check failed"
    exit 1
fi

# Update system packages
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

if ! apt autoremove -y; then
    log_warn "Failed to remove unused packages (non-critical)"
fi

log_info "✓ System packages updated successfully"

# Setup SSH with safe defaults
log_info "Configuring SSH with safe defaults..."
if [[ -f /etc/ssh/sshd_config ]]; then
    log_info "Backing up existing SSH config"
    if ! mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bkup; then
        log_error "Failed to backup SSH config"
        exit 1
    fi
fi

if [[ ! -f ./sshd_config ]]; then
    log_error "SSH config file not found: ./sshd_config"
    exit 1
fi

if ! cp ./sshd_config /etc/ssh/sshd_config; then
    log_error "Failed to copy SSH config"
    exit 1
fi

# Copy it back for review / commit 
if ! cp /etc/ssh/sshd_config ./; then
    log_warn "Failed to copy SSH config back to project directory"
fi

log_info "✓ SSH configuration updated successfully"

# Basic hardening
log_info "Setting up basic system hardening..."

# Dependencies are installed centrally via install_dependencies.sh
# Install and configure fail2ban
log_info "Installing and configuring fail2ban..."
if ! install_dependencies fail2ban; then
    log_error "Failed to install fail2ban"
    exit 1
fi

# Configure fail2ban with proper error handling
log_info "Configuring fail2ban jails..."
if ! cat >> /etc/fail2ban/jail.local << EOF
## block hosts trying to abuse our server as a forward proxy
[nginx-proxy]
enabled = true
port    = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400

[sshd]
enabled = true
port = $YourSSHPortNumber
filter = sshd
logpath = /var/log/auth.log
maxretry = $maxretry
bantime = 3600
findtime = 600
EOF
then
    log_error "Failed to configure fail2ban"
    exit 1
fi

# Restart fail2ban service
log_info "Restarting fail2ban service..."
if ! systemctl restart fail2ban; then
    log_error "Failed to restart fail2ban service"
    exit 1
fi

log_info "✓ Fail2ban configured and started successfully"

# Generate secure password for user
log_info "Generating secure password for user: $LOGIN_UNAME"
USER_PASSWORD=$(generate_secure_password 16)

# Setup secure user with password and SSH keys
log_info "Setting up secure user: $LOGIN_UNAME"
if ! setup_secure_user "$LOGIN_UNAME" "$USER_PASSWORD"; then
    log_error "Failed to setup user: $LOGIN_UNAME"
    exit 1
fi

# Configure sudo without password
log_info "Configuring sudo privileges for user: $LOGIN_UNAME"
if ! configure_sudo_nopasswd "$LOGIN_UNAME"; then
    log_error "Failed to configure sudo for user: $LOGIN_UNAME"
    exit 1
fi

# Configure firewall
log_info "Configuring firewall rules..."
if [[ ! -f ./install/security/firewall.sh ]]; then
    log_error "Firewall script not found: ./install/security/firewall.sh"
    exit 1
fi

if ! chmod +x ./install/security/firewall.sh; then
    log_error "Failed to make firewall script executable"
    exit 1
fi

if ! ./install/security/firewall.sh; then
    log_error "Failed to configure firewall"
    exit 1
fi

log_info "✓ Firewall configuration completed"

# Time synchronization is configured centrally via install_dependencies.sh

# Disable shared memory
log_info "Disabling shared memory for security..."
if ! append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'; then
    log_error "Failed to disable shared memory"
    exit 1
fi
log_info "✓ Shared memory disabled"

# Secure file permissions
log_info "Securing file permissions..."
secure_config_files

# Apply network security
log_info "Applying network security configurations..."
apply_network_security

# Setup security monitoring
log_info "Setting up security monitoring..."
setup_security_monitoring

# Setup intrusion detection
log_info "Setting up intrusion detection..."
setup_intrusion_detection

# Display system status
log_info "Displaying system status..."
echo "=== NETWORK SETTINGS ==="
ss -tulpn
echo
echo "=== SSH CONFIGURATION ==="
sshd -t
echo
echo "=== FIREWALL STATUS ==="
ufw status
echo

# Get server IP for handoff
log_info "Determining server IP address..."
SERVER_IP=$(curl -s v4.ident.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

# Generate and display handoff information
generate_handoff_info "$LOGIN_UNAME" "$USER_PASSWORD" "$SERVER_IP"

# Validate handoff setup
log_info "Validating handoff setup..."
if ! id -u "$LOGIN_UNAME" >/dev/null 2>&1; then
    log_error "User $LOGIN_UNAME does not exist"
    exit 1
fi

if ! groups "$LOGIN_UNAME" | grep -q sudo; then
    log_error "User $LOGIN_UNAME is not in sudo group"
    exit 1
fi

if [[ ! -f "/etc/sudoers.d/$LOGIN_UNAME" ]]; then
    log_error "Sudo configuration not found for $LOGIN_UNAME"
    exit 1
fi

log_info "✓ Handoff setup validation passed"

# Security validation will be run at the end of run_2.sh
log_info "Security validation will be run at the end of run_2.sh"

log_info "=== SETUP COMPLETE ==="
log_info "Run 'sudo reboot' for all changes to take effect"
log_info "After reboot, login via: ssh $LOGIN_UNAME@$SERVER_IP"
log_info "Then run: ./run_2.sh"

# Save handoff information to file for reference
log_info "Saving handoff information to file..."
cat > "/root/handoff_info.txt" << EOF
User: $LOGIN_UNAME
Password: $USER_PASSWORD
Server IP: $SERVER_IP
SSH Command: ssh $LOGIN_UNAME@$SERVER_IP
Next Step: ./run_2.sh
Generated: $(date)
EOF

chmod 600 "/root/handoff_info.txt"
log_info "Handoff information saved to /root/handoff_info.txt"
