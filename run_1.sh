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

# Dependencies are installed centrally via install_dependencies.sh
# Install and configure fail2ban
log_info "Installing and configuring fail2ban..."
install_dependencies fail2ban
cat >> /etc/fail2ban/jail.local << EOF
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
maxretry = $maxretry
EOF
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

# Time synchronization is configured centrally via install_dependencies.sh

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

# Display system status for verification
echo "Begin network settings output:"
ss -tulpn
sshd -t
ufw status

echo ""
echo "=== SYSTEM STATUS VERIFICATION ==="
echo "Please review the settings above before continuing."
echo ""

# Automated sudo configuration
log_info "Configuring sudo access for $LOGIN_UNAME"
cat > "/etc/sudoers.d/$LOGIN_UNAME" << EOF
# Allow $LOGIN_UNAME to run all commands without password
# This is required for automated setup scripts
$LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL
EOF

# Set proper permissions
chmod 440 "/etc/sudoers.d/$LOGIN_UNAME"

# Validate sudoers configuration
if ! visudo -c; then
    log_error "Sudo configuration validation failed"
    rm -f "/etc/sudoers.d/$LOGIN_UNAME"
    exit 1
fi

log_info "Sudo configuration completed for $LOGIN_UNAME"

# Set user password if not already set
if ! passwd -S "$LOGIN_UNAME" | grep -q " P "; then
    echo "Setting password for user $LOGIN_UNAME..."
    echo "Please enter a secure password:"
    passwd "$LOGIN_UNAME"
fi

# Create handoff script for seamless transition
log_info "Creating handoff script for Phase 2"
cat > "/home/$LOGIN_UNAME/complete_setup.sh" << EOF
#!/bin/bash
# Automated setup completion script
# Run this after logging in as $LOGIN_UNAME

set -euo pipefail

echo "=== Ethereum Node Setup - Phase 2 ==="
echo "This script will complete the setup process"
echo

# Verify we're running as the correct user
if [[ "\$(whoami)" != "$LOGIN_UNAME" ]]; then
    echo "Error: This script must be run as user $LOGIN_UNAME"
    exit 1
fi

# Verify sudo access
if ! sudo -n true 2>/dev/null; then
    echo "Error: Sudo access not configured properly"
    exit 1
fi

echo "✓ User verification passed"
echo "✓ Sudo access confirmed"
echo

# Navigate to repository directory
if [[ -d "$REPO_NAME" ]]; then
    cd "$REPO_NAME"
    echo "✓ Navigated to $REPO_NAME directory"
else
    echo "Error: Repository directory not found"
    exit 1
fi

# Run phase 2 setup
echo "Starting Phase 2 setup..."
if [[ -f "run_2.sh" ]]; then
    chmod +x run_2.sh
    ./run_2.sh
else
    echo "Error: run_2.sh not found"
    exit 1
fi
EOF

chmod +x "/home/$LOGIN_UNAME/complete_setup.sh"
chown "$LOGIN_UNAME:$LOGIN_UNAME" "/home/$LOGIN_UNAME/complete_setup.sh"

# Get server IP for display
SERVER_IP=$(curl -s v4.ident.me 2>/dev/null || echo "YOUR_SERVER_IP")

echo ""
echo "=========================================="
echo "  PHASE 1 SETUP COMPLETED SUCCESSFULLY"
echo "=========================================="
echo ""
echo "Next Steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. SSH back in as $LOGIN_UNAME:"
echo "   ssh -p $YourSSHPortNumber $LOGIN_UNAME@$SERVER_IP"
echo "3. Run the completion script:"
echo "   ./complete_setup.sh"
echo ""
echo "Security Features Enabled:"
echo "  ✓ Enhanced SSH configuration"
echo "  ✓ Fail2ban intrusion prevention"
echo "  ✓ UFW firewall with Ethereum rules"
echo "  ✓ System hardening measures"
echo "  ✓ Automated Phase 2 handoff"
echo ""
echo "=========================================="
