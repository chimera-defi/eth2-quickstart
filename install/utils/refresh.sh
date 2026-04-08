#!/bin/bash

# Service Refresh Script
# Restarts Ethereum client services
# Usage: ./refresh.sh [--smart]
# Default: restarts the full stack without stopping first
# --smart: only executes allowlisted targeted restarts from repair preview

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/lib/common_functions.sh"

if [[ "${1:-}" == "--smart" ]]; then
    log_info "Running smart repair workflow..."
    REPAIR_SKIP_POST_STATS=true "$PROJECT_ROOT/install/utils/repair.sh" --apply --confirm
else
    log_info "Refreshing all Ethereum services..."
    restart_all_services
fi

log_info "Running system stats..."
"$PROJECT_ROOT/install/utils/stats.sh"
