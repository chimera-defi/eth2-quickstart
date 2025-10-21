#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 2
# This script should be run as the non-root user
# It will install:
# 1. Geth
# 2. Prysm
# 3. Flashbots mev boost builder
# 4. Nginx without SSL, exposing the geth RPC route. 
#    (You can run `service nginx stop` to disable this)
# Note: External ETH1 RPC calls expect SSL so you will have to 
#       manually run: `sudo su`
#       Followed by: 
#       `./install/ssl/install_acme_ssl.sh`  or 
#       `./install_certbot_ssl.sh` 
#       to get SSL certs and configure NGINX properly

source ./exports.sh
source ./lib/common_functions.sh

log_info "Starting system setup - Phase 2..."

# Check system compatibility first
if ! check_system_compatibility; then
    log_error "System compatibility check failed"
    exit 1
fi
log_info "This script will install Ethereum clients and services"

# Start syncing prysm and geth
# Geth takes a day
# prysm takes 3-5. few hrs w/ the checkpt
# Slightly faster via the screen cmds

# You may want to run a different cmd via screen for more flexibility and faster sync
# screen -d -m  geth --syncmode snap --http --http.addr 127.0.0.1 --cache=16384 --ipcdisable --maxpeers 500 --lightkdf --v5disc
# cd prysm
# screen -d -m ./prysm.sh beacon-chain --p2p-host-ip=$(curl -s v4.ident.me) --config-file=./prysm_conf_beacon_sync.yaml
#  ./prysm.sh beacon-chain --checkpoint-block=$PWD/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/genesis.ssz --config-file=$PWD/prysm_beacon_conf.yaml --p2p-host-ip=88.99.65.230
# Install all dependencies centrally
log_info "Installing all system dependencies..."
if ! ./install/utils/install_dependencies.sh; then
    log_error "Failed to install dependencies"
    exit 1
fi

# Client selection and installation
log_info "Starting client selection process..."
log_info "You can choose your clients interactively or use the default setup"

# Ask user if they want to use interactive selection
echo
echo "Would you like to:"
echo "1. Use interactive client selection (recommended)"
echo "2. Use default setup (Geth + Prysm + MEV Boost)"
echo
read -r -p "Select option (1/2): " client_choice
if ! validate_menu_choice "$client_choice" 2; then
    log_error "Invalid choice. Please select 1 or 2."
    exit 1
fi

case "$client_choice" in
    1)
        log_info "Starting interactive client selection..."
        ./install/utils/select_clients.sh
        log_info "Please run the recommended install scripts from the client selection tool"
        log_info "Example: ./install/execution/install_geth.sh && ./install/consensus/install_prysm.sh"
        ;;
    2)
        log_info "Installing default clients (Geth + Prysm + MEV Boost)..."
        
        log_info "Installing Geth..."
        if ! ./install/execution/install_geth.sh; then
            log_error "Failed to install Geth"
            exit 1
        fi

        log_info "Installing Prysm..."
        if ! ./install/consensus/install_prysm.sh; then
            log_error "Failed to install Prysm"
            exit 1
        fi

        log_info "Installing Flashbots MEV Boost..."
        if ! ./install/mev/install_mev_boost.sh; then
            log_error "Failed to install Flashbots MEV Boost"
            exit 1
        fi

        log_info "All default Ethereum clients installed successfully!"
        log_info "Installed: Geth, Prysm, Flashbots MEV Boost"
        ;;
    *)
        log_error "Invalid selection. Using default setup..."
        log_info "Installing default clients (Geth + Prysm + MEV Boost)..."
        
        log_info "Installing Geth..."
        if ! ./install/execution/install_geth.sh; then
            log_error "Failed to install Geth"
            exit 1
        fi

        log_info "Installing Prysm..."
        if ! ./install/consensus/install_prysm.sh; then
            log_error "Failed to install Prysm"
            exit 1
        fi

        log_info "Installing Flashbots MEV Boost..."
        if ! ./install/mev/install_mev_boost.sh; then
            log_error "Failed to install Flashbots MEV Boost"
            exit 1
        fi

        log_info "All default Ethereum clients installed successfully!"
        log_info "Installed: Geth, Prysm, Flashbots MEV Boost"
        ;;
esac

# Note: Security hardening was already applied in run_1.sh
# This includes: secure_config_files, apply_network_security, 
# setup_security_monitoring, and setup_intrusion_detection

# Display next steps
cat << EOF

=== Next Steps ===

To expose your own uncensored geth RPC proxy for use, install nginx with SSL:

1. Switch to super user: sudo su
2. Run one of the following SSL setup commands:
   - ./install/ssl/install_acme_ssl.sh (Preferred - uses acme.sh)
   - ./install/ssl/install_ssl_certbot.sh (uses certbot with manual DNS verification)

If you are new to NGINX, strongly recommend running only './install/web/install_nginx.sh' first 
and confirming it works without SSL, locally, then remotely via your domain name.

Next step is to start syncing via:
- sudo systemctl start eth1
- Or try: ./install/utils/start.sh

=== Security Features Enabled ===
- File integrity monitoring (AIDE) - runs daily at 2 AM
- Security monitoring - runs every 15 minutes
- Network security restrictions applied
- Configuration files secured with proper permissions
- Firewall rules configured for all client ports

To verify security setup, run: ./test_security_fixes.sh

=== Running Security Validation ===
log_info "Running security validation..."
if [[ -f "docs/validate_security_safe.sh" && -x "docs/validate_security_safe.sh" ]]; then
    log_info "Running code quality validation..."
    if ./docs/validate_security_safe.sh; then
        log_info "✓ Security code validation passed"
    else
        log_warn "⚠ Security code validation had issues - check output above"
    fi
else
    log_warn "Security validation script not found"
fi

if [[ -f "docs/server_security_validation.sh" && -x "docs/server_security_validation.sh" ]]; then
    log_info "Running server security validation..."
    if ./docs/server_security_validation.sh; then
        log_info "✓ Server security validation passed"
    else
        log_warn "⚠ Server security validation had issues - check output above"
    fi
else
    log_warn "Server security validation script not found"
fi

log_info "Security validation completed. Check the output above for any issues."

EOF
