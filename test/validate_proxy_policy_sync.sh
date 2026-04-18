#!/bin/bash
# Validates that Nginx and Caddy configs are rendered from shared proxy policy.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# shellcheck source=../exports.sh
source "$PROJECT_ROOT/exports.sh"
# shellcheck source=../lib/common_functions.sh
source "$PROJECT_ROOT/lib/common_functions.sh"
# shellcheck source=../install/web/nginx_helpers.sh
source "$PROJECT_ROOT/install/web/nginx_helpers.sh"
# shellcheck source=../install/web/caddy_helpers.sh
source "$PROJECT_ROOT/install/web/caddy_helpers.sh"

tmp_nginx="$(mktemp)"
tmp_caddy="$(mktemp)"
trap 'rm -f "$tmp_nginx" "$tmp_caddy"' EXIT

export CI_E2E=true

create_nginx_config "${SERVER_NAME:-rpc.sharedtools.org}" "$tmp_nginx" "false"
create_caddy_config_auto_https "${SERVER_NAME:-rpc.sharedtools.org}" "$tmp_caddy"

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

assert_contains "$tmp_nginx" 'location \^~ /rpc' "nginx rpc route"
assert_contains "$tmp_caddy" '@rpc_path path /rpc\*' "caddy rpc route"
assert_contains "$tmp_nginx" 'location \^~ /ws' "nginx ws route"
assert_contains "$tmp_caddy" '@ws_path path /ws\*' "caddy ws route"

assert_contains "$tmp_nginx" "if \\(\\\$request_method != POST\\)" "nginx rpc method restriction"
assert_contains "$tmp_caddy" '@rpc_post method POST' "caddy rpc method restriction"
assert_contains "$tmp_nginx" 'upstream rpc_backend' "nginx rpc upstream block"
assert_contains "$tmp_nginx" 'upstream ws_backend' "nginx ws upstream block"
assert_contains "$tmp_nginx" 'proxy_cache rpc_read_cache' "nginx rpc cache directive"
assert_contains "$tmp_nginx" 'proxy_cache_background_update on;' "nginx cache background update"
assert_contains "$tmp_nginx" 'proxy_cache_revalidate on;' "nginx cache revalidate"
assert_contains "$tmp_nginx" 'proxy_next_upstream error timeout http_500 http_502 http_503 http_504;' "nginx upstream retry policy"
assert_contains "$tmp_caddy" 'lb_policy least_conn' "caddy load balancing policy"
assert_contains "$tmp_caddy" 'lb_try_duration 5s' "caddy retry duration"
assert_contains "$tmp_caddy" 'encode zstd gzip' "caddy response compression"
assert_contains "$tmp_nginx" 'm3u8\|m3u\|php' "nginx spam path block list"
assert_contains "$tmp_caddy" 'm3u8\|m3u\|php' "caddy spam path block list"

echo "✓ Shared proxy policy rendering looks consistent"
