#!/bin/bash

# refreshes / restarts / potentially upgrades all our services
source ../../lib/common_functions.sh

log_info "Refreshing all Ethereum services..."
restart_all_services

log_info "Running system stats..."
./"$HOME"/eth2-quickstart/extra_utils/stats.sh
