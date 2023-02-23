#!/bin/bash

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
# update feb 23 '23 from https://github.com/ledgerwatch/erigon
ufw deny out on any to 0.0.0.0/8 
ufw deny out on any to 10.0.0.0/8 
ufw deny out on any to 100.64.0.0/10 
ufw deny out on any to 127.0.0.0/8
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
ufw deny out on any to 255.255.255.255/32

# updates feb '23 from prysm docs'
ufw deny in 4000/tcp
ufw deny in 3500/tcp
ufw deny in 8551/tcp
ufw deny in 8545/tcp

ufw enable
