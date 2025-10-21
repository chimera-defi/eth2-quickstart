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

# Configure sudo for the new user
log_info "Configuring sudo access for $LOGIN_UNAME..."
echo "$LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/$LOGIN_UNAME > /dev/null
sudo chmod 440 /etc/sudoers.d/$LOGIN_UNAME

# Set a default password for the new user (user should change this)
log_info "Setting up user account..."
# Generate a random password instead of hardcoded one
RANDOM_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "$LOGIN_UNAME:$RANDOM_PASSWORD" | sudo chpasswd

echo "Begin network settings output:"
ss -tulpn
sshd -t
ufw status

log_info "System setup completed!"
log_warn "IMPORTANT: Change the password for user $LOGIN_UNAME after login"
log_warn "Run: passwd $LOGIN_UNAME"
log_info "Temporary password for $LOGIN_UNAME: $RANDOM_PASSWORD"

echo
echo "=============================================="
echo "NEXT STEPS:"
echo "=============================================="
echo "1. Reboot the system: sudo reboot"
echo "2. After reboot, SSH as the new user:"
echo "   ssh $LOGIN_UNAME@$(curl -s v4.ident.me)"
echo "3. Change the password when prompted:"
echo "   passwd $LOGIN_UNAME"
echo "4. Update configuration (IMPORTANT):"
echo "   nano exports.sh"
echo "   # Update: SERVER_NAME, FEE_RECIPIENT, GRAFITTI, etc."
echo "5. Run the second installation script:"
echo "   ./run_2.sh"
echo "=============================================="
echo
