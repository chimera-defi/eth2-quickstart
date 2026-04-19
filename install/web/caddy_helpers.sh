#!/bin/bash

# Caddy Helper Functions
# Local helper functions for Caddy installation scripts

# Source common web helpers (use BASH_SOURCE so it works when sourced from any path)
CADDY_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=proxy_config_renderer.sh
source "$CADDY_HELPERS_DIR/proxy_config_renderer.sh"

# Install Caddy web server
install_caddy() {
    log_info "Installing Caddy web server..."

    if ! command_exists caddy; then
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        sudo apt-get update
        sudo apt-get install -y caddy
        log_info "Caddy installed successfully"
    else
        log_info "Caddy is already installed"
    fi
}

# Setup Caddy service and directories
setup_caddy_service() {
    log_info "Setting up Caddy service and directories..."

    sudo mkdir -p /etc/caddy
    sudo chown caddy:caddy /etc/caddy
    sudo mkdir -p /var/log/caddy
    sudo chown caddy:caddy /var/log/caddy
    sudo touch /var/log/caddy/access.log
    sudo chown caddy:caddy /var/log/caddy/access.log
    sudo chmod 640 /var/log/caddy/access.log

    if ! enable_systemd_service caddy; then
        log_error "Failed to enable Caddy service"
        return 1
    fi

    log_info "✓ Caddy service setup complete"
}

# Restart Caddy after config changes and verify active state.
restart_caddy_service() {
    if ! enable_systemd_service caddy; then
        log_error "Failed to enable Caddy service"
        return 1
    fi

    if ! sudo systemctl restart caddy; then
        log_error "Failed to restart Caddy service"
        return 1
    fi

    if sudo systemctl is-active --quiet caddy; then
        log_info "Restarted systemd service: caddy"
        return 0
    fi

    log_error "Caddy service is not active after restart"
    sudo systemctl status caddy --no-pager -l 2>/dev/null | sed 's/^/  /' || true
    sudo journalctl -u caddy -n 80 --no-pager 2>/dev/null | sed 's/^/  /' || true
    return 1
}

# Validate Caddy configuration
validate_caddy_config() {
    local caddyfile_path="$1"

    log_info "Validating Caddy configuration..."
    if sudo caddy validate --config "$caddyfile_path" --adapter caddyfile; then
        log_info "✓ Caddy configuration is valid"
        return 0
    fi

    log_error "Caddy configuration validation failed"
    return 1
}

format_caddy_config() {
    local caddyfile_path="$1"
    if command -v caddy &>/dev/null; then
        caddy fmt --overwrite "$caddyfile_path" >/dev/null 2>&1 || true
    fi
}

# Create Caddy configuration with automatic HTTPS or CI internal TLS
create_caddy_config_auto_https() {
    local server_name="$1"
    local caddyfile_path="$2"

    log_info "Creating Caddy configuration with shared edge policy for $server_name..."
    render_caddy_site_config "$server_name" "$caddyfile_path" "auto"
    format_caddy_config "$caddyfile_path"
    log_info "Caddy configuration created: $caddyfile_path"
}

# Create Caddy configuration with manual SSL
create_caddy_config_manual_ssl() {
    local server_name="$1"
    local caddyfile_path="$2"
    local cert_path="$3"
    local key_path="$4"

    log_info "Creating Caddy configuration with manual SSL for $server_name..."
    render_caddy_site_config "$server_name" "$caddyfile_path" "manual" "$cert_path" "$key_path"
    format_caddy_config "$caddyfile_path"
    log_info "Caddy SSL configuration created: $caddyfile_path"
}
