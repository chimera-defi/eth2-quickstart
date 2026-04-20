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
export CI_E2E="${CI_E2E:-true}"
create_nginx_config "${SERVER_NAME:-rpc.sharedtools.org}" "$NGINX_OUT" "false"
render_nginx_http_policy_file "$NGINX_POLICY_OUT"
create_caddy_config_auto_https "${SERVER_NAME:-rpc.sharedtools.org}" "$CADDY_OUT"
'
}

assert_render_fails() {
    local label="$1"
    shift
    if render_case "$tmp_nginx" "$tmp_nginx_policy" "$tmp_caddy" "$@"; then
        echo "✗ Unexpected success: $label"
        exit 1
    fi
    echo "✓ $label"
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
assert_not_contains "$tmp_nginx" 'gzip on;' "nginx gzip disabled in site config"
assert_not_contains "$tmp_caddy" 'encode zstd gzip' "caddy encode disabled"

echo "Case 4: strict mode should fail when required Caddy features are disabled"
assert_render_fails "rate-limit strict mode fails when rate limiting is disabled" \
    CADDY_ENABLE_RATE_LIMIT=false \
    CADDY_REQUIRE_RATE_LIMIT=true

assert_render_fails "dns-challenge strict mode fails when DNS challenge is disabled" \
    CADDY_ENABLE_DNS_CHALLENGE=false \
    CADDY_REQUIRE_DNS_CHALLENGE=true

echo "Case 5: shared anti-abuse knobs should render into both Nginx + Caddy"
render_case "$tmp_nginx" "$tmp_nginx_policy" "$tmp_caddy" \
    EDGE_RPC_RATE_LIMIT_RPM=61 \
    EDGE_WS_RATE_LIMIT_RPM=27 \
    EDGE_GENERAL_RATE_LIMIT_RPM=111 \
    EDGE_RPC_BURST=13 \
    EDGE_WS_BURST=7 \
    EDGE_RPC_CONN_LIMIT_PER_IP=41 \
    EDGE_WS_CONN_LIMIT_PER_IP=23 \
    CADDY_MODULE_LIST_CACHE='http.handlers.rate_limit' \
    CI_E2E=false \
    CADDY_ENABLE_RATE_LIMIT=true

# shellcheck disable=SC2016
assert_contains "$tmp_nginx_policy" 'limit_req_zone \$binary_remote_addr zone=api:10m rate=61r/m;' "nginx rpc rpm from shared knob"
# shellcheck disable=SC2016
assert_contains "$tmp_nginx_policy" 'limit_req_zone \$binary_remote_addr zone=ws:10m rate=27r/m;' "nginx ws rpm from shared knob"
# shellcheck disable=SC2016
assert_contains "$tmp_nginx_policy" 'limit_req_zone \$binary_remote_addr zone=general:10m rate=111r/m;' "nginx general rpm from shared knob"
assert_contains "$tmp_nginx" 'limit_req zone=ws burst=7 nodelay;' "nginx ws burst from shared knob"
assert_contains "$tmp_nginx" 'limit_req zone=api burst=13 nodelay;' "nginx rpc burst from shared knob"
assert_contains "$tmp_nginx" 'limit_conn conn_limit_per_ip 23;' "nginx ws conn limit from shared knob"
assert_contains "$tmp_nginx" 'limit_conn conn_limit_per_ip 41;' "nginx rpc conn limit from shared knob"
assert_contains "$tmp_caddy" 'events 61' "caddy rpc rpm from shared knob"
assert_contains "$tmp_caddy" 'events 27' "caddy ws rpm from shared knob"
assert_contains "$tmp_caddy" 'events 111' "caddy general rpm from shared knob"

echo "✓ Shared proxy policy toggle rendering looks consistent"
