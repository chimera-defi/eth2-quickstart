#!/bin/bash


# NGINX Installation Script
# Installs and configures NGINX web server

source ../../exports.sh
source ../../lib/common_functions.sh

# Get script directories
get_script_directories

log_installation_start "NGINX"

log_info "Server name: $SERVER_NAME"
log_info "Login username: $LOGIN_UNAME"

log_info "Configuring NGINX..."

# Create NGINX configuration
log_info "Creating NGINX configuration..."
cat > "$HOME/nginx_conf_temp" << EOF
server {
  listen 80;
  listen [::]:80;
  server_name $SERVER_NAME;

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
      proxy_pass    http://$LH:$NETHERMIND_HTTP_PORT/;
  }
}
EOF

# Install NGINX configuration
log_info "Installing NGINX configuration..."
if ! sudo mv "$HOME/nginx_conf_temp" /etc/nginx/sites-enabled/default; then
    log_error "Failed to install NGINX configuration"
    exit 1
fi

# Setup firewall rules
log_info "Configuring firewall..."
setup_firewall_rules 80 443

# Add rate limiting
log_info "Adding rate limiting..."
add_rate_limiting

# Configure DDoS protection
log_info "Configuring DDoS protection..."
configure_ddos_protection

# Restart NGINX
log_info "Restarting NGINX..."
if ! sudo service nginx restart; then
    log_error "Failed to restart NGINX"
    exit 1
fi

# Run NGINX hardening
log_info "Running NGINX hardening..."
if ! ./nginx_harden.sh; then
    log_warn "NGINX hardening script failed, but continuing..."
fi

log_installation_complete "NGINX" "nginx" "/etc/nginx/sites-available/default" "/etc/nginx"
log_info "Server name: $SERVER_NAME"
log_info "WebSocket endpoint: http://$SERVER_NAME/ws"
log_info "RPC endpoint: http://$SERVER_NAME/rpc"
