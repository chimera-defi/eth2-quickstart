#!/bin/bash


# Optional Tools Installation Script
# Installs useful network monitoring and system utilities
# https://askubuntu.com/questions/257263/how-to-display-network-traffic-in-the-terminal

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting optional tools installation..."

# Dependencies are installed centrally via install_dependencies.sh
log_info "Network monitoring tools are available..."

log_info "Optional tools installation completed!"
log_info "Installed tools:"
log_info "- bmon: Bandwidth monitoring"
log_info "- slurm: Network traffic monitor"
log_info "- tcptrack: TCP connection tracker"
log_info ""
log_info "Usage examples:"
log_info "- bmon: Monitor bandwidth usage"
log_info "- slurm: Monitor network traffic by interface"
log_info "- tcptrack: Track TCP connections in real-time"
