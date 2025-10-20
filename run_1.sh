#!/bin/bash
set -Eeuo pipefail
IFS=$'\n\t'

# System Setup Script - Phase 1
# Initial system hardening and user setup

source ./exports.sh
source ./lib/utils.sh
source ./lib/common_functions.sh
require_root

log_info "Starting system setup - Phase 1..."

# Check system compatibility first
if ! check_system_compatibility; then
    log_error "System compatibility check failed"
    exit 1
fi

# Update system packages
log_info "Updating system packages..."
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y

# Setup SSH with safe defaults
log_info "Configuring SSH with safe defaults..."
if [ -f /etc/ssh/sshd_config ]; then
    log_info "Backing up existing SSH config"
    mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bkup
fi

if ! cp ./sshd_config /etc/ssh/sshd_config; then
    log_error "Failed to copy SSH config"
    exit 1
fi

# Copy it back for review / commit 
cp /etc/ssh/sshd_config ./

# Basic hardening
log_info "Setting up basic system hardening..."

# Install and configure fail2ban
log_info "Installing and configuring fail2ban..."
install_dependencies fail2ban
echo "
## block hosts trying to abuse our server as a forward proxy
[nginx-proxy]
enabled = true
port    = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400

[sshd]
enabled = true
port = $YourSSHPortNumber
filter = sshd
logpath = /var/log/auth.log
maxretry = $maxretry" >> /etc/fail2ban/jail.local
systemctl restart fail2ban

## Add eth user
id -u "$LOGIN_UNAME" >/dev/null 2>&1 || useradd -m -d /home/"$LOGIN_UNAME" -s /bin/bash "$LOGIN_UNAME"

# Copy over authorized keys to created user to allow ssh
mkdir -p /home/"$LOGIN_UNAME"/.ssh
cp ~/.ssh/authorized_keys /home/"$LOGIN_UNAME"/.ssh/ || true
chown -R "$LOGIN_UNAME":"$LOGIN_UNAME" /home/"$LOGIN_UNAME"/.ssh
chmod 700 /home/"$LOGIN_UNAME"/.ssh
chmod 600 /home/"$LOGIN_UNAME"/.ssh/authorized_keys
usermod -aG sudo "$LOGIN_UNAME"

cp -r ../"$REPO_NAME" /home/"$LOGIN_UNAME"/ || true
chmod -R +x /home/"$LOGIN_UNAME"/"$REPO_NAME" || true
chown -R "$LOGIN_UNAME":"$LOGIN_UNAME" /home/"$LOGIN_UNAME"/"$REPO_NAME" || true

# Whitelist and only allow certain users
# AllowUsers root
# AllowUsers $LOGIN_UNAME
chmod +x ./install/security/firewall.sh
./install/security/firewall.sh

# confirm time date sync
apt install chrony -y
timedatectl set-ntp on

# Disable shared memory
append_once /etc/fstab $'tmpfs\t/run/shm\ttmpfs\tro,noexec,nosuid\t0 0'
echo "Disabled shared memory"

# Secure file permissions
log_info "Securing file permissions..."
secure_config_files

# Apply network security
log_info "Applying network security configurations..."
apply_network_security

# Setup security monitoring
log_info "Setting up security monitoring..."
setup_security_monitoring

# Setup intrusion detection
log_info "Setting up intrusion detection..."
setup_intrusion_detection

echo "Begin network settings output:"

ss -tulpn
sshd -t
ufw status

echo "Manual action required!"
echo "1. Please check the settings above"

read -r -n 1 -p "Press enter to continue when done ^:" || true

echo "2. Please run the following cmds now in another shell and add the line to the file that pops up to enable $LOGIN_UNAME no-prompt sudo to help run the second stage"
echo "ssh root@$(curl -s v4.ident.me) "
echo "sudo visudo"
echo "Add this to the end of the file:"
echo "$LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL "

read -r -n 1 -p "Press enter to continue when done ^:" || true

echo "3. Set a password for your new user when prompted"
passwd "$LOGIN_UNAME"

# Security validation will be run at the end of run_2.sh

echo "Done. Run 'sudo reboot' for all changes to take effect"
echo "Re-login via ssh $LOGIN_UNAME@$(curl -s v4.ident.me) after and run './run_2.sh'"
