#!/bin/bash

# System Statistics Script
# Displays comprehensive system and client statistics
# Usage: ./stats.sh
# Shows: Error logs, client versions, service status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/lib/common_functions.sh"

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
if [[ -x "$HOME/prysm/prysm.sh" ]]; then
    "$HOME/prysm/prysm.sh" beacon-chain -version
    "$HOME/prysm/prysm.sh" validator -version
fi
if command -v geth >/dev/null 2>&1; then
    geth version
fi
echo "End version output --"
echo ''

echo "=== Service Status ==="
show_service_status
