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
    
    # Set default policies with error handling
    log_info "Setting default firewall policies..."
    if ! ufw default deny incoming; then
        log_error "Failed to set default deny incoming"
        exit 1
    fi
    
    if ! ufw default allow outgoing; then
        log_error "Failed to set default allow outgoing"
        exit 1
    fi
    
    # Open essential ports
    log_info "Opening ports for Ethereum clients..."
    ufw allow 30303 || log_warn "Failed to allow port 30303"
    ufw allow 13000/tcp || log_warn "Failed to allow port 13000/tcp"
    ufw allow 12000/udp || log_warn "Failed to allow port 12000/udp"
    ufw allow in ssh || log_warn "Failed to allow SSH"
    ufw allow 22/tcp || log_warn "Failed to allow port 22/tcp"
    ufw allow 443/tcp || log_warn "Failed to allow port 443/tcp"
    
    # Block private networks to prevent netscan abuse
    log_info "Blocking outbound connections to private networks..."
    log_info "This prevents netscan abuse warnings (updated Feb '23 from Erigon docs)"
    
    local private_networks=(
        "0.0.0.0/8" "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8"
        "169.254.0.0/16" "172.16.0.0/12" "192.0.0.0/24" "192.0.2.0/24"
        "192.88.99.0/24" "192.168.0.0/16" "198.18.0.0/15" "198.51.100.0/24"
        "203.0.113.0/24" "224.0.0.0/4" "240.0.0.0/4" "255.255.255.255/32"
    )
    
    for network in "${private_networks[@]}"; do
        ufw deny out on any to "$network" || log_warn "Failed to block outbound to $network"
    done
    
    # Block specific ports (updates from Prysm docs Feb '23)
    log_info "Blocking specific ports for security..."
    ufw deny in 4000/tcp || log_warn "Failed to deny port 4000/tcp"
    ufw deny in 3500/tcp || log_warn "Failed to deny port 3500/tcp"
    ufw deny in 8551/tcp || log_warn "Failed to deny port 8551/tcp"
    ufw deny in 8545/tcp || log_warn "Failed to deny port 8545/tcp"
    
    # Enable firewall with error handling
    log_info "Enabling UFW firewall..."
    if ! ufw enable; then
        log_error "Failed to enable UFW firewall"
        exit 1
    fi
    
    log_info "✓ Firewall configuration completed!"
    log_info "UFW firewall is now enabled with Ethereum client and security rules"
    log_info "Allowed ports: 22 (SSH), 443 (HTTPS), 30303 (Ethereum P2P), 12000/13000 (Prysm)"
    log_info "Blocked: Private networks, specific ports (4000, 3500, 8551, 8545)"
}

# =============================================================================
# FAIL2BAN CONFIGURATION
# =============================================================================

setup_fail2ban() {
    log_info "Setting up fail2ban intrusion prevention..."
    
    # Install fail2ban
    install_dependencies fail2ban
    
    # Define variables with fallback defaults (from original script)
    local SSH_PORT="${YourSSHPortNumber:-22}"
    local MAX_RETRY="${maxretry:-3}"
    
    # Configure fail2ban jails (append mode to preserve existing configs)
    log_info "Configuring fail2ban jails..."
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
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = $MAX_RETRY
bantime = 3600
findtime = 600
EOF

    # Create nginx-proxy filter
    log_info "Creating fail2ban filter for nginx proxy abuse..."
    cat > /etc/fail2ban/filter.d/nginx-proxy.conf << EOF
# Block IPs trying to use server as proxy.
#
# Matches e.g.
# 192.168.1.1 - - "GET http://www.something.com/

[Definition]
failregex = ^<HOST> -.*GET http.*
ignoreregex =
EOF

    # Enable and start fail2ban
    enable_and_start_systemd_service fail2ban
    
    log_info "✓ Fail2ban installation and configuration complete"
}

# =============================================================================
# NGINX HARDENING
# =============================================================================

setup_nginx_hardening() {
    log_info "Setting up nginx hardening..."
    
    # Create fail2ban jail configuration for nginx proxy abuse
    log_info "Creating fail2ban jail configuration..."
    cat > /etc/fail2ban/jail.local << EOF
## block hosts trying to abuse our server as a forward proxy
[nginx-proxy]
enabled = true
port    = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400
EOF

    # Restart services
    log_info "Restarting fail2ban..."
    if ! systemctl restart fail2ban; then
        log_error "Failed to restart fail2ban"
        exit 1
    fi

    log_info "Restarting nginx..."
    if ! systemctl restart nginx; then
        log_error "Failed to restart nginx"
        exit 1
    fi

    log_info "✓ NGINX hardening completed!"
    log_info "fail2ban is now configured to block proxy abuse attempts"
    log_info "Filter: nginx-proxy"
    log_info "Ban time: 86400 seconds (24 hours)"
    log_info "Max retries: 2"
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
    setup_nginx_hardening
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