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
# shellcheck source=../install/web/caddy_helpers.sh
source "$PROJECT_ROOT/install/web/caddy_helpers.sh"

CADDYFILE="/tmp/caddy_validate_$$.Caddyfile"
export CI_E2E=true

create_caddy_config_auto_https "${SERVER_NAME:-rpc.sharedtools.org}" "$CADDYFILE"

trap 'rm -f "$CADDYFILE"' EXIT

validate_with_caddy() {
    # Caddy requires --adapter caddyfile for Caddyfile format (otherwise parses as JSON)
    if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        echo "Validating with sudo caddy validate..."
        if sudo caddy validate --config "$CADDYFILE" --adapter caddyfile; then
            return 0
        fi
    fi

    echo "Validating with caddy validate..."
    caddy validate --config "$CADDYFILE" --adapter caddyfile
}

validate_with_docker() {
    echo "Validating with docker run caddy..."
    docker run --rm -v "$CADDYFILE:/etc/caddy/Caddyfile:ro" caddy:2 \
        caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
}

if command -v caddy &>/dev/null && validate_with_caddy; then
    echo "✓ Caddy config is valid"
    exit 0
fi

if command -v docker &>/dev/null && validate_with_docker; then
    echo "✓ Caddy config is valid"
    exit 0
fi

echo "✗ Caddy config validation failed"
if ! command -v caddy &>/dev/null && ! command -v docker &>/dev/null; then
    echo "Error: caddy or docker required for validation"
    echo "Generated config at: $CADDYFILE"
fi
exit 1
