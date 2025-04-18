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
chmod +x ./firewall.sh
./firewall.sh

# confirm time date sync
sudo apt install chrony -y
timedatectl set-ntp on

# Disable shared memory
echo "tmpfs	/run/shm	tmpfs	ro,noexec,nosuid	0 0" >> /etc/fstab
echo "Disabled shared memory"

echo "Begin network settings output:"

ss -tulpn
sshd -t
ufw status

echo "Manual action required!"
echo "1. Please check the settings above"

read -n 1 -p "Press enter to continue when done ^:" 

echo "2. Please run the following cmds now in another shell and add the line to the file that pops up to enable $LOGIN_UNAME no-prompt sudo to help run the second stage"
echo "ssh root@$(curl -s v4.ident.me) "
echo "sudo visudo"
echo "Add this to the end of the file:"
echo "$LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL "

read -n 1 -p "Press enter to continue when done ^:" 

echo "3. Set a password for your new user when prompted"
passwd $LOGIN_UNAME

echo "Done. Run 'sudo reboot' for all changes to take effect"
echo "Re-login via ssh $LOGIN_UNAME@$(curl -s v4.ident.me) after and run './run_2.sh'"
