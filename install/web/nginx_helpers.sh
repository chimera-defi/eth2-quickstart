#!/bin/bash

# Nginx Helper Functions
# Local helper functions for Nginx installation scripts

NGINX_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=proxy_config_renderer.sh
source "$NGINX_HELPERS_DIR/proxy_config_renderer.sh"

# nginx.org signing key fingerprint (https://nginx.org/en/linux_packages.html)
NGINX_ORG_KEY_FPR="573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62"

# Account nginx workers run as: nginx.org packages use "nginx", distro packages "www-data"
nginx_run_user() {
    if id -u nginx >/dev/null 2>&1; then echo nginx; else echo www-data; fi
}

# Print the installed nginx version (e.g. 1.30.7), empty if nginx is absent
nginx_installed_version() {
    command_exists nginx || return 0
    nginx -v 2>&1 | sed -n 's|.*nginx/\([0-9][0-9.]*\).*|\1|p' | head -1
}

# True when $1 >= $2 (dotted versions)
version_at_least() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

# Add the signed nginx.org stable apt repo, pinned above distro packages.
# Distro nginx lags upstream security releases (see docs/CVE_AUDIT_2026-11.md).
setup_nginx_upstream_repo() {
    local os_id codename key_tmp
    os_id="$(. /etc/os-release && echo "${ID:-}")"
    codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
    if [[ "$os_id" != "ubuntu" && "$os_id" != "debian" ]] || [[ -z "$codename" ]]; then
        log_warn "nginx.org repo supports Ubuntu/Debian only (found: ${os_id:-unknown}); using distro nginx"
        return 1
    fi

    key_tmp="$(mktemp)"
    if ! curl -fsSL --proto '=https' --tlsv1.2 https://nginx.org/keys/nginx_signing.key -o "$key_tmp"; then
        rm -f "$key_tmp"
        log_error "Failed to download nginx.org signing key"
        return 1
    fi
    if ! gpg --show-keys --with-colons "$key_tmp" 2>/dev/null | grep -q "^fpr:::::::::${NGINX_ORG_KEY_FPR}:"; then
        rm -f "$key_tmp"
        log_error "nginx.org signing key fingerprint mismatch (expected $NGINX_ORG_KEY_FPR)"
        return 1
    fi
    sudo gpg --dearmor --yes -o /usr/share/keyrings/nginx-archive-keyring.gpg "$key_tmp"
    rm -f "$key_tmp"

    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] https://nginx.org/packages/${os_id} ${codename} nginx" \
        | sudo tee /etc/apt/sources.list.d/nginx.list >/dev/null
    printf 'Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n' \
        | sudo tee /etc/apt/preferences.d/99nginx >/dev/null
    return 0
}

# nginx.org packages only include conf.d/*.conf and ship a conflicting default
# server; keep our sites-enabled layout working and drop the stock site.
adapt_nginx_upstream_layout() {
    sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d
    if ! grep -rqs "sites-enabled" /etc/nginx/nginx.conf /etc/nginx/conf.d/; then
        echo 'include /etc/nginx/sites-enabled/*;' | sudo tee /etc/nginx/conf.d/00-sites-enabled.conf >/dev/null
    fi
    # Our edge policy (conf.d/eth2-edge-policy.conf) sets keepalive_timeout; the stock
    # nginx.org nginx.conf also sets it, and a duplicate directive fails nginx -t.
    sudo sed -i 's/^\([[:space:]]*\)keepalive_timeout\b/\1#keepalive_timeout/' /etc/nginx/nginx.conf
    if [[ -f /etc/nginx/conf.d/default.conf ]]; then
        sudo mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
    fi
}

# Install Nginx web server (NGINX_SOURCE=upstream|distro, default upstream)
install_nginx() {
    local source="${NGINX_SOURCE:-upstream}"
    local min_version="${NGINX_MIN_VERSION:-1.30.7}"
    local installed

    log_info "Installing Nginx web server (source: $source)..."

    if [[ "$source" == "upstream" ]] && setup_nginx_upstream_repo; then
        sudo apt-get update
        # Replace a distro-packaged nginx (config files are kept; only packages removed)
        if dpkg -s nginx-common >/dev/null 2>&1; then
            sudo apt-get remove -y nginx nginx-core nginx-common nginx-full nginx-light nginx-extras 2>/dev/null || true
        fi
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            -o Dpkg::Options::=--force-confold nginx
        adapt_nginx_upstream_layout
    elif ! command_exists nginx; then
        sudo apt-get update
        sudo apt-get install -y nginx
    else
        sudo apt-get install -y --only-upgrade nginx || true
    fi

    installed="$(nginx_installed_version)"
    if [[ -z "$installed" ]]; then
        log_error "nginx is not installed"
        return 1
    fi
    log_info "Nginx $installed installed"
    if [[ "$source" == "upstream" ]] && ! version_at_least "$installed" "$min_version"; then
        log_error "nginx $installed is older than the patched minimum $min_version"
        return 1
    fi
    if [[ "$source" != "upstream" ]]; then
        log_warn "Distro nginx $installed: version numbers are backported; check your distro's security tracker for the nginx.org advisories"
    fi
}

# Setup Nginx service and directories
setup_nginx_service() {
    log_info "Setting up Nginx service and directories..."

    sudo mkdir -p /etc/nginx/sites-available
    sudo mkdir -p /etc/nginx/sites-enabled
    sudo mkdir -p /etc/nginx/conf.d
    sudo mkdir -p /var/log/nginx
    sudo chown "$(nginx_run_user):$(nginx_run_user)" /var/log/nginx

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
    sudo chown -R "$(nginx_run_user):$(nginx_run_user)" /var/cache/nginx
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
