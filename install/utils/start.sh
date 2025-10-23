#!/bin/bash

# Service Start Script
# Starts all Ethereum client systemd services
# Usage: ./start.sh
# Note: Requires services to be installed and configured

set -Eeuo pipefail

# Source common functions
source ../../lib/common_functions.sh

log_info "Ethereum Client Service Manager"
echo

# Check if running as correct user
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    log_info "Please run as the non-root user (usually 'eth')"
    exit 1
fi

# Show current service status
log_info "Current service status:"
check_all_services_status
echo

# Start all services
log_info "Starting all Ethereum client services..."
if start_all_services; then
    log_info "✓ All services started successfully"
    
    # Wait a moment for services to initialize
    log_info "Waiting for services to initialize..."
    sleep 5
    
    # Show updated status
    log_info "Updated service status:"
    check_all_services_status
    echo
    
    # Run health checks
    log_info "Running health checks..."
    if run_comprehensive_health_check; then
        log_info "✓ All health checks passed - services are healthy"
    else
        log_warn "⚠ Some health checks failed - services may still be starting"
        log_info "This is normal during initial sync - check again in a few minutes"
    fi
else
    log_error "✗ Failed to start some services"
    log_info "Check service logs for details:"
    log_info "  - journalctl -fu eth1"
    log_info "  - journalctl -fu cl"
    log_info "  - journalctl -fu validator"
    log_info "  - journalctl -fu mev"
fi

echo
log_info "Service management complete!"
