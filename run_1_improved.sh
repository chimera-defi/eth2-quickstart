#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 1 (Improved Version)
# Initial system hardening and user setup

source ./exports.sh
source ./lib/utils.sh
source ./lib/common_functions.sh
require_root

# Configuration validation
validate_configuration() {
    log_info "Validating configuration..."
    
    # Validate critical variables
    if [[ -z "$LOGIN_UNAME" || "$LOGIN_UNAME" == "root" ]]; then
        log_error "LOGIN_UNAME must be set and cannot be 'root'"
        exit 1
    fi
    
    if [[ ! "$YourSSHPortNumber" =~ ^[0-9]+$ ]] || [[ "$YourSSHPortNumber" -lt 1024 || "$YourSSHPortNumber" -gt 65535 ]]; then
        log_error "YourSSHPortNumber must be a valid port number (1024-65535)"
        exit 1
    fi
    
    if [[ ! "$maxretry" =~ ^[0-9]+$ ]] || [[ "$maxretry" -lt 1 || "$maxretry" -gt 10 ]]; then
        log_error "maxretry must be a number between 1-10"
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

# Enhanced SSH configuration with security improvements
configure_ssh_secure() {
    log_info "Configuring SSH with enhanced security..."
    
    # Backup original config with timestamp
    local backup_file="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f /etc/ssh/sshd_config ]]; then
        log_info "Creating SSH config backup: $backup_file"
        cp /etc/ssh/sshd_config "$backup_file"
    fi
    
    # Create secure SSH config
    cat > /etc/ssh/sshd_config << EOF
# Enhanced SSH Configuration - Generated $(date)
Include /etc/ssh/sshd_config.d/*.conf

# Port and binding
Port $YourSSHPortNumber
AddressFamily inet
ListenAddress 0.0.0.0

# Host keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security settings
Protocol 2
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521

# Authentication
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin prohibit-password
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
StrictModes yes
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30s

# Security restrictions
AllowUsers $LOGIN_UNAME root
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
GatewayPorts no
PermitTunnel no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxStartups 10:30:60

# Disable unused features
UsePAM yes
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
GSSAPIAuthentication no
HostbasedAuthentication no
IgnoreRhosts yes
IgnoreUserKnownHosts yes

# Subsystem
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

    # Test SSH configuration
    if ! sshd -t; then
        log_error "SSH configuration test failed, restoring backup"
        cp "$backup_file" /etc/ssh/sshd_config
        exit 1
    fi
    
    log_info "SSH configuration updated successfully"
}

# Enhanced user creation with security validation
create_secure_user() {
    log_info "Creating secure user: $LOGIN_UNAME"
    
    # Check if user already exists
    if id -u "$LOGIN_UNAME" >/dev/null 2>&1; then
        log_warn "User $LOGIN_UNAME already exists"
        return 0
    fi
    
    # Create user with secure defaults
    if ! useradd -m -d "/home/$LOGIN_UNAME" -s /bin/bash -G sudo "$LOGIN_UNAME"; then
        log_error "Failed to create user $LOGIN_UNAME"
        exit 1
    fi
    
    # Create .ssh directory with proper permissions
    mkdir -p "/home/$LOGIN_UNAME/.ssh"
    chmod 700 "/home/$LOGIN_UNAME/.ssh"
    chown "$LOGIN_UNAME:$LOGIN_UNAME" "/home/$LOGIN_UNAME/.ssh"
    
    # Copy authorized keys if they exist and are valid
    if [[ -f ~/.ssh/authorized_keys ]] && [[ -s ~/.ssh/authorized_keys ]]; then
        log_info "Copying authorized keys for $LOGIN_UNAME"
        cp ~/.ssh/authorized_keys "/home/$LOGIN_UNAME/.ssh/"
        chmod 600 "/home/$LOGIN_UNAME/.ssh/authorized_keys"
        chown "$LOGIN_UNAME:$LOGIN_UNAME" "/home/$LOGIN_UNAME/.ssh/authorized_keys"
    else
        log_warn "No authorized keys found for root user"
        log_warn "User $LOGIN_UNAME will need to add SSH keys manually"
    fi
    
    # Copy repository with proper permissions
    if [[ -d "../$REPO_NAME" ]]; then
        log_info "Copying repository to user home directory"
        cp -r "../$REPO_NAME" "/home/$LOGIN_UNAME/"
        chmod -R 755 "/home/$LOGIN_UNAME/$REPO_NAME"
        chown -R "$LOGIN_UNAME:$LOGIN_UNAME" "/home/$LOGIN_UNAME/$REPO_NAME"
    fi
    
    log_info "User $LOGIN_UNAME created successfully"
}

# Enhanced fail2ban configuration
configure_fail2ban_enhanced() {
    log_info "Configuring enhanced fail2ban..."
    
    install_dependencies fail2ban
    
    # Create comprehensive fail2ban configuration
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600
# Override /etc/fail2ban/jail.d/00-firewalld.conf
banaction = iptables-multiport
# A host is banned if it has generated "maxretry" during "findtime"
findtime = 600
maxretry = $maxretry

[sshd]
enabled = true
port = $YourSSHPortNumber
filter = sshd
logpath = /var/log/auth.log
maxretry = $maxretry
bantime = 7200

[nginx-proxy]
enabled = true
port = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[nginx-http-auth]
enabled = true
port = 80,443
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
port = 80,443
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 2
bantime = 3600
EOF

    # Create nginx-proxy filter
    cat > /etc/fail2ban/filter.d/nginx-proxy.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*HTTP/1\.[01]" 4\d\d .*$
ignoreregex =
EOF

    systemctl restart fail2ban
    systemctl enable fail2ban
    log_info "Enhanced fail2ban configuration completed"
}

# Automated sudo configuration
configure_sudo_automated() {
    log_info "Configuring sudo access for $LOGIN_UNAME"
    
    # Create sudoers.d file for the user
    cat > "/etc/sudoers.d/$LOGIN_UNAME" << EOF
# Allow $LOGIN_UNAME to run all commands without password
# This is required for automated setup scripts
$LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL
EOF
    
    # Set proper permissions
    chmod 440 "/etc/sudoers.d/$LOGIN_UNAME"
    
    # Validate sudoers configuration
    if ! visudo -c; then
        log_error "Sudo configuration validation failed"
        rm -f "/etc/sudoers.d/$LOGIN_UNAME"
        exit 1
    fi
    
    log_info "Sudo configuration completed for $LOGIN_UNAME"
}

# Enhanced system hardening
apply_enhanced_hardening() {
    log_info "Applying enhanced system hardening..."
    
    # Disable shared memory
    append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'
    
    # Secure file permissions
    secure_config_files
    
    # Apply network security
    apply_network_security
    
    # Setup security monitoring
    setup_security_monitoring
    
    # Setup intrusion detection
    setup_intrusion_detection
    
    # Additional hardening measures
    log_info "Applying additional security measures..."
    
    # Disable unnecessary services
    systemctl disable --now avahi-daemon 2>/dev/null || true
    systemctl disable --now cups 2>/dev/null || true
    systemctl disable --now bluetooth 2>/dev/null || true
    
    # Set secure kernel parameters
    cat >> /etc/sysctl.conf << 'EOF'
# Security hardening
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_timestamps = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF
    
    # Apply sysctl changes
    sysctl -p
    
    log_info "Enhanced system hardening completed"
}

# Improved handoff section with validation
prepare_user_handoff() {
    log_info "Preparing user handoff..."
    
    # Get server IP
    local server_ip
    server_ip=$(curl -s v4.ident.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    # Create handoff script for user
    cat > "/home/$LOGIN_UNAME/complete_setup.sh" << EOF
#!/bin/bash
# Automated setup completion script
# Run this after logging in as $LOGIN_UNAME

set -euo pipefail

echo "=== Ethereum Node Setup - Phase 2 ==="
echo "This script will complete the setup process"
echo

# Verify we're running as the correct user
if [[ "\$(whoami)" != "$LOGIN_UNAME" ]]; then
    echo "Error: This script must be run as user $LOGIN_UNAME"
    exit 1
fi

# Verify sudo access
if ! sudo -n true 2>/dev/null; then
    echo "Error: Sudo access not configured properly"
    echo "Please run: sudo visudo"
    echo "Add this line: $LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL"
    exit 1
fi

echo "✓ User verification passed"
echo "✓ Sudo access confirmed"
echo

# Set user password if not already set
if ! sudo passwd -S "$LOGIN_UNAME" | grep -q " P "; then
    echo "Setting password for user $LOGIN_UNAME..."
    echo "Please enter a secure password:"
    sudo passwd "$LOGIN_UNAME"
fi

echo "✓ User password configured"
echo

# Navigate to repository directory
if [[ -d "$REPO_NAME" ]]; then
    cd "$REPO_NAME"
    echo "✓ Navigated to $REPO_NAME directory"
else
    echo "Error: Repository directory not found"
    exit 1
fi

# Run phase 2 setup
echo "Starting Phase 2 setup..."
if [[ -f "run_2.sh" ]]; then
    chmod +x run_2.sh
    ./run_2.sh
else
    echo "Error: run_2.sh not found"
    exit 1
fi
EOF
    
    chmod +x "/home/$LOGIN_UNAME/complete_setup.sh"
    chown "$LOGIN_UNAME:$LOGIN_UNAME" "/home/$LOGIN_UNAME/complete_setup.sh"
    
    # Create status check script
    cat > "/home/$LOGIN_UNAME/check_status.sh" << 'EOF'
#!/bin/bash
# System status check script

echo "=== System Status Check ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo

echo "=== Network Status ==="
ss -tulpn | grep -E ":(22|80|443|30303|12000|13000)"
echo

echo "=== SSH Status ==="
systemctl status ssh --no-pager -l
echo

echo "=== Firewall Status ==="
ufw status verbose
echo

echo "=== Fail2ban Status ==="
systemctl status fail2ban --no-pager -l
echo

echo "=== System Resources ==="
free -h
df -h /
echo

echo "=== Recent Security Events ==="
tail -10 /var/log/auth.log | grep -E "(Failed|Invalid|Disconnected)"
EOF
    
    chmod +x "/home/$LOGIN_UNAME/check_status.sh"
    chown "$LOGIN_UNAME:$LOGIN_UNAME" "/home/$LOGIN_UNAME/check_status.sh"
    
    log_info "Handoff preparation completed"
}

# Display completion summary
show_completion_summary() {
    local server_ip
    server_ip=$(curl -s v4.ident.me 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo
    echo "=========================================="
    echo "  PHASE 1 SETUP COMPLETED SUCCESSFULLY"
    echo "=========================================="
    echo
    echo "System Information:"
    echo "  Server IP: $server_ip"
    echo "  SSH Port: $YourSSHPortNumber"
    echo "  Username: $LOGIN_UNAME"
    echo
    echo "Next Steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. SSH back in as $LOGIN_UNAME:"
    echo "   ssh -p $YourSSHPortNumber $LOGIN_UNAME@$server_ip"
    echo "3. Run the completion script:"
    echo "   ./complete_setup.sh"
    echo
    echo "Useful Commands:"
    echo "  Check system status: ./check_status.sh"
    echo "  View logs: journalctl -fu <service-name>"
    echo "  Check firewall: sudo ufw status verbose"
    echo
    echo "Security Features Enabled:"
    echo "  ✓ Enhanced SSH configuration"
    echo "  ✓ Fail2ban intrusion prevention"
    echo "  ✓ UFW firewall with Ethereum rules"
    echo "  ✓ System hardening measures"
    echo "  ✓ Security monitoring"
    echo
    echo "=========================================="
}

# Main execution
main() {
    log_info "Starting enhanced system setup - Phase 1..."
    
    # Validate configuration
    validate_configuration
    
    # Check system compatibility
    if ! check_system_compatibility; then
        log_error "System compatibility check failed"
        exit 1
    fi
    
    # Update system packages
    log_info "Updating system packages..."
    apt update -y
    apt upgrade -y
    apt full-upgrade -y
    apt autoremove -y
    
    # Configure SSH with enhanced security
    configure_ssh_secure
    
    # Configure enhanced fail2ban
    configure_fail2ban_enhanced
    
    # Create secure user
    create_secure_user
    
    # Configure sudo access
    configure_sudo_automated
    
    # Run firewall configuration
    chmod +x ./install/security/firewall.sh
    ./install/security/firewall.sh
    
    # Apply enhanced hardening
    apply_enhanced_hardening
    
    # Prepare user handoff
    prepare_user_handoff
    
    # Display completion summary
    show_completion_summary
}

# Run main function
main "$@"