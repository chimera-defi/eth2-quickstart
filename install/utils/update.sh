#!/bin/bash

# System Update Script
# Updates the Ethereum software stack and shows version changes
# Usage: ./update.sh
# Note: Stops services before update, restarts after completion

# Source common functions and configuration
# shellcheck source=../../exports.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../exports.sh"
# shellcheck source=../../lib/common_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common_functions.sh"
get_script_directories

log_info "Starting software stack update..."

# Capture current versions before update
log_info "Capturing current versions..."
OLD_GETH_VERSION=""
OLD_MEV_VERSION=""
OLD_NGINX_VERSION=""

if command_exists geth; then
    OLD_GETH_VERSION=$(geth version 2>/dev/null | head -n1 || echo "unknown")
fi
if command_exists mev-boost; then
    OLD_MEV_VERSION=$(mev-boost -version 2>/dev/null || echo "unknown")
elif [[ -f "$HOME/mev-boost/mev-boost" ]]; then
    OLD_MEV_VERSION=$("$HOME/mev-boost/mev-boost" -version 2>/dev/null || echo "unknown")
fi
if command_exists nginx; then
    OLD_NGINX_VERSION=$(nginx -v 2>&1 || echo "unknown")
fi

# Stop services before update (except validators to avoid downtime)
log_info "Stopping services for update..."
sudo systemctl stop eth1 cl mev nginx 2>/dev/null || true
# Note: Validators are not stopped to avoid downtime during upgrades

# Regular Linux housekeeping
log_info "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get autoremove -y

# Geth - upgrade via apt if installed that way
log_info "Updating Geth..."
sudo apt-get upgrade geth -y 2>/dev/null || log_info "Geth not installed via apt, skipping"

# MEV Boost - reinstall to get latest version
log_info "Updating MEV Boost..."
MEV_BOOST_SCRIPT="$PROJECT_ROOT/install/mev/install_mev_boost.sh"
if [[ -f "$MEV_BOOST_SCRIPT" ]]; then
    if ! bash "$MEV_BOOST_SCRIPT"; then
        log_warn "MEV Boost update had issues, continuing..."
    fi
else
    log_warn "MEV Boost install script not found at $MEV_BOOST_SCRIPT"
fi

# Start all services
log_info "Starting all services..."
sudo systemctl start eth1 cl mev nginx 2>/dev/null || true
# Validators are already running and will be restarted by install scripts if needed

# Output version comparison report
echo ""
echo "=========================================="
echo "         VERSION UPGRADE REPORT"
echo "=========================================="

# Get new versions
NEW_GETH_VERSION=""
NEW_MEV_VERSION=""
NEW_NGINX_VERSION=""

if command_exists geth; then
    NEW_GETH_VERSION=$(geth version 2>/dev/null | head -n1 || echo "unknown")
fi
if command_exists mev-boost; then
    NEW_MEV_VERSION=$(mev-boost -version 2>/dev/null || echo "unknown")
elif [[ -f "$HOME/mev-boost/mev-boost" ]]; then
    NEW_MEV_VERSION=$("$HOME/mev-boost/mev-boost" -version 2>/dev/null || echo "unknown")
fi
if command_exists nginx; then
    NEW_NGINX_VERSION=$(nginx -v 2>&1 || echo "unknown")
fi

echo ""
echo "Geth:"
echo "  Before: $OLD_GETH_VERSION"
echo "  After:  $NEW_GETH_VERSION"
echo ""
echo "MEV-Boost:"
echo "  Before: $OLD_MEV_VERSION"
echo "  After:  $NEW_MEV_VERSION"
echo ""
echo "Nginx:"
echo "  Before: $OLD_NGINX_VERSION"
echo "  After:  $NEW_NGINX_VERSION"
echo ""
echo "=========================================="
echo "Update completed: $(date)"
echo "=========================================="

log_info "Software update completed successfully!"
