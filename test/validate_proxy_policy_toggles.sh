#!/bin/bash
# Validates feature toggles in shared Nginx/Caddy proxy policy rendering.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

tmp_nginx="$(mktemp)"
tmp_nginx_policy="$(mktemp)"
tmp_caddy="$(mktemp)"
trap 'rm -f "$tmp_nginx" "$tmp_nginx_policy" "$tmp_caddy"' EXIT

assert_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "✓ $label"
    else
        echo "✗ Missing: $label"
        echo "  pattern: $pattern"
        echo "  file: $file"
        exit 1
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Eq "$pattern" "$file"; then
        echo "✗ Unexpected: $label"
        echo "  pattern: $pattern"
        echo "  file: $file"
        exit 1
    else
        echo "✓ $label"
    fi
}

render_case() {
    local nginx_out="$1"
    local nginx_policy_out="$2"
    local caddy_out="$3"
    shift 3

    local case_overrides=""
    local kv
    for kv in "$@"; do
        case_overrides+="$kv"$'\n'
    done

    # shellcheck disable=SC2016
    env CASE_OVERRIDES="$case_overrides" PROJECT_ROOT="$PROJECT_ROOT" NGINX_OUT="$nginx_out" NGINX_POLICY_OUT="$nginx_policy_out" CADDY_OUT="$caddy_out" bash -c '
set -Eeuo pipefail
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
while IFS= read -r kv; do
    [[ -z "$kv" ]] && continue
    export "$kv"
done <<< "$CASE_OVERRIDES"
source "$PROJECT_ROOT/lib/common_functions.sh"
source "$PROJECT_ROOT/install/web/nginx_helpers.sh"
source "$PROJECT_ROOT/install/web/caddy_helpers.sh"
export CI_E2E=true
create_nginx_config "${SERVER_NAME:-rpc.sharedtools.org}" "$NGINX_OUT" "false"
render_nginx_http_policy_file "$NGINX_POLICY_OUT"
create_caddy_config_auto_https "${SERVER_NAME:-rpc.sharedtools.org}" "$CADDY_OUT"
'
}

echo "Case 1: metrics + trusted proxy toggles"
render_case "$tmp_nginx" "$tmp_nginx_policy" "$tmp_caddy" \
    EDGE_ENABLE_METRICS=true \
    EDGE_METRICS_PATH=/metrics \
    EDGE_TRUSTED_PROXIES='173.245.48.0/20,103.21.244.0/22'

assert_contains "$tmp_nginx" 'location = /metrics' "nginx metrics location"
assert_contains "$tmp_nginx" 'set_real_ip_from 173\.245\.48\.0/20;' "nginx trusted proxy #1"
assert_contains "$tmp_nginx" 'set_real_ip_from 103\.21\.244\.0/22;' "nginx trusted proxy #2"
assert_contains "$tmp_caddy" 'metrics /metrics' "caddy local metrics endpoint"
assert_contains "$tmp_caddy" 'trusted_proxies static 173\.245\.48\.0/20 103\.21\.244\.0/22' "caddy trusted proxies"

echo "Case 2: DNS resolver + mixed upstreams"
render_case "$tmp_nginx" "$tmp_nginx_policy" "$tmp_caddy" \
    EDGE_DNS_RESOLVER='1.1.1.1 8.8.8.8' \
    EDGE_RPC_UPSTREAMS='rpc-a.internal:8545,10.0.0.12:8545' \
    EDGE_WS_UPSTREAMS='ws-a.internal:8546,10.0.0.12:8546'

assert_contains "$tmp_nginx_policy" 'resolver 1\.1\.1\.1 8\.8\.8\.8 valid=30s ipv6=off;' "nginx resolver directive"
assert_contains "$tmp_nginx" 'server rpc-a\.internal:8545 resolve max_fails=3 fail_timeout=30s;' "nginx rpc hostname resolve"
assert_contains "$tmp_nginx" 'server 10\.0\.0\.12:8545 max_fails=3 fail_timeout=30s;' "nginx rpc ip upstream"
assert_contains "$tmp_caddy" 'reverse_proxy @rpc_post rpc-a\.internal:8545 10\.0\.0\.12:8545' "caddy rpc upstream fanout"

echo "Case 3: compression toggle off"
render_case "$tmp_nginx" "$tmp_nginx_policy" "$tmp_caddy" EDGE_ENABLE_COMPRESSION=false

assert_not_contains "$tmp_nginx_policy" '^gzip on;' "nginx gzip disabled"
assert_not_contains "$tmp_caddy" 'encode zstd gzip' "caddy encode disabled"

echo "✓ Shared proxy policy toggle rendering looks consistent"
