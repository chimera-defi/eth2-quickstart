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

# Go's module cache is read-only; make it writable so rm -rf succeeds.
_caddy_rm_work() {
    chmod -R u+w "$1" 2>/dev/null || true
    rm -rf "$1"
}

# Build Caddy with the required plugins using a pinned, checksum-verified
# toolchain (Go + xcaddy). caddyserver.com/api/download now answers 401 ("Please
# log in or use an API key to build Caddy"), so it is no longer used.
# Nothing is fetched without a pinned SHA-256; the toolchain lives in a temp dir.
install_caddy_with_required_modules() {
    local package_csv="$1"
    local caddy_arch go_sha xcaddy_sha # go: sha256, xcaddy: sha512 (as published)
    local go_ver="${CADDY_BUILD_GO_VERSION:-1.26.11}"
    local xcaddy_ver="${CADDY_BUILD_XCADDY_VERSION:-0.4.7}"
    local caddy_ver="${CADDY_BUILD_VERSION:-2.11.9}"
    local package pin work tmp_binary
    local with_args=()

    caddy_arch="$(detect_caddy_arch)" || return 1
    case "$caddy_arch" in
        amd64)
            go_sha="9849f4e04ee35303714e34fbc3ac8ab44ea3e448a95aa182f91e3b9b79c710ec"
            xcaddy_sha="99fd895a7b7799b18c43ea0915777d8701aaab2a010035b23495c28b4ae429edccd70adb9a01106180f8d9333d9b5df41e74f9702ce0e1cffcf8840698a9ab93"
            ;;
        arm64)
            go_sha="6c2f29b458b5add0835f18b776f69c8881a6d88428f1484a6da55755e620757e"
            xcaddy_sha="b4d52ad6db4184fa5366ef225d24b8340a47fc1924d250b329d3b95f416a0b14e16d72cf71f04f57046e8a26bad2b697ac14c833fc5f5607b9e1c838b9898520"
            ;;
        *)
            log_error "No pinned Go/xcaddy toolchain for architecture: $caddy_arch (amd64 and arm64 only)"
            return 1
            ;;
    esac
    # The pinned checksums above belong to the default versions only.
    if [[ "$go_ver" != "1.26.11" || "$xcaddy_ver" != "0.4.7" ]]; then
        log_error "CADDY_BUILD_GO_VERSION/CADDY_BUILD_XCADDY_VERSION overrides need matching checksums in caddy_helpers.sh"
        return 1
    fi

    IFS=',' read -r -a package_list <<< "$package_csv"
    for package in "${package_list[@]}"; do
        package="$(trim_space "$package")"
        [[ -z "$package" ]] && continue
        if [[ "$package" != *@* ]]; then
            pin="$(printf '%s\n' "${CADDY_PACKAGE_PINS:-}" | tr ',' '\n' | grep -F "${package}@" | head -1 || true)"
            [[ -n "$pin" ]] && package="$(trim_space "$pin")"
        fi
        with_args+=(--with "$package")
    done

    work="$(mktemp -d /tmp/caddy.build.XXXXXX)"
    tmp_binary="$work/caddy"

    log_info "Building Caddy v$caddy_ver (Go $go_ver, xcaddy $xcaddy_ver) with: ${with_args[*]}"
    if ! curl -fsSL "https://go.dev/dl/go${go_ver}.linux-${caddy_arch}.tar.gz" -o "$work/go.tgz" \
        || ! echo "$go_sha  $work/go.tgz" | sha256sum -c - >/dev/null; then
        _caddy_rm_work "$work"; log_error "Go toolchain download or checksum verification failed"; return 1
    fi
    if ! curl -fsSL "https://github.com/caddyserver/xcaddy/releases/download/v${xcaddy_ver}/xcaddy_${xcaddy_ver}_linux_${caddy_arch}.tar.gz" -o "$work/xcaddy.tgz" \
        || ! echo "$xcaddy_sha  $work/xcaddy.tgz" | sha512sum -c - >/dev/null; then
        _caddy_rm_work "$work"; log_error "xcaddy download or checksum verification failed"; return 1
    fi
    mkdir -p "$work/tools" "$work/xc"
    if ! tar -xzf "$work/go.tgz" -C "$work/tools" || ! tar -xzf "$work/xcaddy.tgz" -C "$work/xc" xcaddy; then
        _caddy_rm_work "$work"; log_error "Failed to unpack Go/xcaddy"; return 1
    fi

    if ! (
        cd "$work"
        export GOROOT="$work/tools/go" GOPATH="$work/gopath" GOCACHE="$work/gocache" GOFLAGS=-mod=mod GOTOOLCHAIN=local
        export PATH="$GOROOT/bin:$PATH"
        "$work/xc/xcaddy" build "v${caddy_ver}" "${with_args[@]}" --output "$tmp_binary"
    ); then
        _caddy_rm_work "$work"
        log_error "xcaddy build failed"
        return 1
    fi

    if ! "$tmp_binary" version >/dev/null 2>&1; then
        _caddy_rm_work "$work"
        log_error "Built Caddy binary failed self-check"
        return 1
    fi

    if [[ -x /usr/bin/caddy ]] && [[ ! -e /usr/bin/caddy.system-packaged ]]; then
        sudo cp /usr/bin/caddy /usr/bin/caddy.system-packaged
    fi

    if ! sudo install -m 0755 "$tmp_binary" /usr/bin/caddy; then
        _caddy_rm_work "$work"
        log_error "Failed to install custom Caddy binary to /usr/bin/caddy"
        return 1
    fi
    _caddy_rm_work "$work"

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
        if ! { sudo apt-get update && sudo apt-get install -y --only-upgrade caddy; }; then
            log_warn "Could not upgrade the caddy package"
        fi
    fi

    if ! ensure_caddy_security_modules; then
        log_error "Failed to prepare Caddy with required security modules"
        return 1
    fi

    local caddy_ver
    caddy_ver="$({ caddy version 2>/dev/null || true; } | sed -n 's/^v\{0,1\}\([0-9][0-9.]*\).*/\1/p' | head -1)"
    local caddy_min="${CADDY_MIN_VERSION:-2.11.4}"
    if [[ -n "$caddy_ver" && "$(printf '%s\n%s\n' "$caddy_min" "$caddy_ver" | sort -V | head -1)" != "$caddy_min" ]]; then
        log_error "Caddy $caddy_ver is older than the patched minimum $caddy_min"
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
