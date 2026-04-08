#!/bin/bash

# System Statistics Script
# Displays comprehensive system and client statistics
# Usage: ./stats.sh
# Shows: Error logs, client versions, service status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/lib/common_functions.sh"

if [[ "${1:-}" == "--json" ]]; then
    exec python3 "$SCRIPT_DIR/stats_json.py"
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: ./install/utils/stats.sh [--json]"
    echo "  --json    Output machine-readable monitoring and triage data"
    exit 0
fi

print_version_output() {
    local label="$1"
    shift
    local output

    if output="$("$@" 2>/dev/null)"; then
        echo "$output"
        return 0
    fi

    echo "$label version: unavailable"
    return 1
}

find_prysm_binary() {
    local component="$1"
    local prysm_dist="${HOME}/prysm/dist"

    [[ -d "$prysm_dist" ]] || return 1

    find "$prysm_dist" -maxdepth 1 -type f -name "*${component}*" -perm -111 2>/dev/null | sort | tail -n 1
}

show_prysm_versions() {
    local beacon_binary validator_binary

    beacon_binary="$(find_prysm_binary "beacon-chain" || true)"
    validator_binary="$(find_prysm_binary "validator" || true)"

    if [[ -n "$beacon_binary" ]]; then
        print_version_output "Prysm beacon" "$beacon_binary" --version || true
    elif [[ -x "$HOME/prysm/prysm.sh" ]]; then
        echo "Prysm beacon version: unavailable (bootstrap script present, local binary not downloaded)"
    fi

    if [[ -n "$validator_binary" ]]; then
        print_version_output "Prysm validator" "$validator_binary" --version || true
    elif [[ -x "$HOME/prysm/prysm.sh" ]]; then
        echo "Prysm validator version: unavailable (bootstrap script present, local binary not downloaded)"
    fi
}

echo "=== Error Scan ==="
for service in "${ETH_ALL_SERVICES[@]}"; do
    if service_exists "$service"; then
        echo "-- $service --"
        journalctl -u "$service" -n 200 --no-pager 2>/dev/null | grep -i error || true
    fi
done
echo "End error scan output --"

echo "=== Time Till Duty Check ==="
journalctl -u validator -n 1000 --no-pager 2>/dev/null | grep timeTillDuty || true
echo ''

echo "=== Client Versions ==="
if [[ -x "$HOME/mev-boost/mev-boost" ]]; then
    "$HOME/mev-boost/mev-boost" -version
fi
show_prysm_versions
if command -v geth >/dev/null 2>&1; then
    geth version
fi
echo "End version output --"
echo ''

echo "=== Service Status ==="
show_service_status
