#!/bin/bash

# Caddy Helper Functions
# Local helper functions for Caddy installation scripts

# Source common web helpers (use BASH_SOURCE so it works when sourced from any path)
CADDY_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=web_helpers_common.sh
source "$CADDY_HELPERS_DIR/web_helpers_common.sh"

# Install Caddy web server
install_caddy() {
    log_info "Installing Caddy web server..."
    
    if ! command_exists caddy; then
        # Add Caddy's GPG key
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        
        # Add Caddy's repository
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
        
        # Update package list
        sudo apt-get update
        
        # Install Caddy
        sudo apt-get install -y caddy
        
        log_info "Caddy installed successfully"
    else
        log_info "Caddy is already installed"
    fi
}

# Setup Caddy service and directories
setup_caddy_service() {
    log_info "Setting up Caddy service and directories..."
    
    # Create Caddy configuration directory
    sudo mkdir -p /etc/caddy
    sudo chown caddy:caddy /etc/caddy
    
    # Create log directory
    sudo mkdir -p /var/log/caddy
    sudo chown caddy:caddy /var/log/caddy
    
    # Enable and start Caddy service
    if ! enable_and_start_systemd_service caddy; then
        log_error "Failed to start Caddy service"
        return 1
    fi
    
    log_info "✓ Caddy service setup complete"
}

# Validate Caddy configuration
validate_caddy_config() {
    local caddyfile_path="$1"
    
    log_info "Validating Caddy configuration..."
    
    if sudo caddy validate --config "$caddyfile_path" --adapter caddyfile; then
        log_info "✓ Caddy configuration is valid"
        return 0
    else
        log_error "Caddy configuration validation failed"
        return 1
    fi
}

# Create Caddy configuration with automatic HTTPS
create_caddy_config_auto_https() {
    local server_name="$1"
    local caddyfile_path="$2"
    
    log_info "Creating Caddy configuration with automatic HTTPS for $server_name..."
    
    # CI/E2E: minimal config - tls internal, no rate_limit/request_body (require plugins in default Caddy)
    # Production: full config with dns cloudflare, rate_limit, request_body
    if [[ "${CI_E2E:-}" == "true" ]]; then
        # Minimal config for default Caddy - matches Nginx structure (ws/rpc reverse proxy)
        # No log block, no rate_limit/request_body (require plugins)
        cat > "$caddyfile_path" << EOF
{
    auto_https off
}

http://$server_name {
    redir https://$server_name{uri} permanent
}

https://$server_name {
    tls internal
    
    handle /ws* {
        reverse_proxy $LH:$NETHERMIND_WS_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    handle /rpc* {
        reverse_proxy $LH:$NETHERMIND_HTTP_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
    else
        # Production: full config with rate_limit, request_body (requires Caddy with plugins)
        TLS_LINE='    tls {
        dns cloudflare {
            env CLOUDFLARE_API_TOKEN
        }
    }'
        cat > "$caddyfile_path" << EOF
{
    auto_https off
    servers {
        protocols h1 h2 h3
    }
}

http://$server_name {
    redir https://$server_name{uri} permanent
}

https://$server_name {
$TLS_LINE
    
    handle /ws* {
        rate_limit zone ws
        reverse_proxy $LH:$NETHERMIND_WS_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    handle /rpc* {
        rate_limit zone api
        reverse_proxy $LH:$NETHERMIND_HTTP_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:; font-src 'self' data:; object-src 'none'; media-src 'self'; frame-src 'none';"
        Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(self), sync-xhr=()"
    }
    
    rate_limit {
        zone api {
            key {remote_host}
            events 50
            window 1m
        }
        zone ws {
            key {remote_host}
            events 20
            window 1m
        }
        zone general {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    request_body {
        max_size 10MB
    }
    
    timeouts {
        read_timeout 30s
        read_header_timeout 30s
        write_timeout 30s
        idle_timeout 60s
    }
    
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 5
            roll_keep_for 720h
        }
        format json
        level INFO
    }
}
EOF
    fi
    
    log_info "Caddy configuration created: $caddyfile_path"
}

# Create Caddy configuration with manual SSL
create_caddy_config_manual_ssl() {
    local server_name="$1"
    local caddyfile_path="$2"
    local cert_path="$3"
    local key_path="$4"
    
    log_info "Creating Caddy configuration with manual SSL for $server_name..."
    
    cat > "$caddyfile_path" << EOF
{
    # Global options (Caddy v2)
    auto_https off
    servers {
        protocols h1 h2 h3
        # Connection limits note: Caddy v2 doesn't have built-in connection limiting like Nginx's limit_conn
        # Consider using fail2ban or external firewall rules for connection-based DDoS protection
    }
}

# HTTP to HTTPS redirect
http://$server_name {
    redir https://$server_name{uri} permanent
}

# Main HTTPS site with manual SSL
https://$server_name {
    # Manual SSL certificate configuration
    tls $cert_path $key_path
    
    # WebSocket proxy with rate limiting
    handle /ws* {
        rate_limit zone ws
        reverse_proxy $LH:$NETHERMIND_WS_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # HTTP proxy with rate limiting
    handle /rpc* {
        rate_limit zone api
        reverse_proxy $LH:$NETHERMIND_HTTP_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # Security headers
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        
        # Prevent clickjacking
        X-Frame-Options "DENY"
        
        # Prevent MIME type sniffing
        X-Content-Type-Options "nosniff"
        
        # XSS protection
        X-XSS-Protection "1; mode=block"
        
        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"
        
        # Content Security Policy
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:; font-src 'self' data:; object-src 'none'; media-src 'self'; frame-src 'none';"
        
        # Permissions Policy (added to match Nginx)
        Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(self), sync-xhr=()"
    }
    
    # Enhanced rate limiting (from PR #40, consistent with Nginx)
    # Note: Caddy v2 rate limiting doesn't support burst like Nginx
    # The events count limits requests per window (similar to Nginx's rate)
    rate_limit {
        zone api {
            key {remote_host}
            events 50
            window 1m
        }
        zone ws {
            key {remote_host}
            events 20
            window 1m
        }
        zone general {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
    # Enhanced DDoS protection (from PR #40, consistent with Nginx)
    # Request size limits (equivalent to Nginx's client_max_body_size)
    request_body {
        max_size 10MB
    }
    
    # Timeout configurations (consistent with Nginx)
    # Caddy v2 timeouts align with Nginx's timeout settings
    timeouts {
        read_timeout 30s           # Equivalent to Nginx client_body_timeout
        read_header_timeout 30s    # Equivalent to Nginx client_header_timeout (matched to 30s)
        write_timeout 30s          # Equivalent to Nginx send_timeout
        idle_timeout 60s           # Equivalent to Nginx keepalive_timeout
    }
    
    # Note: Connection limiting (limit_conn) not available in Caddy v2
    # Use system-level tools (fail2ban, UFW) or Caddy plugins if needed
    
    # Logging
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 5
            roll_keep_for 720h
        }
        format json
        level INFO
    }
}
EOF
    
    log_info "Caddy SSL configuration created: $caddyfile_path"
}