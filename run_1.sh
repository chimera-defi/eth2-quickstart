#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 1
# Initial system hardening and user setup with sane defaults

source ./exports.sh
source ./lib/utils.sh
source ./lib/common_functions.sh

require_root

log_info "Starting system setup - Phase 1 (user=$LOGIN_UNAME, ssh_port=$YourSSHPortNumber, max_retry=$maxretry)..."

# System updates and basic checks
check_system_compatibility
apt update -y && apt upgrade -y && apt full-upgrade -y && apt autoremove -y || log_warn "Some packages could not be removed"

# SSH and fail2ban setup
[[ -f /etc/ssh/sshd_config ]] && mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bkup
cp ./sshd_config /etc/ssh/sshd_config
cp /etc/ssh/sshd_config ./ || log_warn "Could not copy SSH config back"

install_dependencies fail2ban
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
port = $YourSSHPortNumber
filter = sshd
logpath = /var/log/auth.log
maxretry = $maxretry
bantime = 3600
findtime = 600
EOF
systemctl restart fail2ban

# User setup and security hardening
USER_PASSWORD=$(generate_secure_password 16)
setup_secure_user "$LOGIN_UNAME" "$USER_PASSWORD"
configure_sudo_nopasswd "$LOGIN_UNAME"

# Firewall and system hardening
chmod +x ./install/security/firewall.sh && ./install/security/firewall.sh
append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'

# Apply comprehensive security configurations
secure_config_files && apply_network_security && setup_security_monitoring && setup_intrusion_detection

# Get server IP and display status
SERVER_IP=$(curl -s v4.ident.me 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")

echo "=== SYSTEM STATUS ==="
echo "Network: $(ss -tulpn | wc -l) active connections"
echo "SSH: $(sshd -t 2>&1 | grep -c 'OK' || echo '0') config checks passed"
echo "Firewall: $(ufw status | grep -c 'Status: active' || echo '0') active"
echo

# Manual verification step (from reference version)
echo "Manual action required!"
echo "1. Please check the settings above"
read -n 1 -p "Press enter to continue when done: " 

echo "2. Please run the following cmds now in another shell and add the line to the file that pops up to enable $LOGIN_UNAME no-prompt sudo to help run the second stage"
echo "ssh root@$SERVER_IP"
echo "sudo visudo"
echo "Add this to the end of the file:"
echo "$LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL"
read -n 1 -p "Press enter to continue when done: " 

echo "3. Set a password for your new user when prompted"
passwd $LOGIN_UNAME

# Generate handoff information
generate_handoff_info "$LOGIN_UNAME" "$USER_PASSWORD" "$SERVER_IP"

echo "Done. Run 'sudo reboot' for all changes to take effect"
echo "Re-login via ssh $LOGIN_UNAME@$SERVER_IP after and run './run_2.sh'"