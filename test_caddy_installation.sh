#!/bin/bash

# Caddy Installation Test Script
# Tests the Caddy installation and configuration

source exports.sh
source lib/common_functions.sh

log_info "Starting Caddy installation test..."

# Test 1: Check if Caddy is installed
log_info "Test 1: Checking if Caddy is installed..."
if command_exists caddy; then
    log_info "✓ Caddy is installed"
    caddy version
else
    log_error "✗ Caddy is not installed"
    exit 1
fi

# Test 2: Check if Caddy service is running
log_info "Test 2: Checking if Caddy service is running..."
if sudo systemctl is-active --quiet caddy; then
    log_info "✓ Caddy service is running"
else
    log_error "✗ Caddy service is not running"
    exit 1
fi

# Test 3: Check Caddy configuration
log_info "Test 3: Checking Caddy configuration..."
if [[ -f /etc/caddy/Caddyfile ]]; then
    log_info "✓ Caddyfile exists"
    if sudo caddy validate --config /etc/caddy/Caddyfile; then
        log_info "✓ Caddyfile is valid"
    else
        log_error "✗ Caddyfile is invalid"
        exit 1
    fi
else
    log_error "✗ Caddyfile not found"
    exit 1
fi

# Test 4: Check Caddy directories
log_info "Test 4: Checking Caddy directories..."
if [[ -d /etc/caddy ]]; then
    log_info "✓ Configuration directory exists: /etc/caddy"
else
    log_error "✗ Configuration directory missing: /etc/caddy"
fi

if [[ -d /var/log/caddy ]]; then
    log_info "✓ Log directory exists: /var/log/caddy"
else
    log_error "✗ Log directory missing: /var/log/caddy"
fi

# Test 5: Check Caddy logs
log_info "Test 5: Checking Caddy logs..."
if [[ -f /var/log/caddy/access.log ]]; then
    log_info "✓ Access log exists: /var/log/caddy/access.log"
    log_info "Recent log entries:"
    tail -5 /var/log/caddy/access.log
else
    log_warn "⚠ Access log not found: /var/log/caddy/access.log"
fi

# Test 6: Check firewall rules
log_info "Test 6: Checking firewall rules..."
if command_exists ufw; then
    if sudo ufw status | grep -q "80/tcp"; then
        log_info "✓ Port 80 is open"
    else
        log_warn "⚠ Port 80 is not open"
    fi
    
    if sudo ufw status | grep -q "443/tcp"; then
        log_info "✓ Port 443 is open"
    else
        log_warn "⚠ Port 443 is not open"
    fi
else
    log_warn "⚠ UFW not found, cannot check firewall rules"
fi

# Test 7: Check security hardening
log_info "Test 7: Checking security hardening..."
if [[ -f /usr/local/bin/caddy_security_monitor.sh ]]; then
    log_info "✓ Security monitoring script exists"
else
    log_warn "⚠ Security monitoring script not found"
fi

# Test 8: Test configuration syntax
log_info "Test 8: Testing configuration syntax..."
if sudo caddy fmt --diff /etc/caddy/Caddyfile > /dev/null 2>&1; then
    log_info "✓ Caddyfile syntax is correct"
else
    log_warn "⚠ Caddyfile syntax issues detected"
fi

# Test 9: Check systemd service status
log_info "Test 9: Checking systemd service status..."
sudo systemctl status caddy --no-pager -l

# Test 10: Check for common issues
log_info "Test 10: Checking for common issues..."

# Check if Caddy is listening on expected ports
if sudo netstat -tlnp | grep -q ":80.*caddy"; then
    log_info "✓ Caddy is listening on port 80"
else
    log_warn "⚠ Caddy is not listening on port 80"
fi

if sudo netstat -tlnp | grep -q ":443.*caddy"; then
    log_info "✓ Caddy is listening on port 443"
else
    log_warn "⚠ Caddy is not listening on port 443"
fi

# Check for error logs
if [[ -f /var/log/caddy/error.log ]]; then
    error_count=$(wc -l < /var/log/caddy/error.log)
    if [[ $error_count -gt 0 ]]; then
        log_warn "⚠ Found $error_count error log entries"
        log_info "Recent errors:"
        tail -3 /var/log/caddy/error.log
    else
        log_info "✓ No errors in error log"
    fi
fi

log_info ""
log_info "=== Caddy Installation Test Complete ==="
log_info "All tests completed. Check the results above for any issues."
log_info ""
log_info "Useful commands:"
log_info "- Check status: sudo systemctl status caddy"
log_info "- View logs: sudo journalctl -u caddy -f"
log_info "- Test config: sudo caddy validate --config /etc/caddy/Caddyfile"
log_info "- Reload config: sudo systemctl reload caddy"
log_info "- Restart service: sudo systemctl restart caddy"