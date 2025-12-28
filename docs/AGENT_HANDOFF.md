# Agent Handoff: Eth2 Quick Start Upgrade

## Overview
This document outlines the plan and initial implementation to transform "Eth2 Quick Start" from a collection of scripts into a cohesive, product-like experience (The "Flywheel").

## The Strategy
We are moving from manual configuration (`nano exports.sh`) to an automated "One-Liner" experience (`curl | bash`).

### Core Components
1.  **The One-Liner (`install.sh`)**: Bootstraps the environment.
2.  **The Wizard (`configure.sh`)**: Interactive TUI for configuration.
3.  **The Runner (`run_manifest.sh`)**: (To be implemented) Executes the plan.
4.  **The Doctor (`doctor.sh`)**: (To be implemented) Verifies health.

## Reference Implementation (Code to use)

### 1. `install.sh` (Entry Point)
Place this at the root of the repository.

```bash
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

./install/utils/configure.sh "$@"
```

### 2. `install/utils/configure.sh` (The Wizard)
This script uses `whiptail` to generate `config/user_config.env` and `install_manifest.sh`.

```bash
#!/bin/bash

# Configuration Wizard for Eth2 Quick Start
# Uses whiptail to prompt the user and generates config/user_config.env

set -e

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Ensure config directory exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/user_config.env"
INSTALL_MANIFEST="$ROOT_DIR/install_manifest.sh"

mkdir -p "$CONFIG_DIR"

# Helper for whiptail
function show_msg() {
    whiptail --title "Eth2 Quick Start" --msgbox "$1" 10 60
}

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Whiptail not found. Installing..."
    sudo apt-get update && sudo apt-get install -y whiptail
fi

# Welcome
whiptail --title "Eth2 Quick Start Wizard" --msgbox "Welcome to the Ethereum Node Setup Wizard.\n\nThis tool will guide you through configuring your node.\n\nIt will generate a configuration file at $CONFIG_FILE." 12 70

# 1. Network Selection
NETWORK=$(whiptail --title "Network Selection" --menu "Choose the Ethereum Network:" 15 60 2 \
"mainnet" "Ethereum Mainnet (Real Value)" \
"holesky" "Holesky Testnet (Testing)" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit 0; fi

# 2. Client Selection Strategy
HARDWARE=$(whiptail --title "Hardware Profile" --menu "Select your hardware profile:" 15 60 3 \
"high" "High-End (32GB+ RAM, 2TB+ NVMe) - Best Performance" \
"mid" "Mid-Range (16GB RAM, SSD) - Balanced" \
"low" "Low-Resource (8GB RAM) - Efficiency First" 3>&1 1>&2 2>&3)

# Recommend clients based on hardware
case $HARDWARE in
    "high")
        REC_EXEC="reth"
        REC_CONS="lighthouse"
        ;;
    "mid")
        REC_EXEC="geth"
        REC_CONS="prysm"
        ;;
    "low")
        REC_EXEC="nimbus_eth1"
        REC_CONS="nimbus"
        ;;
esac

# Confirm Client Selection
whiptail --title "Client Recommendations" --yesno "Based on your hardware, we recommend:\n\nExecution: $REC_EXEC\nConsensus: $REC_CONS\n\nDo you want to use these defaults?" 12 60
USE_DEFAULTS=$?

if [ $USE_DEFAULTS -eq 0 ]; then
    EXEC_CLIENT=$REC_EXEC
    CONS_CLIENT=$REC_CONS
else
    # Manual Selection
    EXEC_CLIENT=$(whiptail --title "Execution Client" --menu "Select Execution Client:" 15 60 5 \
    "geth" "Geth (Go) - Stable, Popular" \
    "nethermind" "Nethermind (C#) - Enterprise" \
    "besu" "Besu (Java) - Enterprise" \
    "erigon" "Erigon (Go) - Archival/Fast" \
    "reth" "Reth (Rust) - High Performance" \
    "nimbus_eth1" "Nimbus (Nim) - Lightweight" 3>&1 1>&2 2>&3)
    
    CONS_CLIENT=$(whiptail --title "Consensus Client" --menu "Select Consensus Client:" 15 60 5 \
    "prysm" "Prysm (Go) - Popular, Easy" \
    "lighthouse" "Lighthouse (Rust) - Secure, Fast" \
    "teku" "Teku (Java) - Institutional" \
    "nimbus" "Nimbus (Nim) - Lightweight" \
    "lodestar" "Lodestar (TS) - JS/TS Ecosystem" \
    "grandine" "Grandine (Rust) - Fast (Beta)" 3>&1 1>&2 2>&3)
fi

# 3. MEV Selection
MEV_CHOICE=$(whiptail --title "MEV Configuration" --menu "Select MEV Solution (for validator rewards):" 15 70 3 \
"mev-boost" "MEV-Boost (Standard) - Recommended" \
"commit-boost" "Commit-Boost (Advanced) - Modular" \
"none" "None - No extra rewards (Not Recommended)" 3>&1 1>&2 2>&3)

# 4. Fee Recipient
FEE_RECIPIENT=$(whiptail --title "Fee Recipient" --inputbox "Enter your ETH address for rewards:" 10 60 "0x0000000000000000000000000000000000000000" 3>&1 1>&2 2>&3)

# 5. Graffiti
GRAFFITI=$(whiptail --title "Graffiti" --inputbox "Enter your validator graffiti (public note on blocks):" 10 60 "Eth2QuickStart" 3>&1 1>&2 2>&3)

# 6. Generate Configuration
echo "# Auto-generated by configure.sh on $(date)" > "$CONFIG_FILE"
echo "export ETH_NETWORK='$NETWORK'" >> "$CONFIG_FILE"
echo "export FEE_RECIPIENT='$FEE_RECIPIENT'" >> "$CONFIG_FILE"
echo "export GRAFITTI='$GRAFFITI'" >> "$CONFIG_FILE"

echo "# Execution Client: $EXEC_CLIENT" >> "$CONFIG_FILE"
echo "# Consensus Client: $CONS_CLIENT" >> "$CONFIG_FILE"

# Generate Manifest
echo "#!/bin/bash" > "$INSTALL_MANIFEST"
echo "# Manifest generated on $(date)" >> "$INSTALL_MANIFEST"
echo "set -e" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"
echo "echo 'Starting Installation based on Manifest...'" >> "$INSTALL_MANIFEST"

# Add System Setup
echo "./run_1.sh" >> "$INSTALL_MANIFEST"

# Add Client Installs
echo "./install/execution/$EXEC_CLIENT.sh" >> "$INSTALL_MANIFEST"
echo "./install/consensus/$CONS_CLIENT.sh" >> "$INSTALL_MANIFEST"

# Add MEV Install
if [ "$MEV_CHOICE" == "mev-boost" ]; then
    echo "./install/mev/install_mev_boost.sh" >> "$INSTALL_MANIFEST"
elif [ "$MEV_CHOICE" == "commit-boost" ]; then
    echo "./install/mev/install_commit_boost.sh" >> "$INSTALL_MANIFEST"
fi

chmod +x "$INSTALL_MANIFEST"

show_msg "Configuration Complete!\n\n1. Config saved to: $CONFIG_FILE\n2. Manifest saved to: $INSTALL_MANIFEST\n\nRun './install_manifest.sh' (or reboot and run it) to apply changes."

if (whiptail --title "Run Installation?" --yesno "Do you want to run the installation now? (Requires sudo)" 10 60); then
    clear
    echo "Running installation..."
    sudo "$INSTALL_MANIFEST"
else
    clear
    echo "Setup complete. Run ./install_manifest.sh when ready."
fi
```

### 3. Modifications to `exports.sh`
You need to add this block to `exports.sh` to load the user configuration:

```bash
# ----------------------------------------------------------------------------
# User Configuration Override
# ----------------------------------------------------------------------------
# If the user configuration file exists, source it to override defaults
# Use absolute path resolution if possible, or relative to this file
if [ -f "$(dirname "${BASH_SOURCE[0]}")/config/user_config.env" ]; then
    source "$(dirname "${BASH_SOURCE[0]}")/config/user_config.env"
fi
```

## Next Steps for the Coding Agent

1.  **Restore the scripts**: Re-create `install.sh` and `install/utils/configure.sh` using the code above.
2.  **Update exports.sh**: Apply the configuration override block.
3.  **Implement Manifest Runner**: Create `install/utils/run_manifest.sh` to execute the manifest robustly (logging, error handling).
4.  **Implement Vibe Mode**: Add `--vibe` support to `install.sh` and `configure.sh` for non-interactive defaults.
5.  **Create Doctor Script**: Create `install/utils/doctor.sh` to verify installation success.

