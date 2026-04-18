#!/bin/bash

# Shared proxy configuration renderer for Nginx and Caddy.
# This file is the single source of truth for RPC routing, spam blocking,
# headers, and request-shape hardening shared between both servers.

if [[ -n "${ETH2QS_PROXY_CONFIG_RENDERER_LOADED:-}" ]]; then
    return 0
fi
ETH2QS_PROXY_CONFIG_RENDERER_LOADED=1

readonly PROXY_RPC_READ_METHODS_REGEX='eth_chainId|net_version|web3_clientVersion|eth_blockNumber|eth_getBlockByNumber|eth_getBlockByHash|eth_getTransactionByHash|eth_getTransactionReceipt|eth_getBalance|eth_getCode|eth_getStorageAt|eth_call|eth_estimateGas|eth_getLogs|eth_feeHistory|eth_gasPrice'
readonly PROXY_RPC_WRITE_METHODS_REGEX='eth_sendRawTransaction|eth_sendTransaction|personal_sendTransaction|engine_[[:alnum:]_]+|admin_[[:alnum:]_]+|miner_[[:alnum:]_]+|txpool_[[:alnum:]_]+|debug_[[:alnum:]_]+'
readonly PROXY_SPAM_EXTENSIONS_REGEX='m3u8|m3u|php|asp|aspx|jsp|cgi|pl|env|git|bak|ini|sql|sqlite|tar|gz|zip'
readonly PROXY_ATTACK_PATHS_REGEX='admin|wp-admin|wp-login|\.env|config|cgi-bin|phpmyadmin|boaform|HNAP1|xmlrpc\.php'

render_nginx_http_policy_file() {
    local output_path="$1"

    cat > "$output_path" << 'EOF'
# Shared edge policy (generated)

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=50r/m;
limit_req_zone $binary_remote_addr zone=ws:10m rate=20r/m;
limit_req_zone $binary_remote_addr zone=general:10m rate=100r/m;
limit_req_status 429;

# Connection limiting zones
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn_zone $binary_remote_addr zone=conn_limit_total:10m;
limit_conn_status 429;

# RPC read cache
proxy_cache_path /var/cache/nginx/rpc_cache levels=1:2 keys_zone=rpc_read_cache:50m max_size=1g inactive=2m use_temp_path=off;

# Timeout and body controls
client_body_buffer_size 128k;
client_max_body_size 10m;
client_body_timeout 30s;
client_header_timeout 30s;
keepalive_timeout 60s;
send_timeout 30s;
client_body_temp_path /var/cache/nginx/client_temp 1 2;

# Leak less fingerprinting info
server_tokens off;
EOF

    cat >> "$output_path" << EOF

# Classify JSON-RPC request bodies for cache safety.
# These maps evaluate when Nginx has access to the request body.
map \$request_body \$rpc_is_read_method {
    default 0;
    ~*\"method\"\\s*:\\s*\"($PROXY_RPC_READ_METHODS_REGEX)\" 1;
}

map \$request_body \$rpc_is_write_method {
    default 0;
    ~*\"method\"\\s*:\\s*\"($PROXY_RPC_WRITE_METHODS_REGEX)\" 1;
}

map \$request_body \$rpc_has_dynamic_block_tag {
    default 0;
    ~*\"(latest|pending)\" 1;
}

map "\$rpc_is_read_method:\$rpc_is_write_method:\$rpc_has_dynamic_block_tag" \$rpc_cache_bypass {
    default 1;
    "1:0:0" 0;
}
EOF
}

render_nginx_site_config() {
    local server_name="$1"
    local config_path="$2"
    local use_ssl="${3:-false}"
    local cert_path="${4:-}"
    local key_path="${5:-}"

    if [[ "$use_ssl" == "true" ]]; then
        cat > "$config_path" << EOF
# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name $server_name;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $server_name;

    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:; font-src 'self' data:; object-src 'none'; media-src 'self'; frame-src 'none';" always;
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(self), sync-xhr=()" always;

    location ~* \\.($PROXY_SPAM_EXTENSIONS_REGEX)(?:\$|/) {
        access_log off;
        log_not_found off;
        return 403;
    }

    location ~* ^/($PROXY_ATTACK_PATHS_REGEX)(?:\$|/) {
        return 403;
    }

    location = / {
        return 404;
    }

    location ^~ /ws {
        if (\$request_method != GET) {
            return 405;
        }

        limit_req zone=ws burst=5 nodelay;
        limit_conn conn_limit_per_ip 20;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://$LH:$NETHERMIND_WS_PORT/;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
    }

    location ^~ /rpc {
        if (\$request_method != POST) {
            return 405;
        }

        limit_req zone=api burst=10 nodelay;
        limit_conn conn_limit_per_ip 30;

        proxy_cache rpc_read_cache;
        proxy_cache_methods POST;
        proxy_cache_key "\$scheme://\$host\$request_uri|\$request_body";
        proxy_cache_lock on;
        proxy_cache_lock_age 5s;
        proxy_cache_lock_timeout 10s;
        proxy_cache_valid 200 2s;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_bypass 0;
        proxy_no_cache \$rpc_cache_bypass;

        add_header X-RPC-Cache \$upstream_cache_status always;
        add_header X-RPC-Cache-Bypass \$rpc_cache_bypass always;

        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://$LH:$NETHERMIND_HTTP_PORT/;
        proxy_read_timeout 30s;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }

    location / {
        return 403;
    }
}
EOF
        return 0
    fi

    cat > "$config_path" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $server_name;

    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location ~* \\.($PROXY_SPAM_EXTENSIONS_REGEX)(?:\$|/) {
        access_log off;
        log_not_found off;
        return 403;
    }

    location ~* ^/($PROXY_ATTACK_PATHS_REGEX)(?:\$|/) {
        return 403;
    }

    location = / {
        return 404;
    }

    location ^~ /ws {
        if (\$request_method != GET) {
            return 405;
        }

        limit_req zone=ws burst=5 nodelay;
        limit_conn conn_limit_per_ip 20;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://$LH:$NETHERMIND_WS_PORT/;
        proxy_read_timeout 60s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
    }

    location ^~ /rpc {
        if (\$request_method != POST) {
            return 405;
        }

        limit_req zone=api burst=10 nodelay;
        limit_conn conn_limit_per_ip 30;

        proxy_cache rpc_read_cache;
        proxy_cache_methods POST;
        proxy_cache_key "\$scheme://\$host\$request_uri|\$request_body";
        proxy_cache_lock on;
        proxy_cache_lock_age 5s;
        proxy_cache_lock_timeout 10s;
        proxy_cache_valid 200 2s;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_bypass 0;
        proxy_no_cache \$rpc_cache_bypass;

        add_header X-RPC-Cache \$upstream_cache_status always;
        add_header X-RPC-Cache-Bypass \$rpc_cache_bypass always;

        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://$LH:$NETHERMIND_HTTP_PORT/;
        proxy_read_timeout 30s;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
    }

    location / {
        return 403;
    }
}
EOF
}

render_caddy_site_config() {
    local server_name="$1"
    local config_path="$2"
    local tls_mode="${3:-auto}" # auto|manual
    local cert_path="${4:-}"
    local key_path="${5:-}"

    local tls_block
    local redirect_block=""
    local site_address="https://$server_name"
    local enable_rate_limit="${CADDY_ENABLE_RATE_LIMIT:-true}"
    local rate_limit_global=""
    local rate_limit_ws=""
    local rate_limit_rpc=""
    local strict_sni_line="        strict_sni_host"

    if [[ "${CI_E2E:-}" == "true" ]]; then
        enable_rate_limit="false"
        site_address=":80"
        tls_block=""
        strict_sni_line=""
    fi

    if [[ "${CI_E2E:-}" != "true" ]]; then
        redirect_block=$'http://'"$server_name"$' {\n    redir https://'"$server_name"$'{uri} permanent\n}\n'
    fi

    if [[ "${CI_E2E:-}" != "true" ]] && [[ "$tls_mode" == "manual" ]]; then
        tls_block="    tls $cert_path $key_path"
    elif [[ "${CI_E2E:-}" != "true" ]]; then
        tls_block=$'    tls {\n        dns cloudflare {\n            env CLOUDFLARE_API_TOKEN\n        }\n    }'
    fi

    if [[ "$enable_rate_limit" == "true" ]]; then
        rate_limit_global=$'    rate_limit {\n        zone api {\n            key {remote_host}\n            events 50\n            window 1m\n        }\n        zone ws {\n            key {remote_host}\n            events 20\n            window 1m\n        }\n        zone general {\n            key {remote_host}\n            events 100\n            window 1m\n        }\n    }\n'
        rate_limit_ws='        rate_limit zone ws'
        rate_limit_rpc='        rate_limit zone api'
    fi

    cat > "$config_path" << EOF
{
    auto_https off
    servers {
        protocols h1 h2 h3
$strict_sni_line
        max_header_size 1048576
    }
    admin off
}

$redirect_block

$site_address {
$tls_block

    @spam path_regexp spam (?i).*(\\.($PROXY_SPAM_EXTENSIONS_REGEX))(?:\$|/)
    respond @spam "Access Denied" 403

    @attack path_regexp attack ^/($PROXY_ATTACK_PATHS_REGEX)(?:\$|/)
    respond @attack "Access Denied" 403

    @ws_path path /ws*
    route @ws_path {
$rate_limit_ws
        @ws_get method GET
        reverse_proxy @ws_get $LH:$NETHERMIND_WS_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
        respond "Method Not Allowed" 405
    }

    @rpc_path path /rpc*
    route @rpc_path {
$rate_limit_rpc
        @rpc_post method POST
        reverse_proxy @rpc_post $LH:$NETHERMIND_HTTP_PORT {
            header_up Host {host}
            header_up X-Real-IP {remote}
            header_up X-Forwarded-For {remote}
            header_up X-Forwarded-Proto {scheme}
        }
        respond "Method Not Allowed" 405
    }

    @root path /
    respond @root "Not Found" 404
    respond "Access Denied" 403

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Frame-Options "DENY"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss: https:; font-src 'self' data:; object-src 'none'; media-src 'self'; frame-src 'none';"
        Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(self), sync-xhr=()"
    }

$rate_limit_global
    request_body {
        max_size 10MB
    }

    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
        }
        format json
        level INFO
    }
}
EOF
}
