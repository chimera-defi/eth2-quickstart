#!/bin/bash

# Configuration Wizard for Eth2 Quick Start
# Uses whiptail to prompt the user and generates config/user_config.env
# Supports --vibe mode for non-interactive defaults

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
INSTALL_MANIFEST="$ROOT_DIR/install_manifest.sh"

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

# 6. Generate Configuration
echo "# Auto-generated by configure.sh on $(date)" > "$CONFIG_FILE"
echo "# Network: $NETWORK" >> "$CONFIG_FILE"
echo "# Hardware Profile: ${HARDWARE:-manual}" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"
echo "export ETH_NETWORK='$NETWORK'" >> "$CONFIG_FILE"
echo "export FEE_RECIPIENT='$FEE_RECIPIENT'" >> "$CONFIG_FILE"
echo "export GRAFITTI='$GRAFFITI'" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"
echo "# Selected Clients" >> "$CONFIG_FILE"
echo "export EXEC_CLIENT='$EXEC_CLIENT'" >> "$CONFIG_FILE"
echo "export CONS_CLIENT='$CONS_CLIENT'" >> "$CONFIG_FILE"
echo "" >> "$CONFIG_FILE"
echo "# MEV Configuration" >> "$CONFIG_FILE"
echo "export MEV_SOLUTION='$MEV_CHOICE'" >> "$CONFIG_FILE"

# Notify user
echo -e "${GREEN}[OK]${NC} Configuration saved to $CONFIG_FILE"

# Generate Manifest
echo "#!/bin/bash" > "$INSTALL_MANIFEST"
echo "# Installation Manifest - Auto-generated on $(date)" >> "$INSTALL_MANIFEST"
echo "# Network: $NETWORK | Execution: $EXEC_CLIENT | Consensus: $CONS_CLIENT | MEV: $MEV_CHOICE" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"
echo "set -e" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"
echo "# Source configuration" >> "$INSTALL_MANIFEST"
echo "SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"" >> "$INSTALL_MANIFEST"
echo "cd \"\$SCRIPT_DIR\"" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"
echo "# Source exports and user config" >> "$INSTALL_MANIFEST"
echo "source ./exports.sh" >> "$INSTALL_MANIFEST"
echo "if [[ -f ./config/user_config.env ]]; then" >> "$INSTALL_MANIFEST"
echo "    source ./config/user_config.env" >> "$INSTALL_MANIFEST"
echo "fi" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"
echo "echo '================================================='" >> "$INSTALL_MANIFEST"
echo "echo '  Starting Installation based on Manifest...'" >> "$INSTALL_MANIFEST"
echo "echo '================================================='" >> "$INSTALL_MANIFEST"
echo "echo ''" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"

# Add System Setup
echo "# Phase 1: System Setup" >> "$INSTALL_MANIFEST"
echo "echo '[1/4] Running system setup (run_1.sh)...'" >> "$INSTALL_MANIFEST"
echo "./run_1.sh" >> "$INSTALL_MANIFEST"
echo "echo '[OK] System setup complete'" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"

# Add Client Installs
echo "# Phase 2: Execution Client Installation" >> "$INSTALL_MANIFEST"
echo "echo '[2/4] Installing execution client: $EXEC_CLIENT...'" >> "$INSTALL_MANIFEST"
echo "./install/execution/$EXEC_CLIENT.sh" >> "$INSTALL_MANIFEST"
echo "echo '[OK] Execution client installed'" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"

echo "# Phase 3: Consensus Client Installation" >> "$INSTALL_MANIFEST"
echo "echo '[3/4] Installing consensus client: $CONS_CLIENT...'" >> "$INSTALL_MANIFEST"
echo "./install/consensus/$CONS_CLIENT.sh" >> "$INSTALL_MANIFEST"
echo "echo '[OK] Consensus client installed'" >> "$INSTALL_MANIFEST"
echo "" >> "$INSTALL_MANIFEST"

# Add MEV Install
echo "# Phase 4: MEV Solution Installation" >> "$INSTALL_MANIFEST"
if [[ "$MEV_CHOICE" == "mev-boost" ]]; then
    echo "echo '[4/4] Installing MEV-Boost...'" >> "$INSTALL_MANIFEST"
    echo "./install/mev/install_mev_boost.sh" >> "$INSTALL_MANIFEST"
    echo "echo '[OK] MEV-Boost installed'" >> "$INSTALL_MANIFEST"
elif [[ "$MEV_CHOICE" == "commit-boost" ]]; then
    echo "echo '[4/4] Installing Commit-Boost...'" >> "$INSTALL_MANIFEST"
    echo "./install/mev/install_commit_boost.sh" >> "$INSTALL_MANIFEST"
    echo "echo '[OK] Commit-Boost installed'" >> "$INSTALL_MANIFEST"
else
    echo "echo '[4/4] Skipping MEV installation (none selected)'" >> "$INSTALL_MANIFEST"
fi
echo "" >> "$INSTALL_MANIFEST"

# Add completion message
echo "echo ''" >> "$INSTALL_MANIFEST"
echo "echo '================================================='" >> "$INSTALL_MANIFEST"
echo "echo '  Installation Complete!'" >> "$INSTALL_MANIFEST"
echo "echo '================================================='" >> "$INSTALL_MANIFEST"
echo "echo ''" >> "$INSTALL_MANIFEST"
echo "echo 'Run ./install/utils/doctor.sh to verify your installation'" >> "$INSTALL_MANIFEST"
echo "echo ''" >> "$INSTALL_MANIFEST"

chmod +x "$INSTALL_MANIFEST"

echo -e "${GREEN}[OK]${NC} Manifest saved to $INSTALL_MANIFEST"
echo ""

# Show summary
if [[ "$VIBE_MODE" != "true" ]]; then
    show_msg "Configuration Complete!\n\n1. Config saved to: $CONFIG_FILE\n2. Manifest saved to: $INSTALL_MANIFEST\n\nRun './install_manifest.sh' to apply changes."

    if whiptail --title "Run Installation?" --yesno "Do you want to run the installation now? (Requires sudo)" 10 60; then
        clear
        echo -e "${GREEN}[*] Running installation...${NC}"
        echo ""
        sudo "$INSTALL_MANIFEST"
    else
        clear
        echo -e "${YELLOW}[*] Setup complete. Run ./install_manifest.sh when ready.${NC}"
    fi
else
    # Vibe mode - show summary and offer to run
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
    echo "  - $INSTALL_MANIFEST"
    echo ""
    echo "To proceed with installation, run:"
    echo "  sudo ./install_manifest.sh"
    echo ""
    echo "Or run the manifest runner for better logging:"
    echo "  sudo ./install/utils/run_manifest.sh"
fi
