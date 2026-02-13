#!/bin/bash
# Package definitions - SINGLE SOURCE OF TRUTH for all apt packages
# Sourced by install_dependencies.sh and consolidated_security.sh

# run_1 consolidated security (firewall, fail2ban, AIDE)
RUN_1_SECURITY_PACKAGES=(aide cron fail2ban)

# Base - needed for ALL environments
BASE_PACKAGES=(
    bash curl wget git tar gzip sudo jq openssl ca-certificates
    gnupg lsb-release software-properties-common apt-transport-https
)

# Test - infra + run_1 security (install more rather than less; apt install -y is idempotent)
TEST_PACKAGES=(
    shellcheck ufw systemd systemd-sysv openssh-server
    "${RUN_1_SECURITY_PACKAGES[@]}"
)

# Production - build tools, clients, and run_1 security
PRODUCTION_PACKAGES=(
    unzip build-essential python3 python3-pip chrony ufw
    "${RUN_1_SECURITY_PACKAGES[@]}"
    snapd cmake libssl-dev libgmp-dev libtinfo5 libprotobuf-dev pkg-config
    openjdk-17-jdk libclang-dev nginx apache2-utils bmon tcptrack
)
