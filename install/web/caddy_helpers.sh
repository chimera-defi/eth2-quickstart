#!/bin/bash

# Caddy Helper Functions
# Local helper functions for Caddy installation scripts

# Source common web helpers (use BASH_SOURCE so it works when sourced from any path)
CADDY_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=proxy_config_renderer.sh
source "$CADDY_HELPERS_DIR/proxy_config_renderer.sh"

# Map platform arch strings to Caddy download API arch values.
detect_caddy_arch() {
    local raw_arch
    if command -v dpkg >/dev/null 2>&1; then
        raw_arch="$(dpkg --print-architecture 2>/dev/null || true)"
    fi
    if [[ -z "$raw_arch" ]]; then
        raw_arch="$(uname -m)"
    fi

    case "$raw_arch" in
        amd64|x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        armv7l|armhf)
            echo "armv7"
            ;;
        *)
            log_error "Unsupported architecture for Caddy module bootstrap: $raw_arch"
            return 1
            ;;
    esac
}

caddy_missing_required_modules() {
    local module_csv="$1"
    local missing=()
    local module

    # Refresh cached module list if a previous call populated it.
    unset CADDY_MODULE_LIST_CACHE || true

    IFS=',' read -r -a module_list <<< "$module_csv"
    for module in "${module_list[@]}"; do
        module="$(trim_space "$module")"
        [[ -z "$module" ]] && continue
        if ! caddy_has_module "$module"; then
            missing+=("$module")
        fi
    done

    printf '%s\n' "${missing[@]}"
}

install_caddy_with_required_modules() {
    local package_csv="$1"
    local caddy_arch
    local package
    local tmp_binary
    local url="https://caddyserver.com/api/download"
    local curl_args=(--get --data-urlencode "os=linux")

    caddy_arch="$(detect_caddy_arch)" || return 1
    curl_args+=(--data-urlencode "arch=$caddy_arch")

    IFS=',' read -r -a package_list <<< "$package_csv"
    for package in "${package_list[@]}"; do
        package="$(trim_space "$package")"
        [[ -z "$package" ]] && continue
        curl_args+=(--data-urlencode "p=$package")
    done

    tmp_binary="$(mktemp /tmp/caddy.custom.XXXXXX)"
    if ! curl -fsSL "${curl_args[@]}" "$url" -o "$tmp_binary"; then
        rm -f "$tmp_binary"
        log_error "Failed to download custom Caddy binary with required modules"
        return 1
    fi
    chmod +x "$tmp_binary"

    if ! "$tmp_binary" version >/dev/null 2>&1; then
        rm -f "$tmp_binary"
        log_error "Downloaded Caddy binary failed self-check"
        return 1
    fi

    if [[ -x /usr/bin/caddy ]] && [[ ! -e /usr/bin/caddy.system-packaged ]]; then
        sudo cp /usr/bin/caddy /usr/bin/caddy.system-packaged
    fi

    if ! sudo install -m 0755 "$tmp_binary" /usr/bin/caddy; then
        rm -f "$tmp_binary"
        log_error "Failed to install custom Caddy binary to /usr/bin/caddy"
        return 1
    fi
    rm -f "$tmp_binary"

    unset CADDY_MODULE_LIST_CACHE || true
    return 0
}

ensure_caddy_security_modules() {
    local ensure_modules="${CADDY_ENSURE_MODULES:-true}"
    local required_modules="${CADDY_REQUIRED_MODULES:-http.handlers.rate_limit,dns.providers.cloudflare}"
    local required_packages="${CADDY_REQUIRED_PACKAGES:-github.com/mholt/caddy-ratelimit,github.com/caddy-dns/cloudflare}"
    local missing_modules=""

    if [[ "$ensure_modules" != "true" ]]; then
        log_info "Skipping Caddy module bootstrap (CADDY_ENSURE_MODULES=$ensure_modules)"
        return 0
    fi

    missing_modules="$(caddy_missing_required_modules "$required_modules")"
    if [[ -z "$missing_modules" ]]; then
        log_info "✓ Caddy already has required modules: $required_modules"
        return 0
    fi

    log_info "Missing Caddy modules detected:"
    printf '%s\n' "$missing_modules" | sed 's/^/  - /'
    log_info "Installing Caddy binary with required modules..."

    if ! install_caddy_with_required_modules "$required_packages"; then
        log_error "Caddy module bootstrap failed"
        return 1
    fi

    missing_modules="$(caddy_missing_required_modules "$required_modules")"
    if [[ -n "$missing_modules" ]]; then
        log_error "Caddy module bootstrap incomplete; still missing:"
        printf '%s\n' "$missing_modules" | sed 's/^/  - /'
        return 1
    fi

    log_info "✓ Caddy module bootstrap complete ($required_modules)"
    return 0
}

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

    if ! ensure_caddy_security_modules; then
        log_error "Failed to prepare Caddy with required security modules"
        return 1
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
    sudo caddy fmt --overwrite "$caddyfile_path" >/dev/null 2>&1 || true
    if ! sudo caddy adapt --config "$caddyfile_path" --adapter caddyfile >/dev/null; then
        log_error "Caddy configuration adaptation failed"
        return 1
    fi

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
        # Temp files in /tmp can hit overwrite permission edge cases in some CI
        # container setups; run non-overwrite fmt there as a syntax/style check.
        if [[ "$caddyfile_path" == /tmp/* ]]; then
            caddy fmt "$caddyfile_path" >/dev/null 2>&1 || true
        else
            caddy fmt --overwrite "$caddyfile_path" >/dev/null 2>&1 || true
        fi
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
