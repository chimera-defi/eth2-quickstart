#!/bin/bash

# Nginx Helper Functions
# Local helper functions for Nginx installation scripts

NGINX_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=web_helpers_common.sh
source "$NGINX_HELPERS_DIR/web_helpers_common.sh"
# shellcheck source=proxy_config_renderer.sh
source "$NGINX_HELPERS_DIR/proxy_config_renderer.sh"

# Install Nginx web server
install_nginx() {
    log_info "Installing Nginx web server..."

    if ! command_exists nginx; then
        sudo apt-get update
        sudo apt-get install -y nginx
        log_info "Nginx installed successfully"
    else
        log_info "Nginx is already installed"
    fi
}

# Setup Nginx service and directories
setup_nginx_service() {
    log_info "Setting up Nginx service and directories..."

    sudo mkdir -p /etc/nginx/sites-available
    sudo mkdir -p /etc/nginx/sites-enabled
    sudo mkdir -p /etc/nginx/conf.d
    sudo mkdir -p /var/log/nginx
    sudo chown www-data:www-data /var/log/nginx

    if ! enable_and_start_systemd_service nginx; then
        log_error "Failed to start Nginx service"
        return 1
    fi

    log_info "✓ Nginx service setup complete"
}

# Validate Nginx configuration
validate_nginx_config() {
    local config_file="${1:-/etc/nginx/nginx.conf}"

    log_info "Validating Nginx configuration..."
    if sudo nginx -t -c "$config_file"; then
        log_info "✓ Nginx configuration is valid"
        return 0
    fi

    log_error "Nginx configuration validation failed"
    return 1
}

write_nginx_shared_http_policy() {
    local temp_file
    temp_file="$(mktemp)"

    render_nginx_http_policy_file "$temp_file"

    if ! sudo mv "$temp_file" /etc/nginx/conf.d/eth2-edge-policy.conf; then
        rm -f "$temp_file"
        log_error "Failed to install shared Nginx edge policy"
        return 1
    fi
    sudo chown root:root /etc/nginx/conf.d/eth2-edge-policy.conf
    sudo chmod 644 /etc/nginx/conf.d/eth2-edge-policy.conf
    return 0
}

prepare_nginx_cache_dirs() {
    sudo mkdir -p /var/cache/nginx/rpc_cache
    sudo mkdir -p /var/cache/nginx/client_temp
    sudo chown -R www-data:www-data /var/cache/nginx
}

# Add shared policy (rate limiting, connection limits, cache zones)
add_rate_limiting() {
    log_info "Adding shared edge policy to Nginx..."

    prepare_nginx_cache_dirs
    if write_nginx_shared_http_policy; then
        log_info "✓ Shared edge policy installed"
        return 0
    fi

    log_error "Failed to install shared edge policy"
    return 1
}

# Configure DDoS protection (implemented via shared edge policy + cache dirs)
configure_ddos_protection() {
    log_info "Configuring enhanced DDoS protection..."
    prepare_nginx_cache_dirs

    if [[ -f /etc/nginx/conf.d/eth2-edge-policy.conf ]]; then
        log_info "✓ Enhanced DDoS protection configured in shared edge policy"
        return 0
    fi

    if write_nginx_shared_http_policy; then
        log_info "✓ Enhanced DDoS protection configured in shared edge policy"
        return 0
    fi

    log_error "Failed to configure enhanced DDoS protection"
    return 1
}

# Create Nginx base configuration from shared policy renderer
create_nginx_config() {
    local server_name="$1"
    local config_path="$2"
    local use_ssl="${3:-false}"
    local cert_path="${4:-}"
    local key_path="${5:-}"

    log_info "Creating Nginx configuration for $server_name..."
    render_nginx_site_config "$server_name" "$config_path" "$use_ssl" "$cert_path" "$key_path"
    log_info "Nginx configuration created: $config_path"
}
