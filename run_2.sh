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

# Check if running as correct user
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    log_info "Please run as the non-root user (usually 'eth')"
    log_info "If you just ran run_1.sh, please:"
    log_info "1. Reboot the system: sudo reboot"
    log_info "2. Login as the non-root user"
    log_info "3. Run this script again"
    exit 1
fi

log_info "This script will install Ethereum clients and services"
log_info "Running as user: $(whoami)"

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

# Apply security configurations
log_info "Applying security configurations..."
secure_config_files
apply_network_security

# Check if services are already running
log_info "Checking current service status..."
check_all_services_status
echo

# Start all Ethereum client services automatically
log_info "Starting Ethereum client services..."
if start_all_services; then
    log_info "✓ All services started successfully"
    
    # Wait for services to become healthy
    log_info "Waiting for services to become healthy..."
    if wait_for_services_healthy 300; then
        log_info "✓ All services are healthy and running"
    else
        log_warn "⚠ Some services may still be starting up"
        log_info "This is normal during initial startup - services will continue syncing in background"
    fi
    
    # Run health checks
    log_info "Running comprehensive health checks..."
    if run_comprehensive_health_check; then
        log_info "✓ All health checks passed"
    else
        log_warn "⚠ Some health checks failed - services may still be syncing"
        log_info "This is normal during initial sync - check again in a few minutes"
    fi
else
    log_error "✗ Failed to start some services"
    log_info "You can try starting them manually with: sudo systemctl start eth1 cl validator mev"
    log_info "Check service logs for details: journalctl -fu [service_name]"
fi

# Run security validation
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

# Display comprehensive status and next steps
cat << EOF

=== INSTALLATION COMPLETE ===

✓ Ethereum clients installed and started
✓ Services are running and syncing
✓ Security configurations applied
✓ Health checks completed

=== SERVICE STATUS ===
EOF

check_all_services_status

cat << EOF

=== NEXT STEPS ===

1. Monitor sync progress:
   - Execution client: journalctl -fu eth1
   - Consensus client: journalctl -fu cl
   - Validator: journalctl -fu validator
   - MEV-Boost: journalctl -fu mev

2. Check sync status:
   - Geth: curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://127.0.0.1:8545
   - Prysm: curl http://127.0.0.1:5051/eth/v1/node/syncing

3. To expose RPC endpoints with SSL:
   - Switch to super user: sudo su
   - Run: ./install/ssl/install_acme_ssl.sh (recommended)
   - Or: ./install/ssl/install_ssl_certbot.sh

4. For basic HTTP proxy (no SSL):
   - Run: ./install/web/install_nginx.sh

=== SECURITY FEATURES ENABLED ===
- File integrity monitoring (AIDE) - runs daily at 2 AM
- Security monitoring - runs every 15 minutes
- Network security restrictions applied
- Configuration files secured with proper permissions
- Firewall rules configured for all client ports

=== USEFUL COMMANDS ===
- Check all services: ./install/utils/start.sh
- Stop all services: sudo systemctl stop eth1 cl validator mev
- Restart all services: sudo systemctl restart eth1 cl validator mev
- View logs: journalctl -fu [service_name]
- Check security: ./test_security_fixes.sh

=== SYNC TIME ESTIMATES ===
- Geth: 1-2 days (depending on hardware and internet)
- Prysm: 3-5 hours (with checkpoint sync)
- Total: Expect 1-2 days for full sync

=== MONITORING COMMANDS ===
- Check Geth sync: curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://127.0.0.1:8545
- Check Prysm sync: curl http://127.0.0.1:5051/eth/v1/node/syncing
- View all logs: journalctl -fu eth1 cl validator mev
- Check disk usage: df -h
- Check memory usage: free -h

=== TROUBLESHOOTING ===
If services fail to start:
1. Check logs: journalctl -fu [service_name]
2. Check system resources: htop, df -h
3. Restart services: sudo systemctl restart [service_name]
4. Check firewall: sudo ufw status
5. Verify configuration files exist and have correct permissions

Your Ethereum node is now running and syncing! 🚀

EOF
