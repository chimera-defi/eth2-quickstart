#!/bin/bash

# Caddy Helper Functions
# Local helper functions for Caddy installation scripts

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
    
    if sudo caddy validate --config "$caddyfile_path"; then
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
    
    cat > "$caddyfile_path" << EOF
{
    # Global options
    auto_https off
    servers {
        protocols h1 h2 h3
    }
}

# HTTP to HTTPS redirect
http://$server_name {
    redir https://$server_name{uri} permanent
}

# Main HTTPS site
https://$server_name {
    # Enable automatic HTTPS
    tls {
        dns cloudflare {
            env CLOUDFLARE_API_TOKEN
        }
    }
    
    # WebSocket proxy for Ethereum WebSocket API
    handle /ws* {
        reverse_proxy $LH:$NETHERMIND_WS_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # HTTP proxy for Ethereum RPC API
    handle /rpc* {
        reverse_proxy $LH:$NETHERMIND_HTTP_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # Prysm checkpoint sync endpoint
    handle /prysm/checkpt_sync* {
        reverse_proxy $LH:3500 {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # Prysm web interface
    handle /prysm/web* {
        reverse_proxy $LH:7500 {
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
    }
    
    # Rate limiting
    rate_limit {
        zone static {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
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
    # Global options
    auto_https off
    servers {
        protocols h1 h2 h3
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
    
    # WebSocket proxy for Ethereum WebSocket API
    handle /ws* {
        reverse_proxy $LH:$NETHERMIND_WS_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # HTTP proxy for Ethereum RPC API
    handle /rpc* {
        reverse_proxy $LH:$NETHERMIND_HTTP_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # Prysm checkpoint sync endpoint
    handle /prysm/checkpt_sync* {
        reverse_proxy $LH:3500 {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
    }
    
    # Prysm web interface
    handle /prysm/web* {
        reverse_proxy $LH:7500 {
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
    }
    
    # Rate limiting
    rate_limit {
        zone static {
            key {remote_host}
            events 100
            window 1m
        }
    }
    
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