#!/bin/bash


# Firewall Configuration Script
# Sets up UFW firewall with Ethereum client and security rules

source ../../exports.sh
source ../../lib/common_functions.sh

log_info "Starting firewall configuration..."

# UFW is installed centrally via install_dependencies.sh

# Set default policies
log_info "Setting default firewall policies..."
if ! ufw default deny incoming; then
    log_error "Failed to set default deny incoming"
    exit 1
fi

if ! ufw default allow outgoing; then
    log_error "Failed to set default allow outgoing"
    exit 1
fi

# Open ports for Ethereum clients
log_info "Opening ports for Ethereum clients..."
ufw allow 30303 || log_warn "Failed to allow port 30303"
ufw allow 13000/tcp || log_warn "Failed to allow port 13000/tcp"
ufw allow 12000/udp || log_warn "Failed to allow port 12000/udp"
ufw allow in ssh || log_warn "Failed to allow SSH"
ufw allow 22/tcp || log_warn "Failed to allow port 22/tcp"
ufw allow 443/tcp || log_warn "Failed to allow port 443/tcp"

# Block outbound connections to private/reserved networks to prevent netscan abuse
log_info "Blocking outbound connections to private networks..."
log_info "This prevents netscan abuse warnings (updated Feb '23 from Erigon docs)"

# Define private network ranges to block
private_networks=(
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.0.0.0/24"
    "192.0.2.0/24"
    "192.88.99.0/24"
    "192.168.0.0/16"
    "198.18.0.0/15"
    "198.51.100.0/24"
    "203.0.113.0/24"
    "224.0.0.0/4"
    "240.0.0.0/4"
    "255.255.255.255/32"
)

for network in "${private_networks[@]}"; do
    ufw deny out on any to "$network" || log_warn "Failed to block outbound to $network"
done

# Block specific ports (updates from Prysm docs Feb '23)
log_info "Blocking specific ports for security..."
ufw deny in 4000/tcp || log_warn "Failed to deny port 4000/tcp"
ufw deny in 3500/tcp || log_warn "Failed to deny port 3500/tcp"
ufw deny in 8551/tcp || log_warn "Failed to deny port 8551/tcp"
ufw deny in 8545/tcp || log_warn "Failed to deny port 8545/tcp"

# Enable firewall
log_info "Enabling UFW firewall..."
if ! ufw enable; then
    log_error "Failed to enable UFW firewall"
    exit 1
fi

log_info "Firewall configuration completed!"
log_info "UFW firewall is now enabled with Ethereum client and security rules"
log_info "Allowed ports: 22 (SSH), 443 (HTTPS), 30303 (Ethereum P2P), 12000/13000 (Prysm)"
log_info "Blocked: Private networks, specific ports (4000, 3500, 8551, 8545)"
