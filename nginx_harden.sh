#!/bin/bash

cat > $HOME/nginx-proxy.conf << EOF
# Block IPs trying to use server as proxy.
#
# Matches e.g.
# 192.168.1.1 - - "GET http://www.something.com/

[Definition]
failregex = ^<HOST> -.*GET http.*
ignoreregex =
EOF

mv $HOME/nginx-proxy.conf /etc/fail2ban/filter.d/nginx-proxy.conf

cat /etc/fail2ban/jail.local > $HOME/jail.local << EOF
## block hosts trying to abuse our server as a forward proxy
[nginx-proxy]
enabled = true
port    = 80,443
filter = nginx-proxy
logpath = /var/log/nginx/access.log
maxretry = 2
bantime  = 86400
EOF

sudo mv $HOME/jail.local  /etc/fail2ban/jail.local

systemctl restart fail2ban
systemctl restart nginx
