#!/bin/bash

# Caddy Security Hardening Script
# Applies security best practices to Caddy configuration

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"
source "$PROJECT_ROOT/install/web/caddy_helpers.sh"

# Check if running as root
require_root

log_info "Starting Caddy security hardening..."
backup_file=""

# Backup original Caddyfile
log_info "Creating backup of original Caddyfile..."
if [[ -f /etc/caddy/Caddyfile ]]; then
    backup_file="/etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/caddy/Caddyfile "$backup_file"
    log_info "Backup created: $backup_file"
else
    log_error "Caddyfile not found at /etc/caddy/Caddyfile"
    exit 1
fi

temp_config="/tmp/caddy_hardened_$$.Caddyfile"
cleanup_temp() {
    rm -f "$temp_config"
}
trap cleanup_temp EXIT

# Generate hardened Caddy config from the shared renderer used by installer
log_info "Rendering hardened Caddy configuration from shared policy..."
if [[ "${CI_E2E:-}" != "true" ]] && [[ -f "/etc/letsencrypt/live/$SERVER_NAME/fullchain.pem" ]] && [[ -f "/etc/letsencrypt/live/$SERVER_NAME/privkey.pem" ]]; then
    create_caddy_config_manual_ssl "$SERVER_NAME" "$temp_config" "/etc/letsencrypt/live/$SERVER_NAME/fullchain.pem" "/etc/letsencrypt/live/$SERVER_NAME/privkey.pem"
else
    create_caddy_config_auto_https "$SERVER_NAME" "$temp_config"
fi

# Install hardened configuration
log_info "Installing hardened Caddyfile..."
if ! sudo mv "$temp_config" /etc/caddy/Caddyfile; then
    log_error "Failed to install hardened Caddyfile"
    exit 1
fi

sudo chown caddy:caddy /etc/caddy/Caddyfile
sudo chmod 644 /etc/caddy/Caddyfile

# Validate configuration
if ! validate_caddy_config "/etc/caddy/Caddyfile"; then
    log_error "Hardened Caddyfile validation failed"
    log_info "Restoring backup..."
    [[ -n "$backup_file" ]] && sudo cp "$backup_file" /etc/caddy/Caddyfile
    exit 1
fi

# Restart Caddy with hardened configuration
log_info "Restarting Caddy with hardened configuration..."
if ! restart_caddy_service; then
    log_error "Failed to restart Caddy with hardened configuration"
    log_info "Restoring backup..."
    [[ -n "$backup_file" ]] && sudo cp "$backup_file" /etc/caddy/Caddyfile
    restart_caddy_service || true
    exit 1
fi

# Verify Caddy is running
if sudo systemctl is-active --quiet caddy; then
    log_info "✓ Caddy is running with hardened configuration"
else
    log_error "Caddy failed to start with hardened configuration"
    exit 1
fi

# Additional security measures
log_info "Applying additional security measures..."

# Create Caddy security monitoring script
sudo tee /usr/local/bin/caddy_security_monitor.sh > /dev/null << 'EOF'
#!/bin/bash
# Caddy security monitoring script

LOG_FILE="/var/log/caddy_security.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Caddy security monitoring check" >> "$LOG_FILE"

if [[ -f /var/log/caddy/access.log ]]; then
    if grep -q "wp-admin\|admin\|config\|\.env\|m3u8" /var/log/caddy/access.log; then
        echo "[$DATE] WARNING: Suspicious requests detected" >> "$LOG_FILE"
    fi

    recent_requests=$(grep "$(date '+%d/%b/%Y:%H')" /var/log/caddy/access.log | wc -l)
    if [[ $recent_requests -gt 1000 ]]; then
        echo "[$DATE] WARNING: High request rate detected: $recent_requests requests in the last hour" >> "$LOG_FILE"
    fi
fi

if ! pgrep -f caddy >/dev/null; then
    echo "[$DATE] ERROR: Caddy process not running" >> "$LOG_FILE"
fi

echo "[$DATE] Caddy security monitoring check complete" >> "$LOG_FILE"
EOF

sudo chmod +x /usr/local/bin/caddy_security_monitor.sh

# Add security monitoring to crontab
(crontab -l 2>/dev/null | grep -v caddy_security_monitor.sh; echo "*/5 * * * * /usr/local/bin/caddy_security_monitor.sh") | crontab - 2>/dev/null || true

log_info "✓ Caddy security hardening completed!"
log_info "Hardened features applied:"
log_info "- Shared edge routing policy render (same source as Nginx policy)"
log_info "- RPC/WS method restrictions and spam-path filtering"
log_info "- Security headers and timeouts"
log_info "- Security monitoring"
log_info "- Enhanced logging"

log_info "Configuration file: /etc/caddy/Caddyfile"
log_info "Backup file: /etc/caddy/Caddyfile.backup.*"
log_info "Security logs: /var/log/caddy_security.log"
