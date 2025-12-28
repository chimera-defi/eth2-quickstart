#!/bin/bash

# Configuration Wizard for Eth2 Quick Start
# Uses whiptail to prompt the user and generates config/user_config.env
# Supports --vibe mode for non-interactive defaults
#
# SECURITY NOTE: This wizard generates TWO installation phases:
#   Phase 1: System hardening (run as root, requires reboot)
#   Phase 2: Client installation (run as new secure user after reboot)

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure config directory exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
CONFIG_DIR="$ROOT_DIR/config"
CONFIG_FILE="$CONFIG_DIR/user_config.env"
PHASE1_MANIFEST="$ROOT_DIR/install_phase1.sh"
PHASE2_MANIFEST="$ROOT_DIR/install_phase2.sh"

mkdir -p "$CONFIG_DIR"

# Parse arguments
VIBE_MODE=false
for arg in "$@"; do
    case $arg in
        --vibe)
            VIBE_MODE=true
            shift
            ;;
        --help|-h)
            echo "Eth2 Quick Start - Configuration Wizard"
            echo ""
            echo "Usage: ./configure.sh [options]"
            echo ""
            echo "Options:"
            echo "  --vibe      Use sensible defaults (non-interactive)"
            echo "  --help, -h  Show this help message"
            echo ""
            echo "This wizard generates TWO installation phases for security:"
            echo "  Phase 1: System hardening (run as root, requires reboot)"
            echo "  Phase 2: Client installation (run as new user after reboot)"
            exit 0
            ;;
    esac
done

# Helper for whiptail
show_msg() {
    whiptail --title "Eth2 Quick Start" --msgbox "$1" 10 60
}

# Vibe mode defaults
set_vibe_defaults() {
    echo -e "${YELLOW}[*] Vibe Mode: Selecting sensible defaults...${NC}"

    # Detect hardware and set appropriate defaults
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')

    if [[ $TOTAL_RAM -ge 32 ]]; then
        HARDWARE="high"
        EXEC_CLIENT="reth"
        CONS_CLIENT="lighthouse"
        echo -e "${GREEN}[*] Detected high-end hardware (${TOTAL_RAM}GB RAM)${NC}"
    elif [[ $TOTAL_RAM -ge 16 ]]; then
        HARDWARE="mid"
        EXEC_CLIENT="geth"
        CONS_CLIENT="prysm"
        echo -e "${GREEN}[*] Detected mid-range hardware (${TOTAL_RAM}GB RAM)${NC}"
    else
        HARDWARE="low"
        EXEC_CLIENT="nimbus_eth1"
        CONS_CLIENT="nimbus"
        echo -e "${GREEN}[*] Detected low-resource hardware (${TOTAL_RAM}GB RAM)${NC}"
    fi

    NETWORK="mainnet"
    MEV_CHOICE="mev-boost"
    FEE_RECIPIENT="0x0000000000000000000000000000000000000000"
    GRAFFITI="Eth2QuickStart"

    echo -e "${GREEN}[*] Selected: Network=$NETWORK, Exec=$EXEC_CLIENT, Cons=$CONS_CLIENT, MEV=$MEV_CHOICE${NC}"
}

# Interactive mode using whiptail
run_interactive_wizard() {
    # Check if whiptail is installed
    if ! command -v whiptail &> /dev/null; then
        echo "Whiptail not found. Installing..."
        sudo apt-get update && sudo apt-get install -y whiptail
    fi

    # Welcome with security explanation
    whiptail --title "Eth2 Quick Start Wizard" --msgbox "Welcome to the Ethereum Node Setup Wizard.\n\nIMPORTANT: Installation happens in TWO phases:\n\n1. Phase 1: System hardening (as root)\n   - Creates secure user, hardens SSH, firewall\n   - REQUIRES REBOOT after completion\n\n2. Phase 2: Client installation (as new user)\n   - Installs execution/consensus clients\n   - Run AFTER rebooting and SSH'ing as new user" 18 70

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
    if [ $? -ne 0 ]; then exit 0; fi

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
    if whiptail --title "Client Recommendations" --yesno "Based on your hardware, we recommend:\n\nExecution: $REC_EXEC\nConsensus: $REC_CONS\n\nDo you want to use these defaults?" 12 60; then
        EXEC_CLIENT=$REC_EXEC
        CONS_CLIENT=$REC_CONS
    else
        # Manual Selection - Execution Client
        EXEC_CLIENT=$(whiptail --title "Execution Client" --menu "Select Execution Client:" 18 60 7 \
        "geth" "Geth (Go) - Stable, Popular" \
        "nethermind" "Nethermind (C#) - Enterprise" \
        "besu" "Besu (Java) - Enterprise" \
        "erigon" "Erigon (Go) - Archival/Fast" \
        "reth" "Reth (Rust) - High Performance" \
        "nimbus_eth1" "Nimbus (Nim) - Lightweight" \
        "ethrex" "Ethrex (Rust) - Minimalist" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 0; fi

        # Manual Selection - Consensus Client
        CONS_CLIENT=$(whiptail --title "Consensus Client" --menu "Select Consensus Client:" 18 60 6 \
        "prysm" "Prysm (Go) - Popular, Easy" \
        "lighthouse" "Lighthouse (Rust) - Secure, Fast" \
        "teku" "Teku (Java) - Institutional" \
        "nimbus" "Nimbus (Nim) - Lightweight" \
        "lodestar" "Lodestar (TS) - JS/TS Ecosystem" \
        "grandine" "Grandine (Rust) - Fast (Beta)" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 0; fi
    fi

    # 3. MEV Selection
    MEV_CHOICE=$(whiptail --title "MEV Configuration" --menu "Select MEV Solution (for validator rewards):" 15 70 3 \
    "mev-boost" "MEV-Boost (Standard) - Recommended" \
    "commit-boost" "Commit-Boost (Advanced) - Modular" \
    "none" "None - No extra rewards (Not Recommended)" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then exit 0; fi

    # 4. Fee Recipient
    FEE_RECIPIENT=$(whiptail --title "Fee Recipient" --inputbox "Enter your ETH address for rewards:" 10 60 "0x0000000000000000000000000000000000000000" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then exit 0; fi

    # 5. Graffiti
    GRAFFITI=$(whiptail --title "Graffiti" --inputbox "Enter your validator graffiti (public note on blocks):" 10 60 "Eth2QuickStart" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then exit 0; fi
}

# Main logic
if [[ "$VIBE_MODE" == "true" ]]; then
    set_vibe_defaults
else
    run_interactive_wizard
fi

# Generate Configuration File
{
    echo "# Auto-generated by configure.sh on $(date)"
    echo "# Network: $NETWORK"
    echo "# Hardware Profile: ${HARDWARE:-manual}"
    echo ""
    echo "export ETH_NETWORK='$NETWORK'"
    echo "export FEE_RECIPIENT='$FEE_RECIPIENT'"
    echo "export GRAFITTI='$GRAFFITI'"
    echo ""
    echo "# Selected Clients"
    echo "export EXEC_CLIENT='$EXEC_CLIENT'"
    echo "export CONS_CLIENT='$CONS_CLIENT'"
    echo ""
    echo "# MEV Configuration"
    echo "export MEV_SOLUTION='$MEV_CHOICE'"
} > "$CONFIG_FILE"

echo -e "${GREEN}[OK]${NC} Configuration saved to $CONFIG_FILE"

# =============================================================================
# Generate Phase 1 Manifest (System Hardening - Run as ROOT)
# =============================================================================
{
    cat << 'PHASE1_HEADER'
#!/bin/bash
# ============================================================================
# PHASE 1: System Hardening and Security Setup
# ============================================================================
# This script MUST be run as ROOT
# After completion, you MUST:
#   1. Note the credentials displayed (or check /root/handoff_info.txt)
#   2. Reboot the server: sudo reboot
#   3. SSH back in as the NEW USER (not root)
#   4. Run Phase 2: ./install_phase2.sh
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source exports
source ./exports.sh
if [[ -f ./config/user_config.env ]]; then
    source ./config/user_config.env
fi

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: Phase 1 must be run as root${NC}"
    echo "Please run: sudo ./install_phase1.sh"
    exit 1
fi

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Phase 1: System Hardening${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "This phase will:"
echo "  - Update system packages"
echo "  - Configure SSH security"
echo "  - Create secure user account"
echo "  - Setup firewall and intrusion detection"
echo ""
echo -e "${YELLOW}After completion, you MUST reboot and login as the new user.${NC}"
echo ""
read -r -p "Press Enter to continue or Ctrl+C to cancel..."

# Run the system setup script
./run_1.sh

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Phase 1 Complete - REBOOT REQUIRED${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo -e "${YELLOW}CRITICAL: You must now:${NC}"
echo ""
echo "  1. Save the credentials from /root/handoff_info.txt"
echo "  2. Reboot the server:"
echo "     sudo reboot"
echo ""
echo "  3. SSH back in as the NEW user (check handoff_info.txt for details)"
echo ""
echo "  4. Navigate to the install directory:"
echo "     cd ~/.eth2-quickstart"
echo ""
echo "  5. Run Phase 2 to install Ethereum clients:"
echo "     ./install_phase2.sh"
echo ""
echo -e "${RED}DO NOT skip the reboot - security changes require it.${NC}"
echo ""
PHASE1_HEADER
} > "$PHASE1_MANIFEST"

chmod +x "$PHASE1_MANIFEST"
echo -e "${GREEN}[OK]${NC} Phase 1 manifest saved to $PHASE1_MANIFEST"

# =============================================================================
# Generate Phase 2 Manifest (Client Installation - Run as NEW USER)
# =============================================================================
{
    cat << 'PHASE2_HEADER'
#!/bin/bash
# ============================================================================
# PHASE 2: Ethereum Client Installation
# ============================================================================
# This script should be run as the SECURE USER (not root)
# Prerequisites:
#   - Phase 1 completed successfully
#   - Server has been rebooted
#   - You are logged in as the new secure user
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Navigate to script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Source exports
source ./exports.sh
source ./lib/common_functions.sh
if [[ -f ./config/user_config.env ]]; then
    source ./config/user_config.env
fi

# Verify NOT running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}ERROR: Phase 2 should NOT be run as root${NC}"
    echo "Please run as the secure user created in Phase 1"
    echo "Check /root/handoff_info.txt for credentials"
    exit 1
fi

# Verify running as the expected user
EXPECTED_USER="${LOGIN_UNAME:-eth}"
CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" != "$EXPECTED_USER" ]]; then
    echo -e "${YELLOW}WARNING: Running as '$CURRENT_USER', expected '$EXPECTED_USER'${NC}"
    read -r -p "Continue anyway? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Phase 2: Ethereum Client Installation${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
PHASE2_HEADER

    # Add configuration display
    echo "echo \"Configuration:\""
    echo "echo \"  Network:    \${ETH_NETWORK:-mainnet}\""
    echo "echo \"  Execution:  $EXEC_CLIENT\""
    echo "echo \"  Consensus:  $CONS_CLIENT\""
    echo "echo \"  MEV:        $MEV_CHOICE\""
    echo "echo \"\""
    echo "read -r -p \"Press Enter to continue or Ctrl+C to cancel...\""
    echo ""

    # Install dependencies
    echo "# Install dependencies"
    echo "echo -e \"\${BLUE}[1/4] Installing dependencies...\${NC}\""
    echo "./install/utils/install_dependencies.sh"
    echo "echo -e \"\${GREEN}[OK]\${NC} Dependencies installed\""
    echo ""

    # Install execution client
    echo "# Install execution client: $EXEC_CLIENT"
    echo "echo -e \"\${BLUE}[2/4] Installing execution client: $EXEC_CLIENT...\${NC}\""
    echo "./install/execution/$EXEC_CLIENT.sh"
    echo "echo -e \"\${GREEN}[OK]\${NC} Execution client installed\""
    echo ""

    # Install consensus client
    echo "# Install consensus client: $CONS_CLIENT"
    echo "echo -e \"\${BLUE}[3/4] Installing consensus client: $CONS_CLIENT...\${NC}\""
    echo "./install/consensus/$CONS_CLIENT.sh"
    echo "echo -e \"\${GREEN}[OK]\${NC} Consensus client installed\""
    echo ""

    # Install MEV solution
    echo "# Install MEV solution: $MEV_CHOICE"
    echo "echo -e \"\${BLUE}[4/4] Installing MEV solution: $MEV_CHOICE...\${NC}\""
    case "$MEV_CHOICE" in
        "mev-boost")
            echo "./install/mev/install_mev_boost.sh"
            echo "echo -e \"\${GREEN}[OK]\${NC} MEV-Boost installed\""
            ;;
        "commit-boost")
            echo "./install/mev/install_commit_boost.sh"
            echo "echo -e \"\${GREEN}[OK]\${NC} Commit-Boost installed\""
            ;;
        *)
            echo "echo -e \"\${YELLOW}[SKIP]\${NC} MEV installation skipped\""
            ;;
    esac
    echo ""

    # Completion message
    cat << 'PHASE2_FOOTER'

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Phase 2 Complete - Installation Finished!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Start your clients:"
echo "     sudo systemctl start eth1"
echo "     sudo systemctl start cl"
echo ""
echo "  2. Monitor sync progress:"
echo "     sudo journalctl -u eth1 -u cl -f"
echo ""
echo "  3. Verify installation:"
echo "     ./install/utils/doctor.sh"
echo ""
echo "  4. (Optional) Setup SSL for RPC endpoint:"
echo "     sudo ./install/ssl/install_acme_ssl.sh"
echo ""
echo "For more information, see the README.md"
echo ""
PHASE2_FOOTER
} > "$PHASE2_MANIFEST"

chmod +x "$PHASE2_MANIFEST"
echo -e "${GREEN}[OK]${NC} Phase 2 manifest saved to $PHASE2_MANIFEST"

echo ""

# Show summary
if [[ "$VIBE_MODE" != "true" ]]; then
    show_msg "Configuration Complete!\n\nTwo installation phases created:\n\n1. Phase 1 (as root):\n   ./install_phase1.sh\n\n2. Phase 2 (as new user, after reboot):\n   ./install_phase2.sh"

    if whiptail --title "Run Phase 1?" --yesno "Do you want to run Phase 1 now?\n\nThis will:\n- Harden the system\n- Create a new secure user\n- Require a REBOOT after completion\n\nAfter reboot, you'll run Phase 2 as the new user." 14 60; then
        clear
        echo -e "${GREEN}[*] Running Phase 1...${NC}"
        echo ""
        sudo "$PHASE1_MANIFEST"
    else
        clear
        echo -e "${YELLOW}[*] Setup complete. Run ./install_phase1.sh when ready.${NC}"
    fi
else
    # Vibe mode - show summary
    echo ""
    echo -e "${GREEN}==================================================${NC}"
    echo -e "${GREEN}  Configuration Complete (Vibe Mode)${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo ""
    echo "Summary:"
    echo "  Network:    $NETWORK"
    echo "  Execution:  $EXEC_CLIENT"
    echo "  Consensus:  $CONS_CLIENT"
    echo "  MEV:        $MEV_CHOICE"
    echo ""
    echo "Files created:"
    echo "  - $CONFIG_FILE"
    echo "  - $PHASE1_MANIFEST (run as root)"
    echo "  - $PHASE2_MANIFEST (run as new user after reboot)"
    echo ""
    echo -e "${YELLOW}INSTALLATION IS A TWO-PHASE PROCESS:${NC}"
    echo ""
    echo "  Phase 1 (as root):"
    echo "    sudo ./install_phase1.sh"
    echo "    -> Hardens system, creates user, REQUIRES REBOOT"
    echo ""
    echo "  Phase 2 (as new user, after reboot):"
    echo "    ./install_phase2.sh"
    echo "    -> Installs Ethereum clients"
    echo ""
fi
