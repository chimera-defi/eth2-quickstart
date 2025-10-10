#!/bin/bash

# System Update Script
# Updates the software stack and shows version changes

source ./exports.sh
source ./lib/common_functions.sh

log_info "Starting system update..."

# Get current versions
log_info "Checking current software versions..."
export MEV_BOOST_VERSION
MEV_BOOST_VERSION=$(../mev-boost/mev-boost -version 2>/dev/null || echo "Not installed")
export GETH_VERSION
GETH_VERSION=$(geth version 2>/dev/null || echo "Not installed")
export PRYSM_VERSION
PRYSM_VERSION=$(../prysm/prysm.sh validator --version 2>/dev/null || echo "Not installed")
export NGINX_VERSION
NGINX_VERSION=$(nginx -v 2>&1 || echo "Not installed")

log_info "Current versions:"
log_info "MEV Boost: $MEV_BOOST_VERSION"
log_info "Geth: $GETH_VERSION"
log_info "Prysm: $PRYSM_VERSION"
log_info "Nginx: $NGINX_VERSION"

# Stop services before update
log_info "Stopping services for update..."
sudo systemctl stop eth1

# Update system packages
log_info "Updating system packages..."
sudo apt-get update
sudo apt upgrade -y
sudo apt dist-upgrade -y
sudo apt autoremove -y

# Update Geth
log_info "Updating Geth..."
sudo apt-get install ethereum -y
sudo apt upgrade geth -y
sudo systemctl start eth1

# Update Prysm
log_info "Updating Prysm services..."
sudo systemctl restart cl
sudo systemctl restart validator

# Update MEV Boost
log_info "Updating MEV Boost..."
rm -rf ./mev-boost
if [[ -f "./install_mev_boost.sh" ]]; then
    ./install_mev_boost.sh && sudo systemctl restart mev
else
    log_warn "MEV Boost install script not found, skipping"
fi

# Restart Nginx
log_info "Restarting Nginx..."
sudo service nginx restart

# Get new versions
log_info "Checking new software versions..."
NEW_MEV_BOOST_VERSION=$(../mev-boost/mev-boost -version 2>/dev/null || echo "Not installed")
NEW_GETH_VERSION=$(geth version 2>/dev/null || echo "Not installed")
NEW_PRYSM_VERSION=$(../prysm/prysm.sh validator --version 2>/dev/null || echo "Not installed")
NEW_NGINX_VERSION=$(nginx -v 2>&1 || echo "Not installed")

# Show version comparison
cat << EOF

=== Version Update Summary ===
Upgraded from:
- MEV Boost: $MEV_BOOST_VERSION
- Geth: $GETH_VERSION
- Prysm: $PRYSM_VERSION
- Nginx: $NGINX_VERSION

To:
- MEV Boost: $NEW_MEV_BOOST_VERSION
- Geth: $NEW_GETH_VERSION
- Prysm: $NEW_PRYSM_VERSION
- Nginx: $NEW_NGINX_VERSION

EOF

# Show disk space
log_info "Current disk space:"
df -hT

# Show system stats
log_info "System update completed!"
log_info "All services have been updated and restarted"
