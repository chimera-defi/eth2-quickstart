#!/bin/bash
set -e

# Eth2 Quick Start - One-Liner Installer
# Usage: curl -fsSL https://.../install.sh | bash

REPO_URL="https://github.com/chimera-defi/eth2-quickstart.git"
INSTALL_DIR="$HOME/.eth2-quickstart"
BRANCH="master" # or main

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}       Eth2 Quick Start - One-Liner Setup         ${NC}"
echo -e "${GREEN}==================================================${NC}"

# 1. Check Prerequisites
echo -e "${BLUE}[*] Checking system requirements...${NC}"
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root to setup the initial environment.${NC}"
    echo "Please run: sudo bash"
    exit 1
fi

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${BLUE}[*] Installing git...${NC}"
    apt-get update && apt-get install -y git
fi

# 2. Clone/Update Repository
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}[*] Updating existing repository...${NC}"
    cd "$INSTALL_DIR"
    git pull origin "$BRANCH"
else
    echo -e "${BLUE}[*] Cloning repository...${NC}"
    git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 3. Handover to Configurator/Runner
echo -e "${BLUE}[*] Starting configuration wizard...${NC}"
chmod +x install/utils/configure.sh
# We run the configurator as the SUDO_USER if possible, or root if not
# But setup usually needs root. The configurator handles permissions.

./install/utils/configure.sh "$@"
