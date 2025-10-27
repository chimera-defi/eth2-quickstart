#!/bin/bash

# Consolidated Security Setup Script
# This script consolidates all security functions into a single, comprehensive setup
# Replaces individual security scripts with a unified approach

set -Eeuo pipefail

# Source required files
source ../../exports.sh
source ../../lib/common_functions.sh

# Check if running as root
require_root

log_info "Starting consolidated security setup..."

# =============================================================================
# FIREWALL CONFIGURATION
# =============================================================================

setup_firewall() {
    log_info "Setting up UFW firewall with comprehensive rules..."
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Open essential ports
    ufw allow 22/tcp comment "SSH"
    ufw allow 443/tcp comment "HTTPS"
    ufw allow 30303 comment "Ethereum P2P"
    ufw allow 12000/udp comment "Prysm P2P"
    ufw allow 13000/tcp comment "Prysm API"
    
    # Block private networks to prevent netscan abuse
    local private_networks=(
        "0.0.0.0/8" "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8"
        "169.254.0.0/16" "172.16.0.0/12" "192.0.0.0/24" "192.0.2.0/24"
        "192.88.99.0/24" "192.168.0.0/16" "198.18.0.0/15" "198.51.100.0/24"
        "203.0.113.0/24" "224.0.0.0/4" "240.0.0.0/4" "255.255.255.255/32"
    )
    
    for network in "${private_networks[@]}"; do
        ufw deny out on any to "$network" comment "Block private network $network"
    done
    
    # Block dangerous ports
    ufw deny in 4000/tcp comment "Block port 4000"
    ufw deny in 3500/tcp comment "Block port 3500"
    ufw deny in 8551/tcp comment "Block port 8551"
    ufw deny in 8545/tcp comment "Block port 8545"
    
    # Enable firewall
    ufw --force enable
    
    log_info "✓ Firewall configured with comprehensive rules"
}

# =============================================================================
# FAIL2BAN CONFIGURATION
# =============================================================================

setup_fail2ban() {
    log_info "Setting up fail2ban intrusion prevention..."
    
    # Install fail2ban
    install_dependencies fail2ban
    
    # Configure fail2ban jails
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $YourSSHPortNumber
filter = sshd
logpath = /var/log/auth.log
maxretry = $maxretry
bantime = 3600
findtime = 600

[nginx-proxy]
enabled = true
port = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400
findtime = 600
EOF

    # Create nginx-proxy filter
    cat > /etc/fail2ban/filter.d/nginx-proxy.conf << EOF
[Definition]
failregex = ^<HOST> -.*GET http.*
ignoreregex =
EOF

    # Enable and start fail2ban
    enable_and_start_systemd_service fail2ban
    
    log_info "✓ Fail2ban configured with SSH and nginx protection"
}

# =============================================================================
# AIDE INTRUSION DETECTION
# =============================================================================

setup_aide() {
    log_info "Setting up AIDE file integrity monitoring..."
    
    # Install AIDE
    install_dependencies aide
    
    # Initialize AIDE database if it doesn't exist
    if [[ ! -f "/var/lib/aide/aide.db" ]]; then
        aideinit
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    fi
    
    # Create AIDE check script
    cat > /usr/local/bin/aide_check.sh << 'EOF'
#!/bin/bash
# AIDE intrusion detection check

LOG_FILE="/var/log/aide_check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Running AIDE check..." >> "$LOG_FILE"

if aide --check >> "$LOG_FILE" 2>&1; then
    echo "[$DATE] AIDE check passed - no changes detected" >> "$LOG_FILE"
else
    echo "[$DATE] WARNING: AIDE detected changes in system files" >> "$LOG_FILE"
fi

echo "[$DATE] AIDE check complete" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/aide_check.sh
    
    # Schedule daily AIDE checks
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/aide_check.sh") | crontab - 2>/dev/null || true
    
    log_info "✓ AIDE file integrity monitoring configured"
}

# =============================================================================
# SECURITY MONITORING
# =============================================================================

setup_security_monitoring() {
    log_info "Setting up security monitoring system..."
    
    # Create security monitoring script
    cat > /usr/local/bin/security_monitor.sh << 'EOF'
#!/bin/bash
# Security monitoring script

LOG_FILE="/var/log/security_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Security monitoring check" >> "$LOG_FILE"

# Check for failed login attempts
if command -v lastb >/dev/null 2>&1; then
    failed_logins=$(lastb | wc -l)
    if [[ $failed_logins -gt 0 ]]; then
        echo "[$DATE] WARNING: $failed_logins failed login attempts detected" >> "$LOG_FILE"
    fi
fi

# Check for suspicious processes
if pgrep -f "nc -l" >/dev/null 2>&1; then
    echo "[$DATE] WARNING: Suspicious netcat listener detected" >> "$LOG_FILE"
fi

# Check disk usage
disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
if [[ $disk_usage -gt 90 ]]; then
    echo "[$DATE] WARNING: Disk usage at ${disk_usage}%" >> "$LOG_FILE"
fi

# Check memory usage
memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [[ $memory_usage -gt 90 ]]; then
    echo "[$DATE] WARNING: Memory usage at ${memory_usage}%" >> "$LOG_FILE"
fi

echo "[$DATE] Security monitoring check complete" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/security_monitor.sh
    
    # Schedule security monitoring every 15 minutes
    (crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/security_monitor.sh") | crontab - 2>/dev/null || true
    
    # Configure log rotation
    cat > /etc/logrotate.d/security_monitor << EOF
/var/log/security_monitor.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    log_info "✓ Security monitoring system configured"
}

# =============================================================================
# NETWORK SECURITY HARDENING
# =============================================================================

setup_network_security() {
    log_info "Applying network security hardening..."
    
    # Disable unnecessary services
    systemctl disable bluetooth 2>/dev/null || true
    systemctl disable cups 2>/dev/null || true
    systemctl disable avahi-daemon 2>/dev/null || true
    
    # Configure kernel security parameters
    cat >> /etc/sysctl.conf << EOF

# Network security settings
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF

    # Apply sysctl settings
    sysctl -p >/dev/null 2>&1 || true
    
    log_info "✓ Network security hardening applied"
}

# =============================================================================
# FILE SECURITY HARDENING
# =============================================================================

setup_file_security() {
    log_info "Applying file security hardening..."
    
    # Set secure permissions on configuration files
    find /etc -name "*.conf" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.cfg" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.yaml" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.yml" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.json" -type f -exec chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.toml" -type f -exec chmod 644 {} \; 2>/dev/null || true
    
    # Secure sensitive files
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        chmod 600 /etc/ssh/sshd_config
    fi
    
    if [[ -f "/etc/sudoers" ]]; then
        chmod 440 /etc/sudoers
    fi
    
    # Disable shared memory for security
    if ! grep -q "tmpfs.*/run/shm" /etc/fstab; then
        echo "tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0 0" >> /etc/fstab
    fi
    
    log_info "✓ File security hardening applied"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log_info "=== CONSOLIDATED SECURITY SETUP ==="
    
    # Run all security setup functions
    setup_firewall
    setup_fail2ban
    setup_aide
    setup_security_monitoring
    setup_network_security
    setup_file_security
    
    log_info "=== SECURITY SETUP COMPLETE ==="
    log_info "✓ Firewall configured with comprehensive rules"
    log_info "✓ Fail2ban intrusion prevention active"
    log_info "✓ AIDE file integrity monitoring scheduled"
    log_info "✓ Security monitoring system active"
    log_info "✓ Network security hardening applied"
    log_info "✓ File security hardening applied"
    
    echo
    log_info "Security features summary:"
    log_info "- UFW firewall: Blocks private networks, dangerous ports"
    log_info "- Fail2ban: Protects SSH and nginx from brute force"
    log_info "- AIDE: Daily file integrity checks at 2 AM"
    log_info "- Security monitoring: Every 15 minutes"
    log_info "- Network hardening: Kernel security parameters"
    log_info "- File hardening: Secure permissions and shared memory disabled"
    
    echo
    log_info "To verify security setup, run: ./test_security_fixes.sh"
}

# Execute main function
main "$@"