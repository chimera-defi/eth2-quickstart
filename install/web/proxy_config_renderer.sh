#!/bin/bash

# Shared proxy configuration renderer for Nginx and Caddy.
# This file is the single source of truth for RPC routing, spam blocking,
# headers, and request-shape hardening shared between both servers.

if [[ -n "${ETH2QS_PROXY_CONFIG_RENDERER_LOADED:-}" ]]; then
    return 0
fi
ETH2QS_PROXY_CONFIG_RENDERER_LOADED=1

PROXY_RENDERER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_POLICY_CONFIG="$PROXY_RENDERER_DIR/../../config/edge_policy.env"
if [[ -f "$PROXY_POLICY_CONFIG" ]]; then
    # shellcheck source=../../config/edge_policy.env
    source "$PROXY_POLICY_CONFIG"
fi

: "${PROXY_RPC_READ_METHODS_REGEX:=eth_chainId|net_version|web3_clientVersion|eth_blockNumber|eth_getBlockByNumber|eth_getBlockByHash|eth_getTransactionByHash|eth_getTransactionReceipt|eth_getBalance|eth_getCode|eth_getStorageAt|eth_call|eth_estimateGas|eth_getLogs|eth_feeHistory|eth_gasPrice}"
: "${PROXY_RPC_WRITE_METHODS_REGEX:=eth_sendRawTransaction|eth_sendTransaction|personal_sendTransaction|engine_[[:alnum:]_]+|admin_[[:alnum:]_]+|miner_[[:alnum:]_]+|txpool_[[:alnum:]_]+|debug_[[:alnum:]_]+}"
: "${PROXY_SPAM_EXTENSIONS_REGEX:=m3u8|m3u|php|asp|aspx|jsp|cgi|pl|env|git|bak|ini|sql|sqlite|tar|gz|zip}"
: "${PROXY_ATTACK_PATHS_REGEX:=admin|wp-admin|wp-login|\\.env|config|cgi-bin|phpmyadmin|boaform|HNAP1|xmlrpc\\.php}"

readonly PROXY_RPC_READ_METHODS_REGEX
readonly PROXY_RPC_WRITE_METHODS_REGEX
readonly PROXY_SPAM_EXTENSIONS_REGEX
readonly PROXY_ATTACK_PATHS_REGEX

: "${EDGE_RPC_UPSTREAMS:=${LH}:${NETHERMIND_HTTP_PORT}}"
: "${EDGE_WS_UPSTREAMS:=${LH}:${NETHERMIND_WS_PORT}}"
: "${EDGE_LB_POLICY:=least_conn}"                 # least_conn|ip_hash
: "${EDGE_UPSTREAM_KEEPALIVE:=64}"
: "${EDGE_DNS_RESOLVER:=}"                        # e.g. "1.1.1.1 8.8.8.8"
: "${EDGE_TRUSTED_PROXIES:=}"                     # comma-separated CIDRs
: "${EDGE_ENABLE_METRICS:=false}"
: "${EDGE_METRICS_PATH:=/metrics}"
: "${EDGE_ENABLE_COMPRESSION:=true}"
: "${EDGE_RPC_CACHE_MIN_USES:=1}"
: "${CADDY_LB_POLICY:=least_conn}"                # random, random_choose, least_conn, round_robin, first, ip_hash, uri_hash, header, cookie
: "${CADDY_LB_RETRIES:=2}"
: "${CADDY_LB_TRY_DURATION:=5s}"
: "${CADDY_LB_TRY_INTERVAL:=250ms}"
: "${CADDY_FAIL_DURATION:=30s}"
: "${CADDY_MAX_FAILS:=3}"

readonly EDGE_RPC_UPSTREAMS
readonly EDGE_WS_UPSTREAMS
readonly EDGE_LB_POLICY
readonly EDGE_UPSTREAM_KEEPALIVE
readonly EDGE_DNS_RESOLVER
readonly EDGE_TRUSTED_PROXIES
readonly EDGE_ENABLE_METRICS
readonly EDGE_METRICS_PATH
readonly EDGE_ENABLE_COMPRESSION
readonly EDGE_RPC_CACHE_MIN_USES
readonly CADDY_LB_POLICY
readonly CADDY_LB_RETRIES
readonly CADDY_LB_TRY_DURATION
readonly CADDY_LB_TRY_INTERVAL
readonly CADDY_FAIL_DURATION
readonly CADDY_MAX_FAILS

trim_space() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

csv_to_space_list() {
    local csv="$1"
    local item
    local out=()
    IFS=',' read -r -a items <<< "$csv"
    for item in "${items[@]}"; do
        item="$(trim_space "$item")"
        [[ -n "$item" ]] && out+=("$item")
    done
    printf '%s ' "${out[@]}"
}

upstream_host_from_addr() {
    local addr="$1"
    local host="$addr"
    if [[ "$addr" =~ ^\[[^]]+\]:[0-9]+$ ]]; then
        host="${addr%%]:*}"
        host="${host#\[}"
    elif [[ "$addr" == *:* ]]; then
        host="${addr%:*}"
    fi
    printf '%s' "$host"
}

should_add_resolve_flag() {
    local addr="$1"
    local host
    host="$(upstream_host_from_addr "$addr")"
    [[ "$host" == *:* ]] && return 1
    [[ -n "$EDGE_DNS_RESOLVER" && ! "$host" =~ ^[0-9.]+$ && "$host" != "localhost" ]]
}

render_nginx_upstream_block() {
    local name="$1"
    local upstream_csv="$2"
    local lb_policy="$3"
    local policy_line=""
    local server_lines=""
    local addr

    case "$lb_policy" in
        ip_hash)
            policy_line='    ip_hash;'
            ;;
        *)
            policy_line='    least_conn;'
            ;;
    esac

    IFS=',' read -r -a upstreams <<< "$upstream_csv"
    for addr in "${upstreams[@]}"; do
        addr="$(trim_space "$addr")"
        [[ -z "$addr" ]] && continue
        if should_add_resolve_flag "$addr"; then
            server_lines+="    server $addr resolve max_fails=3 fail_timeout=30s;"$'\n'
        else
            server_lines+="    server $addr max_fails=3 fail_timeout=30s;"$'\n'
        fi
    done

    cat << EOF
upstream $name {
$policy_line
$server_lines    keepalive $EDGE_UPSTREAM_KEEPALIVE;
}
EOF
}

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

    if [[ -n "$EDGE_DNS_RESOLVER" ]]; then
        echo "resolver $EDGE_DNS_RESOLVER valid=30s ipv6=off;" >> "$output_path"
    fi

    if [[ "$EDGE_ENABLE_COMPRESSION" == "true" ]]; then
        cat >> "$output_path" << 'EOF'

# Response compression
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 5;
gzip_min_length 1024;
gzip_types application/json application/javascript text/css text/plain application/xml text/xml;
EOF
    fi

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
    local redirect_block=""
    local listen_block=""
    local tls_block=""
    local header_block=""
    local trusted_proxy_block=""
    local metrics_location_block=""
    local upstream_blocks=""

    if [[ "$use_ssl" == "true" ]]; then
        redirect_block=$'# HTTP to HTTPS redirect\nserver {\n    listen 80;\n    listen [::]:80;\n    server_name '"$server_name"$';\n    return 301 https://\\$server_name\\$request_uri;\n}\n\n'
        listen_block=$'    listen 443 ssl http2;\n    listen [::]:443 ssl http2;'
        tls_block=$'    ssl_certificate '"$cert_path"$';\n    ssl_certificate_key '"$key_path"$';\n    ssl_protocols TLSv1.2 TLSv1.3;\n    ssl_ciphers '\''ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256'\'';\n    ssl_prefer_server_ciphers off;\n    ssl_session_cache shared:SSL:10m;\n    ssl_session_timeout 10m;\n    ssl_session_tickets off;\n    ssl_stapling on;\n    ssl_stapling_verify on;'
        header_block=$'    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;\n    add_header X-Frame-Options "DENY" always;\n    add_header X-Content-Type-Options "nosniff" always;\n    add_header X-XSS-Protection "1; mode=block" always;\n    add_header Referrer-Policy "strict-origin-when-cross-origin" always;\n    add_header Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\''; style-src '\''self'\'' '\''unsafe-inline'\''; img-src '\''self'\'' data: https:; connect-src '\''self'\'' wss: https:; font-src '\''self'\'' data:; object-src '\''none'\''; media-src '\''self'\''; frame-src '\''none'\'';" always;\n    add_header Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), speaker=(), vibrate=(), fullscreen=(self), sync-xhr=()" always;'
    else
        listen_block=$'    listen 80;\n    listen [::]:80;'
        header_block=$'    add_header X-Frame-Options "DENY" always;\n    add_header X-Content-Type-Options "nosniff" always;\n    add_header X-XSS-Protection "1; mode=block" always;\n    add_header Referrer-Policy "strict-origin-when-cross-origin" always;'
    fi

    if [[ -n "$EDGE_TRUSTED_PROXIES" ]]; then
        local proxy_cidr
        IFS=',' read -r -a proxy_cidrs <<< "$EDGE_TRUSTED_PROXIES"
        trusted_proxy_block=$'    real_ip_header X-Forwarded-For;\n    real_ip_recursive on;\n'
        for proxy_cidr in "${proxy_cidrs[@]}"; do
            proxy_cidr="$(trim_space "$proxy_cidr")"
            [[ -n "$proxy_cidr" ]] && trusted_proxy_block+="    set_real_ip_from $proxy_cidr;"$'\n'
        done
    fi

    if [[ "$EDGE_ENABLE_METRICS" == "true" ]]; then
        metrics_location_block=$'    location = '"$EDGE_METRICS_PATH"$' {\n        stub_status;\n        access_log off;\n        allow 127.0.0.1;\n        allow ::1;\n        deny all;\n    }\n'
    fi

    upstream_blocks="$(render_nginx_upstream_block "ws_backend" "$EDGE_WS_UPSTREAMS" "$EDGE_LB_POLICY")"$'\n'"$(render_nginx_upstream_block "rpc_backend" "$EDGE_RPC_UPSTREAMS" "$EDGE_LB_POLICY")"

    cat > "$config_path" << EOF
$redirect_block
$upstream_blocks

server {
$listen_block
    server_name $server_name;

$tls_block
$header_block
$trusted_proxy_block

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

$metrics_location_block
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
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 2;
        proxy_next_upstream_timeout 10s;
        proxy_socket_keepalive on;
        proxy_pass http://ws_backend/;
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
        proxy_cache_background_update on;
        proxy_cache_revalidate on;
        proxy_cache_min_uses $EDGE_RPC_CACHE_MIN_USES;
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
        proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
        proxy_next_upstream_tries 2;
        proxy_next_upstream_timeout 10s;
        proxy_socket_keepalive on;
        proxy_pass http://rpc_backend/;
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
    local trusted_proxies_line=""
    local metrics_global_line=""
    local metrics_site_line=""
    local encode_line=""
    local caddy_rpc_upstreams=""
    local caddy_ws_upstreams=""

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

    caddy_rpc_upstreams="$(trim_space "$(csv_to_space_list "$EDGE_RPC_UPSTREAMS")")"
    caddy_ws_upstreams="$(trim_space "$(csv_to_space_list "$EDGE_WS_UPSTREAMS")")"

    if [[ -z "$caddy_rpc_upstreams" ]]; then
        caddy_rpc_upstreams="$LH:$NETHERMIND_HTTP_PORT"
    fi
    if [[ -z "$caddy_ws_upstreams" ]]; then
        caddy_ws_upstreams="$LH:$NETHERMIND_WS_PORT"
    fi

    if [[ "$EDGE_ENABLE_COMPRESSION" == "true" ]]; then
        encode_line='    encode zstd gzip'
    fi

    if [[ "$EDGE_ENABLE_METRICS" == "true" ]]; then
        metrics_global_line='    metrics'
        metrics_site_line="    metrics $EDGE_METRICS_PATH"
    fi

    if [[ -n "$EDGE_TRUSTED_PROXIES" ]]; then
        local trusted_proxy_list
        trusted_proxy_list="$(trim_space "$(csv_to_space_list "$EDGE_TRUSTED_PROXIES")")"
        if [[ -n "$trusted_proxy_list" ]]; then
            trusted_proxies_line=$'        trusted_proxies static '"$trusted_proxy_list"$'\n        trusted_proxies_strict'
        fi
    fi

    cat > "$config_path" << EOF
{
    auto_https off
${metrics_global_line}
    servers {
        protocols h1 h2 h3
$strict_sni_line
        max_header_size 1048576
$trusted_proxies_line
    }
    admin off
}

$redirect_block

$site_address {
$tls_block

${encode_line}
${metrics_site_line}

    @spam path_regexp spam (?i).*(\\.($PROXY_SPAM_EXTENSIONS_REGEX))(?:\$|/)
    respond @spam "Access Denied" 403

    @attack path_regexp attack ^/($PROXY_ATTACK_PATHS_REGEX)(?:\$|/)
    respond @attack "Access Denied" 403

    @ws_path path /ws*
    route @ws_path {
$rate_limit_ws
        @ws_get method GET
        reverse_proxy @ws_get $caddy_ws_upstreams {
            lb_policy $CADDY_LB_POLICY
            lb_retries $CADDY_LB_RETRIES
            lb_try_duration $CADDY_LB_TRY_DURATION
            lb_try_interval $CADDY_LB_TRY_INTERVAL
            fail_duration $CADDY_FAIL_DURATION
            max_fails $CADDY_MAX_FAILS
            transport http {
                dial_timeout 5s
                response_header_timeout 30s
                keepalive 120s
            }
            header_up Host {host}
            header_up X-Real-IP {remote}
        }
        respond "Method Not Allowed" 405
    }

    @rpc_path path /rpc*
    route @rpc_path {
$rate_limit_rpc
        @rpc_post method POST
        reverse_proxy @rpc_post $caddy_rpc_upstreams {
            lb_policy $CADDY_LB_POLICY
            lb_retries $CADDY_LB_RETRIES
            lb_try_duration $CADDY_LB_TRY_DURATION
            lb_try_interval $CADDY_LB_TRY_INTERVAL
            fail_duration $CADDY_FAIL_DURATION
            max_fails $CADDY_MAX_FAILS
            transport http {
                dial_timeout 5s
                response_header_timeout 30s
                keepalive 120s
            }
            header_up Host {host}
            header_up X-Real-IP {remote}
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
