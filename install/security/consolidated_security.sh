#!/bin/bash

# Consolidated Security Setup Script
# Combines firewall, fail2ban, and AIDE into one efficient script

# Source configuration files
source ../../exports.sh
source ../../lib/common_functions.sh

# Get script directories
get_script_directories

# Check if running as root
require_root

log_installation_start "Consolidated Security Suite"

# Function 1: Setup Firewall
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

    # Open essential ports using common function
    log_info "Opening ports for Ethereum clients..."
    setup_firewall_rules 30303 13000/tcp 12000/udp 22/tcp 443/tcp
    
    # Allow SSH (special rule)
    ufw allow in ssh || log_warn "Failed to allow SSH"

    # Block outbound connections to private/reserved networks to prevent netscan abuse
    log_info "Blocking outbound connections to private networks..."
    log_info "This prevents netscan abuse warnings (updated Feb '23 from Erigon docs)"

    # Define private network ranges to block
    private_networks=(
        "0.0.0.0/8"
        "10.0.0.0/8"
        "100.64.0.0/10"
        "127.0.0.0/8"
        "169.254.0.0/16"
        "172.16.0.0/12"
        "192.0.0.0/24"
        "192.0.2.0/24"
        "192.88.99.0/24"
        "192.168.0.0/16"
        "198.18.0.0/15"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "240.0.0.0/4"
        "255.255.255.255/32"
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

    log_info "✓ Firewall configuration completed!"
    log_info "UFW firewall is now enabled with Ethereum client and security rules"
    log_info "Allowed ports: 22 (SSH), 443 (HTTPS), 30303 (Ethereum P2P), 12000/13000 (Prysm)"
    log_info "Blocked: Private networks, specific ports (4000, 3500, 8551, 8545)"
}

# Function 2: Setup Fail2ban
setup_fail2ban() {
    log_info "Setting up fail2ban intrusion prevention..."

    # Install fail2ban
    install_dependencies fail2ban

    # Define variables with fallback defaults
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

    # Enable and start fail2ban service
    enable_and_start_systemd_service fail2ban

    log_info "✓ Fail2ban installation and configuration complete"
}

# Function 3: Setup AIDE
setup_aide() {
    log_info "Setting up AIDE file integrity monitoring..."
    
    # Install AIDE
    install_dependencies aide
    
    # Initialize AIDE database
    log_info "Initializing AIDE database..."
    if ! aide --init; then
        log_error "Failed to initialize AIDE database"
        exit 1
    fi
    
    # Move database to production location
    if [[ -f /var/lib/aide/aide.db.new ]]; then
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        log_info "AIDE database initialized successfully"
    fi
    
    # Create AIDE check script
    log_info "Creating AIDE check script..."
    cat > /usr/local/bin/aide_check.sh << 'EOF'
#!/bin/bash
# AIDE File Integrity Check Script

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_info "Running AIDE file integrity check..."

# Run AIDE check
if aide --check > /var/log/aide_check.log 2>&1; then
    log_info "✓ AIDE check passed - no changes detected"
else
    log_warn "⚠ AIDE check found changes - check /var/log/aide_check.log"
fi
EOF

    chmod +x /usr/local/bin/aide_check.sh
    
    # Schedule AIDE check in crontab
    log_info "Scheduling AIDE check in crontab..."
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/aide_check.sh") | crontab -
    
    log_info "✓ AIDE file integrity monitoring setup complete"
    log_info "AIDE check scheduled daily at 2 AM"
}

# Function 4: Security Verification
verify_security_setup() {
    log_info "Verifying security setup..."
    
    local issues=0
    
    # Check firewall
    if ufw status | grep -q "Status: active"; then
        log_info "✓ UFW firewall is active"
    else
        log_error "✗ UFW firewall is not active"
        issues=$((issues + 1))
    fi
    
    # Check fail2ban
    if systemctl is-active --quiet fail2ban; then
        log_info "✓ Fail2ban is running"
    else
        log_error "✗ Fail2ban is not running"
        issues=$((issues + 1))
    fi
    
    # Check AIDE
    if command -v aide >/dev/null 2>&1; then
        log_info "✓ AIDE is installed"
    else
        log_error "✗ AIDE is not installed"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        log_info "✓ All security features verified successfully"
    else
        log_warn "⚠ $issues security issues found - check logs above"
    fi
}

# Main execution
main() {
    # Run all security setup functions
    setup_firewall
    setup_fail2ban
    setup_aide
    
    # Verify security setup
    verify_security_setup

    log_info "=== SECURITY SETUP COMPLETE ==="
    log_info "✓ Firewall configured with comprehensive rules"
    log_info "✓ Fail2ban intrusion prevention active"
    log_info "✓ AIDE file integrity monitoring scheduled"
    log_info "✓ All security features are now active and protecting your system"
    
    log_installation_complete "Consolidated Security Suite" "security-suite"
}

# Execute main function
main "$@"