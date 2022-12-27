#!/bin/bash

source ./exports.sh

sudo apt update -y
sudo apt upgrade -y
sudo apt full-upgrade -y
sudo apt autoremove -y

# setup sshd safe defaults
mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bkup
mv sshd_config /etc/ssh/sshd_config
# Copy it back for review / commit 
cp /etc/ssh/sshd_config ./

# Basic hardening

# install and config fail2ban
apt install fail2ban -y
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
useradd -m -d /home/$LOGIN_UNAME -s /bin/bash $LOGIN_UNAME

# Copy over authorized keys to created user to allow ssh
mkdir /home/$LOGIN_UNAME/.ssh
cp ~/.ssh/authorized_keys /home/$LOGIN_UNAME/.ssh/
chown -R $LOGIN_UNAME:$LOGIN_UNAME /home/$LOGIN_UNAME/.ssh
chmod 700 /home/$LOGIN_UNAME/.ssh
chmod 600 /home/$LOGIN_UNAME/.ssh/authorized_keys
usermod -aG sudo $LOGIN_UNAME

cp -r ../$REPO_NAME /home/$LOGIN_UNAME/
chmod -R +x /home/$LOGIN_UNAME/$REPO_NAME
chown -R $LOGIN_UNAME:$LOGIN_UNAME /home/$LOGIN_UNAME/$REPO_NAME

# Whitelist and only allow certain users
# AllowUsers root
# AllowUsers $LOGIN_UNAME

# Firewall rules
apt install ufw
ufw default deny incoming
ufw default allow outgoing

# Open ports for geth and prysm 
ufw allow 30303
ufw allow 13000/tcp
ufw allow 12000/udp
ufw allow in ssh
ufw allow 22/tcp
ufw allow 443/tcp

# # Disable outbound on private / reserved / rfc1981 ips to prevent netscan abuse warnings 
# block all private networks to prevent netscan abuse
ufw deny out on any to 0.0.0.0/8 
ufw deny out on any to 10.0.0.0/8 
ufw deny out on any to 100.64.0.0/10 
ufw deny out on any to 169.254.0.0/16 
ufw deny out on any to 172.16.0.0/12 
ufw deny out on any to 192.0.0.0/24 
ufw deny out on any to 192.0.2.0/24 
ufw deny out on any to 192.88.99.0/24 
ufw deny out on any to 192.168.0.0/16 
ufw deny out on any to 198.18.0.0/15 
ufw deny out on any to 198.51.100.0/24 
ufw deny out on any to 203.0.113.0/24 
ufw deny out on any to 224.0.0.0/4 
ufw deny out on any to 240.0.0.0/4 

ufw enable

# confirm time date sync
timedatectl set-ntp on

# Disable shared memory
echo "tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0 0" >> /etc/fstab

ss -tulpn
sshd -t
ufw status

echo "Manual action required!"
echo "1. Please check the settings above"

read -n 1 -p "Press enter to continue when done ^:" 

echo "2. Please run the following cmd in another shell and add the line to the file that pops up to enable $LOGIN_UNAME no-prompt sudo to help run_2.sh"
echo "$ sudo visudo"
echo "Add this to the end of the file:"
echo "$ $LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL "

read -n 1 -p "Press enter to continue when done ^:" 

echo "3. Set a password for your new user when prompted"
passwd $LOGIN_UNAME

echo "Done. Run 'sudo reboot' for all changes to take effect"
echo "Re-login via ssh $LOGIN_UNAME@$(curl -s v4.ident.me) after and run './run_2.sh'"
