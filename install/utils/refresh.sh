#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'


# Service Refresh Script
# Restarts all Ethereum client services
# Usage: ./refresh.sh
# Note: Restarts services without stopping them first
source ../../lib/common_functions.sh

log_info "Refreshing all Ethereum services..."
restart_all_services

log_info "Running system stats..."
./"$HOME"/eth2-quickstart/extra_utils/stats.sh
