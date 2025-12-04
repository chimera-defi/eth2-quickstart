#!/bin/bash

# Service Refresh Script
# Restarts all Ethereum client services
# Usage: ./refresh.sh
# Note: Restarts services without stopping them first

# Source required files
# shellcheck source=../../exports.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../exports.sh"
# shellcheck source=../../lib/common_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common_functions.sh"
get_script_directories

log_info "Refreshing all Ethereum services..."
restart_all_services

log_info "Running system stats..."
STATS_SCRIPT="$PROJECT_ROOT/install/utils/stats.sh"
if [[ -f "$STATS_SCRIPT" ]]; then
    bash "$STATS_SCRIPT"
else
    log_warn "Stats script not found at $STATS_SCRIPT"
fi
