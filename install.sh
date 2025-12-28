#!/bin/bash
set -e

# Eth2 Quick Start - One-Liner Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/master/install.sh | bash
# Or with vibe mode: curl -fsSL ... | bash -s -- --vibe
#
# SECURITY NOTE: This installer uses a TWO-PHASE approach:
#   Phase 1: System hardening (this script, as root) - REQUIRES REBOOT
#   Phase 2: Client installation (run manually as new user after reboot)

REPO_URL="https://github.com/chimera-defi/eth2-quickstart.git"
INSTALL_DIR="$HOME/.eth2-quickstart"
BRANCH="master"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
VIBE_MODE=false
PHASE_ONLY=""
for arg in "$@"; do
    case $arg in
        --vibe)
            VIBE_MODE=true
            shift
            ;;
        --branch=*)
            BRANCH="${arg#*=}"
            shift
            ;;
        --phase1-only)
            PHASE_ONLY="1"
            shift
            ;;
        --help|-h)
            echo "Eth2 Quick Start - One-Liner Installer"
            echo ""
            echo "Usage: curl -fsSL <url>/install.sh | bash [options]"
            echo ""
            echo "Options:"
            echo "  --vibe           Use sensible defaults (non-interactive)"
            echo "  --branch=NAME    Use a specific branch (default: master)"
            echo "  --phase1-only    Only run Phase 1 (system hardening)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "SECURITY: Installation happens in TWO phases:"
            echo "  Phase 1: System hardening (as root, requires reboot)"
            echo "  Phase 2: Client installation (as new user, after reboot)"
            exit 0
            ;;
    esac
done

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}       Eth2 Quick Start - One-Liner Setup         ${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: This is a TWO-PHASE installation:${NC}"
echo "  Phase 1: System hardening (this will run now)"
echo "  Phase 2: Client installation (run after reboot)"
echo ""

# 1. Check Prerequisites
echo -e "${BLUE}[*] Checking system requirements...${NC}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root to setup the initial environment.${NC}"
    echo "Please run: sudo bash -c \"\$(curl -fsSL <url>/install.sh)\""
    exit 1
fi

# Check OS compatibility
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    case "$ID" in
        ubuntu|debian)
            echo -e "${GREEN}[OK]${NC} Running on $ID $VERSION_ID"
            ;;
        *)
            echo -e "${YELLOW}[WARN]${NC} Unsupported OS: $ID (designed for Ubuntu/Debian)"
            echo "Proceeding anyway, but some features may not work."
            ;;
    esac
else
    echo -e "${YELLOW}[WARN]${NC} Could not detect OS version"
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
    echo "This installer requires x86_64 (amd64) architecture."
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Architecture: $ARCH"

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${BLUE}[*] Installing git...${NC}"
    apt-get update && apt-get install -y git
fi
echo -e "${GREEN}[OK]${NC} Git is installed"

# Check for whiptail (needed for wizard)
if ! command -v whiptail &> /dev/null; then
    echo -e "${BLUE}[*] Installing whiptail...${NC}"
    apt-get update && apt-get install -y whiptail
fi
echo -e "${GREEN}[OK]${NC} Whiptail is installed"

echo ""

# 2. Clone/Update Repository
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}[*] Updating existing repository...${NC}"
    cd "$INSTALL_DIR"
    # Stash any local changes
    git stash --quiet 2>/dev/null || true
    git fetch origin "$BRANCH"
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
    echo -e "${GREEN}[OK]${NC} Repository updated"
else
    echo -e "${BLUE}[*] Cloning repository...${NC}"
    git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo -e "${GREEN}[OK]${NC} Repository cloned to $INSTALL_DIR"
fi

echo ""

# 3. Ensure scripts are executable
echo -e "${BLUE}[*] Setting up scripts...${NC}"
chmod +x install/utils/configure.sh 2>/dev/null || true
chmod +x install/utils/run_manifest.sh 2>/dev/null || true
chmod +x install/utils/doctor.sh 2>/dev/null || true
chmod +x run_1.sh run_2.sh 2>/dev/null || true

# 4. Run Configuration Wizard
echo ""
echo -e "${BLUE}[*] Starting configuration wizard...${NC}"
echo ""

if [[ "$VIBE_MODE" == "true" ]]; then
    echo -e "${YELLOW}[*] Vibe mode enabled - using sensible defaults${NC}"
    ./install/utils/configure.sh --vibe "$@"
else
    ./install/utils/configure.sh "$@"
fi

# 5. After configure.sh, check if Phase 1 was run
# If not, offer to run it now
if [[ -f "./install_phase1.sh" ]]; then
    echo ""
    echo -e "${BLUE}[*] Configuration complete.${NC}"
    echo ""
    echo "Generated installation scripts:"
    echo "  - install_phase1.sh (system hardening, run as root)"
    echo "  - install_phase2.sh (client installation, run as new user)"
    echo ""

    # In non-interactive vibe mode, just remind user what to do
    if [[ "$VIBE_MODE" == "true" ]]; then
        echo -e "${YELLOW}==================================================${NC}"
        echo -e "${YELLOW}  Next Steps:${NC}"
        echo -e "${YELLOW}==================================================${NC}"
        echo ""
        echo "1. Run Phase 1 (as root):"
        echo "   sudo ./install_phase1.sh"
        echo ""
        echo "2. After Phase 1 completes, REBOOT:"
        echo "   sudo reboot"
        echo ""
        echo "3. SSH back in as the NEW USER (credentials in /root/handoff_info.txt)"
        echo ""
        echo "4. Run Phase 2 (as new user):"
        echo "   cd ~/.eth2-quickstart"
        echo "   ./install_phase2.sh"
        echo ""
    fi
fi
