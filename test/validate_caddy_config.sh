#!/bin/bash
# Validates the Caddy config that would be generated for CI_E2E
# Run from project root. Requires: caddy (or docker)
# Usage: ./test/validate_caddy_config.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# shellcheck source=../exports.sh
source "$PROJECT_ROOT/exports.sh"
# shellcheck source=../lib/common_functions.sh
source "$PROJECT_ROOT/lib/common_functions.sh"
# shellcheck source=../install/web/web_helpers_common.sh
source "$PROJECT_ROOT/install/web/web_helpers_common.sh"
# shellcheck source=../install/web/caddy_helpers.sh
source "$PROJECT_ROOT/install/web/caddy_helpers.sh"

CADDYFILE="/tmp/caddy_validate_$$.Caddyfile"
export CI_E2E=true

create_caddy_config_auto_https "${SERVER_NAME:-rpc.sharedtools.org}" "$CADDYFILE"

# Caddy requires --adapter caddyfile for Caddyfile format (otherwise parses as JSON)
if command -v caddy &>/dev/null; then
    echo "Validating with caddy validate..."
    if caddy validate --config "$CADDYFILE" --adapter caddyfile; then
        echo "✓ Caddy config is valid"
        rm -f "$CADDYFILE"
        exit 0
    else
        echo "✗ Caddy config validation failed"
        rm -f "$CADDYFILE"
        exit 1
    fi
elif command -v docker &>/dev/null; then
    echo "Validating with docker run caddy..."
    if docker run --rm -v "$CADDYFILE:/etc/caddy/Caddyfile:ro" caddy:2 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
        echo "✓ Caddy config is valid"
        rm -f "$CADDYFILE"
        exit 0
    else
        echo "✗ Caddy config validation failed"
        rm -f "$CADDYFILE"
        exit 1
    fi
else
    echo "Error: caddy or docker required for validation"
    echo "Generated config at: $CADDYFILE"
    exit 1
fi
