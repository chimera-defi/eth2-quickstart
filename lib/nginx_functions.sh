#!/bin/bash

# Nginx-specific functions for web server configuration
# This library contains functions only used by nginx installation scripts

# Strict mode and safe defaults for sourced scripts
set -Eeuo pipefail
IFS=$'\n\t'

# Source common functions
source "$(dirname "$0")/common_functions.sh" 2>/dev/null || source "./lib/common_functions.sh"

# =============================================================================
# NGINX CONFIGURATION FUNCTIONS
# =============================================================================

add_rate_limiting() {
    local config_file="/etc/nginx/sites-available/default"
    
    log_info "Adding rate limiting to nginx configuration..."
    
    # Check if rate limiting is already configured
    if grep -q "limit_req_zone" "$config_file" 2>/dev/null; then
        log_info "Rate limiting already configured"
        return 0
    fi
    
    # Create backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add rate limiting configuration
    cat >> "$config_file" << 'EOF'

# Rate limiting for RPC endpoints
limit_req_zone $binary_remote_addr zone=rpc_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ws_limit:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;

server {
    # Apply rate limiting to RPC endpoints
    location /rpc {
        limit_req zone=rpc_limit burst=20 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8545;
    }
    
    location /ws {
        limit_req zone=ws_limit burst=10 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8546;
    }
    
    location /api {
        limit_req zone=api_limit burst=30 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:5051;
    }
}
EOF

    # Test nginx configuration
    if nginx -t >/dev/null 2>&1; then
        log_info "Rate limiting configuration added successfully"
        systemctl reload nginx
    else
        log_error "Invalid nginx configuration, restoring backup"
        mv "${config_file}.backup.$(date +%Y%m%d_%H%M%S)" "$config_file"
        return 1
    fi
}

configure_ddos_protection() {
    log_info "Configuring DDoS protection..."
    
    # Add connection limiting
    cat > /etc/nginx/conf.d/security.conf << 'EOF'
# DDoS protection
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn_zone $server_name zone=conn_limit_per_server:10m;

# Rate limiting
limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=10r/s;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

# Hide nginx version
server_tokens off;

# Connection limits
limit_conn conn_limit_per_ip 10;
limit_conn conn_limit_per_server 1000;
EOF

    log_info "DDoS protection configured"
}