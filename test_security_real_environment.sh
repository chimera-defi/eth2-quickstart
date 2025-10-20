#!/bin/bash

# Real Environment Security Testing Script
# This script tests security implementations in a real environment
# Run this after running run_1.sh and run_2.sh to validate security

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${BLUE}[SECTION]${NC} $1"
}

# Check if running as non-root user
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

log_info "Starting real environment security testing..."
echo

# Test 1: Test security monitoring script execution
log_section "Testing Security Monitoring Script Execution"

if [[ -f "/usr/local/bin/security_monitor.sh" && -x "/usr/local/bin/security_monitor.sh" ]]; then
    log_info "Running security monitoring script..."
    if /usr/local/bin/security_monitor.sh; then
        log_info "✓ Security monitoring script executed successfully"
        
        # Check if log file was created
        if [[ -f "/var/log/security_monitor.log" ]]; then
            log_info "✓ Security monitoring log file created"
            log_info "Log file size: $(stat -c %s /var/log/security_monitor.log) bytes"
        else
            log_error "✗ Security monitoring log file not created"
        fi
    else
        log_error "✗ Security monitoring script execution failed"
    fi
else
    log_error "✗ Security monitoring script not found or not executable"
fi

echo

# Test 2: Test AIDE intrusion detection
log_section "Testing AIDE Intrusion Detection"

if command -v aide >/dev/null 2>&1; then
    log_info "AIDE is installed"
    
    if [[ -f "/var/lib/aide/aide.db" ]]; then
        log_info "✓ AIDE database exists"
        
        if [[ -f "/usr/local/bin/aide_check.sh" && -x "/usr/local/bin/aide_check.sh" ]]; then
            log_info "Running AIDE check script..."
            if /usr/local/bin/aide_check.sh; then
                log_info "✓ AIDE check script executed successfully"
                
                # Check if log file was created
                if [[ -f "/var/log/aide_check.log" ]]; then
                    log_info "✓ AIDE check log file created"
                    log_info "Log file size: $(stat -c %s /var/log/aide_check.log) bytes"
                else
                    log_error "✗ AIDE check log file not created"
                fi
            else
                log_error "✗ AIDE check script execution failed"
            fi
        else
            log_error "✗ AIDE check script not found or not executable"
        fi
    else
        log_error "✗ AIDE database not found"
    fi
else
    log_error "✗ AIDE not installed"
fi

echo

# Test 3: Test firewall rules
log_section "Testing Firewall Rules"

log_info "Checking UFW status..."
ufw status

if ufw status | grep -q "Status: active"; then
    log_info "✓ UFW is active"
    
    # Check if critical ports are blocked
    if ufw status | grep -q "8545/tcp.*DENY"; then
        log_info "✓ Port 8545 (RPC) is blocked"
    else
        log_error "✗ Port 8545 (RPC) is not blocked"
    fi
    
    if ufw status | grep -q "8551/tcp.*DENY"; then
        log_info "✓ Port 8551 (Engine API) is blocked"
    else
        log_error "✗ Port 8551 (Engine API) is not blocked"
    fi
else
    log_error "✗ UFW is not active"
fi

echo

# Test 4: Test fail2ban
log_section "Testing Fail2ban"

log_info "Checking fail2ban status..."
if systemctl is-active --quiet fail2ban; then
    log_info "✓ Fail2ban is running"
    
    log_info "Fail2ban status:"
    fail2ban-client status
else
    log_error "✗ Fail2ban is not running"
fi

echo

# Test 5: Test network binding
log_section "Testing Network Binding"

log_info "Checking network bindings..."
log_info "Services binding to 0.0.0.0 (security risk):"
if ss -tuln | grep "0.0.0.0"; then
    log_error "✗ Services found binding to 0.0.0.0 (security risk)"
else
    log_info "✓ No services binding to 0.0.0.0"
fi

log_info "Services binding to localhost:"
if ss -tuln | grep "127.0.0.1"; then
    log_info "✓ Services properly binding to localhost"
else
    log_warn "⚠ No services found binding to localhost"
fi

echo

# Test 6: Test file permissions
log_section "Testing File Permissions"

log_info "Checking file permissions..."

# Check secrets directory
if [[ -d "$HOME/secrets" ]]; then
    local perms
    perms=$(stat -c %a "$HOME/secrets")
    if [[ "$perms" == "700" ]]; then
        log_info "✓ Secrets directory has correct permissions (700)"
    else
        log_error "✗ Secrets directory permissions incorrect (expected 700, got $perms)"
    fi
    
    # Check JWT secret
    if [[ -f "$HOME/secrets/jwt.hex" ]]; then
        local jwt_perms
        jwt_perms=$(stat -c %a "$HOME/secrets/jwt.hex")
        if [[ "$jwt_perms" == "600" ]]; then
            log_info "✓ JWT secret has correct permissions (600)"
        else
            log_error "✗ JWT secret permissions incorrect (expected 600, got $jwt_perms)"
        fi
    else
        log_warn "⚠ JWT secret not found (may not be created yet)"
    fi
else
    log_warn "⚠ Secrets directory not found (may not be created yet)"
fi

echo

# Test 7: Test crontab scheduling
log_section "Testing Crontab Scheduling"

log_info "Checking crontab scheduling..."
if crontab -l 2>/dev/null | grep -q "security_monitor"; then
    log_info "✓ Security monitoring is scheduled"
    crontab -l 2>/dev/null | grep "security_monitor"
else
    log_error "✗ Security monitoring not scheduled in crontab"
fi

if crontab -l 2>/dev/null | grep -q "aide_check"; then
    log_info "✓ AIDE intrusion detection is scheduled"
    crontab -l 2>/dev/null | grep "aide_check"
else
    log_error "✗ AIDE intrusion detection not scheduled in crontab"
fi

echo

# Test 8: Test log rotation
log_section "Testing Log Rotation"

log_info "Checking log rotation configuration..."
if [[ -f "/etc/logrotate.d/security_monitor" ]]; then
    log_info "✓ Security monitoring log rotation configured"
    cat /etc/logrotate.d/security_monitor
else
    log_error "✗ Security monitoring log rotation not configured"
fi

echo

# Test 9: Test systemd services
log_section "Testing Systemd Services"

log_info "Checking critical systemd services..."
local services=("ufw" "fail2ban")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        log_info "✓ $service is running"
    else
        log_error "✗ $service is not running"
    fi
done

echo

# Test 10: Test security logs
log_section "Testing Security Logs"

log_info "Checking security logs..."

if [[ -f "/var/log/security_monitor.log" ]]; then
    log_info "✓ Security monitoring log exists"
    log_info "Log file size: $(stat -c %s /var/log/security_monitor.log) bytes"
    log_info "Last 5 lines of security monitoring log:"
    tail -5 /var/log/security_monitor.log
else
    log_error "✗ Security monitoring log not found"
fi

echo

if [[ -f "/var/log/aide_check.log" ]]; then
    log_info "✓ AIDE intrusion detection log exists"
    log_info "Log file size: $(stat -c %s /var/log/aide_check.log) bytes"
    log_info "Last 5 lines of AIDE log:"
    tail -5 /var/log/aide_check.log
else
    log_warn "⚠ AIDE intrusion detection log not found (may not have run yet)"
fi

echo

# Test 11: Test SSH configuration
log_section "Testing SSH Configuration"

log_info "Checking SSH configuration..."
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
    log_info "✓ Root login is disabled"
else
    log_warn "⚠ Root login not disabled"
fi

if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
    log_info "✓ Password authentication is disabled"
else
    log_warn "⚠ Password authentication not disabled"
fi

echo

# Test 12: Test system information
log_section "System Information"

log_info "System information:"
log_info "OS: $(lsb_release -d | cut -f2)"
log_info "Kernel: $(uname -r)"
log_info "Uptime: $(uptime -p)"
log_info "Load average: $(uptime | awk -F'load average:' '{print $2}')"

echo

# Test 13: Test disk and memory usage
log_section "Resource Usage"

log_info "Disk usage:"
df -h /

echo

log_info "Memory usage:"
free -h

echo

# Test 14: Test for suspicious processes
log_section "Suspicious Processes Check"

log_info "Checking for suspicious processes..."
local suspicious_processes=("nc" "netcat" "nmap" "masscan" "hydra" "john")
local found_processes=()

for process in "${suspicious_processes[@]}"; do
    if pgrep -f "$process" >/dev/null 2>&1; then
        found_processes+=("$process")
    fi
done

if [[ ${#found_processes[@]} -eq 0 ]]; then
    log_info "✓ No suspicious processes detected"
else
    log_warn "⚠ Suspicious processes found: ${found_processes[*]}"
fi

echo

# Test 15: Test network connections
log_section "Network Connections"

log_info "Active network connections:"
ss -tuln | head -20

echo

# Summary
log_section "Testing Summary"

log_info "Security testing completed. Review the results above to ensure all security measures are working correctly."

echo

# Recommendations
log_section "Recommendations"

echo "1. Monitor security logs regularly:"
echo "   - Security monitoring: /var/log/security_monitor.log"
echo "   - AIDE intrusion detection: /var/log/aide_check.log"
echo
echo "2. Check system status regularly:"
echo "   - Firewall: ufw status"
echo "   - Fail2ban: fail2ban-client status"
echo "   - Services: systemctl status ufw fail2ban"
echo
echo "3. Run security verification periodically:"
echo "   - ./server_security_validation.sh"
echo "   - ./docs/verify_security.sh"
echo
echo "4. Keep system updated:"
echo "   - sudo apt update && sudo apt upgrade"
echo
echo "5. Review security alerts and logs regularly"

echo

log_info "Security testing completed successfully!"