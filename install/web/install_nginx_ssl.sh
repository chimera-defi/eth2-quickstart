#!/bin/bash


# NGINX SSL Configuration Script
# Configures NGINX to use SSL certificates

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting NGINX SSL configuration..."
log_info "Server name: $SERVER_NAME"

# Create SSL-enabled NGINX configuration
log_info "Creating SSL-enabled NGINX configuration..."
cat > "$HOME/nginx_conf_temp" << EOF
server {
  listen 80;
  listen [::]:80;
  server_name $SERVER_NAME;

  listen [::]:443 ssl ipv6only=on;
  listen 443 ssl;
  ssl_certificate /etc/letsencrypt/live/$SERVER_NAME/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$SERVER_NAME/privkey.pem;

  location ^~ /ws {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Host \$http_host;
      proxy_set_header X-NginX-Proxy true;
      proxy_pass   http://$LH:$NETHERMIND_WS_PORT/;
  }

  location ^~ /rpc {
      proxy_http_version 1.1;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Host \$http_host;
      proxy_set_header X-NginX-Proxy true;
      proxy_pass    http://127.0.0.1:8545/;
  }
}
EOF

# Verify SSL certificates exist
log_info "Verifying SSL certificates..."
if [[ ! -f "/etc/letsencrypt/live/$SERVER_NAME/fullchain.pem" ]]; then
    log_error "SSL certificate not found: /etc/letsencrypt/live/$SERVER_NAME/fullchain.pem"
    log_error "Please run install_ssl_certbot.sh or install_acme_ssl.sh first"
    exit 1
fi

# Install SSL-enabled NGINX configuration
log_info "Installing SSL-enabled NGINX configuration..."
if ! sudo mv "$HOME/nginx_conf_temp" /etc/nginx/sites-enabled/default; then
    log_error "Failed to install SSL NGINX configuration"
    exit 1
fi

# Setup firewall rules
log_info "Configuring firewall for SSL..."
setup_firewall_rules 80 443

# Add rate limiting
log_info "Adding rate limiting..."
add_rate_limiting

# Configure DDoS protection
log_info "Configuring DDoS protection..."
configure_ddos_protection

# Restart NGINX
log_info "Restarting NGINX with SSL configuration..."
if ! sudo systemctl restart nginx; then
    log_error "Failed to restart NGINX"
    exit 1
fi

# Run NGINX hardening
log_info "Running NGINX hardening..."
if ! ./nginx_harden.sh; then
    log_warn "NGINX hardening script failed, but continuing..."
fi

log_info "NGINX SSL configuration completed!"
log_info "Server name: $SERVER_NAME"
log_info "HTTPS WebSocket endpoint: https://$SERVER_NAME/ws"
log_info "HTTPS RPC endpoint: https://$SERVER_NAME/rpc"
