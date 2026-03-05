#!/bin/bash

# System Update Script
# Updates the Ethereum software stack and shows version changes
# Usage: ./update.sh
# Note: Stops core services before updating, restarts after completion

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/lib/common_functions.sh"
get_script_directories

set -euo pipefail

get_mev_boost_version() {
    if [[ -x "$HOME/mev-boost/mev-boost" ]]; then
        "$HOME/mev-boost/mev-boost" -version 2>/dev/null || echo "unknown"
    else
        echo "not-installed"
    fi
}

get_geth_version() {
    if command -v geth >/dev/null 2>&1; then
        geth version 2>/dev/null | head -n 1 || echo "unknown"
    else
        echo "not-installed"
    fi
}

get_prysm_version() {
    if [[ -x "$HOME/prysm/prysm.sh" ]]; then
        "$HOME/prysm/prysm.sh" validator --version 2>/dev/null | head -n 1 || echo "unknown"
    else
        echo "not-installed"
    fi
}

get_nginx_version() {
    if command -v nginx >/dev/null 2>&1; then
        nginx -v 2>&1 || echo "unknown"
    else
        echo "not-installed"
    fi
}

MEV_BOOST_VERSION_BEFORE=$(get_mev_boost_version)
GETH_VERSION_BEFORE=$(get_geth_version)
PRYSM_VERSION_BEFORE=$(get_prysm_version)
NGINX_VERSION_BEFORE=$(get_nginx_version)

log_info "Starting software stack update..."

# Stop services before update (except validators to avoid downtime)
log_info "Stopping services for update..."
stop_service_if_active "eth1"
stop_service_if_active "cl"
stop_service_if_active "mev"
stop_service_if_active "nginx"
stop_service_if_active "caddy"
# Note: Validators are not stopped to avoid downtime during upgrades

# regular linux housecleaning
log_info "Updating system packages..."
sudo apt-get update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# geth - upgrade before already shouldve upgraded it for us but here is cmd in case needed
log_info "Updating Geth..."
sudo apt upgrade geth -y 

# prysm
log_info "Restarting Prysm services..."
# Services will be restarted after MEV Boost update

# mev / flashbots
log_info "Updating MEV Boost..."
if [[ -x "$PROJECT_ROOT/install/mev/install_mev_boost.sh" ]]; then
    "$PROJECT_ROOT/install/mev/install_mev_boost.sh"
else
    log_warn "MEV-Boost installer not found: $PROJECT_ROOT/install/mev/install_mev_boost.sh"
fi

# Start all services (validators will restart automatically via enable_and_start_systemd_service)
log_info "Starting all services..."
start_service_if_installed "eth1"
start_service_if_installed "cl"
start_service_if_installed "mev"
if service_exists "nginx" && service_enabled "nginx"; then
    start_service_if_installed "nginx"
fi
if service_exists "caddy" && service_enabled "caddy"; then
    start_service_if_installed "caddy"
fi
# Validators are already running and will be restarted by install scripts if needed

MEV_BOOST_VERSION_AFTER=$(get_mev_boost_version)
GETH_VERSION_AFTER=$(get_geth_version)
PRYSM_VERSION_AFTER=$(get_prysm_version)
NGINX_VERSION_AFTER=$(get_nginx_version)

echo ""
echo "=========================================="
echo "      SOFTWARE UPDATE VERSION REPORT"
echo "=========================================="
echo "MEV-Boost:"
echo "  before: $MEV_BOOST_VERSION_BEFORE"
echo "  after:  $MEV_BOOST_VERSION_AFTER"
echo "Geth:"
echo "  before: $GETH_VERSION_BEFORE"
echo "  after:  $GETH_VERSION_AFTER"
echo "Prysm:"
echo "  before: $PRYSM_VERSION_BEFORE"
echo "  after:  $PRYSM_VERSION_AFTER"
echo "Nginx:"
echo "  before: $NGINX_VERSION_BEFORE"
echo "  after:  $NGINX_VERSION_AFTER"
echo "=========================================="
