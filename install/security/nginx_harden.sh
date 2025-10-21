#!/bin/bash


# NGINX Hardening Script
# Configures fail2ban to block IPs trying to use server as proxy

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting NGINX hardening..."

# Create fail2ban filter for nginx proxy abuse
log_info "Creating fail2ban filter for nginx proxy abuse..."
cat > "$HOME"/nginx-proxy.conf << EOF
# Block IPs trying to use server as proxy.
#
# Matches e.g.
# 192.168.1.1 - - "GET http://www.something.com/

[Definition]
failregex = ^<HOST> -.*GET http.*
ignoreregex =
EOF

# Install the filter
if ! sudo mv "$HOME"/nginx-proxy.conf /etc/fail2ban/filter.d/nginx-proxy.conf; then
    log_error "Failed to install nginx-proxy filter"
    exit 1
fi

# Create fail2ban jail configuration
log_info "Creating fail2ban jail configuration..."
cat > "$HOME"/jail.local << EOF
## block hosts trying to abuse our server as a forward proxy
[nginx-proxy]
enabled = true
port    = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400
EOF

# Install the jail configuration
if ! sudo mv "$HOME"/jail.local /etc/fail2ban/jail.local; then
    log_error "Failed to install fail2ban jail configuration"
    exit 1
fi

# Restart services
log_info "Restarting fail2ban..."
if ! sudo systemctl restart fail2ban; then
    log_error "Failed to restart fail2ban"
    exit 1
fi

log_info "Restarting nginx..."
if ! sudo systemctl restart nginx; then
    log_error "Failed to restart nginx"
    exit 1
fi

log_info "NGINX hardening completed!"
log_info "fail2ban is now configured to block proxy abuse attempts"
log_info "Filter: nginx-proxy"
log_info "Ban time: 86400 seconds (24 hours)"
log_info "Max retries: 2"
