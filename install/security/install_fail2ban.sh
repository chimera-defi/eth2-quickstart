#!/bin/bash

# Fail2ban Installation and Configuration Script
# Part of Ethereum Node Setup - Security Section

# Source configuration files
source ../../exports.sh
source ../../lib/common_functions.sh

# Check if running as root
require_root

log_info "Installing and configuring fail2ban..."

# Install fail2ban
install_dependencies fail2ban

# Configure fail2ban with sane defaults
log_info "Configuring fail2ban jails..."

# Define variables with fallback defaults
SSH_PORT="${YourSSHPortNumber:-22}"
MAX_RETRY="${maxretry:-3}"

cat >> /etc/fail2ban/jail.local << EOF
[nginx-proxy]
enabled = true
port = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = $MAX_RETRY
bantime = 3600
findtime = 600
EOF

# Enable and start fail2ban service
enable_and_start_system_service fail2ban

log_info "✓ Fail2ban installation and configuration complete"