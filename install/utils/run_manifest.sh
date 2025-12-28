#!/bin/bash

# Manifest Runner for Eth2 Quick Start
# Executes the installation manifest with logging, progress tracking, and error handling

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
MANIFEST_FILE="$ROOT_DIR/install_manifest.sh"
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

# Parse arguments
DRY_RUN=false
VERBOSE=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Eth2 Quick Start - Manifest Runner"
            echo ""
            echo "Usage: ./run_manifest.sh [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run   Show what would be executed without running"
            echo "  --verbose   Show detailed output"
            echo "  --help, -h  Show this help message"
            exit 0
            ;;
    esac
done

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Log to console with colors
    case "$level" in
        "INFO")  echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $message" ;;
    esac
}

# Error handler
handle_error() {
    local exit_code=$?
    local line_number=$1

    log "ERROR" "Installation failed at line $line_number with exit code $exit_code"
    log "ERROR" "Check the log file for details: $LOG_FILE"
    echo ""
    echo -e "${RED}==================================================${NC}"
    echo -e "${RED}  Installation Failed${NC}"
    echo -e "${RED}==================================================${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo "  1. Check the log file: $LOG_FILE"
    echo "  2. Run the doctor script: ./install/utils/doctor.sh"
    echo "  3. Check system requirements: RAM >= 8GB, Disk >= 500GB"
    echo ""
    echo "To retry, run:"
    echo "  sudo ./install/utils/run_manifest.sh"
    echo ""

    exit $exit_code
}

# Progress tracking
TOTAL_PHASES=4
CURRENT_PHASE=0

progress() {
    CURRENT_PHASE=$((CURRENT_PHASE + 1))
    local percent=$((CURRENT_PHASE * 100 / TOTAL_PHASES))
    echo ""
    echo -e "${BLUE}[${CURRENT_PHASE}/${TOTAL_PHASES}] ($percent%)${NC} $1"
    log "INFO" "Phase $CURRENT_PHASE: $1"
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root"
        echo -e "${RED}Error: Please run with sudo${NC}"
        exit 1
    fi

    # Check if manifest exists
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log "ERROR" "Manifest file not found: $MANIFEST_FILE"
        echo -e "${RED}Error: Manifest file not found${NC}"
        echo "Please run ./install/utils/configure.sh first to generate the manifest."
        exit 1
    fi

    # Check disk space (require at least 100GB free)
    local free_space
    free_space=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $free_space -lt 100 ]]; then
        log "WARN" "Low disk space: ${free_space}GB free (recommend 500GB+)"
        echo -e "${YELLOW}Warning: Low disk space. Ethereum nodes require 500GB+ storage.${NC}"
    fi

    log "INFO" "Prerequisites check passed"
}

# Create log directory
mkdir -p "$LOG_DIR"

# Main execution
echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Eth2 Quick Start - Manifest Runner${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo ""

# Check prerequisites
check_prerequisites

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY RUN] Showing what would be executed:${NC}"
    echo ""
    echo "--- Manifest Contents ---"
    cat "$MANIFEST_FILE"
    echo "--- End of Manifest ---"
    exit 0
fi

# Set up error trap
trap 'handle_error $LINENO' ERR

# Log start
log "INFO" "Starting installation from manifest: $MANIFEST_FILE"

# Source configuration
cd "$ROOT_DIR"
# shellcheck source=/dev/null
source "$ROOT_DIR/exports.sh"

if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    log "INFO" "Loading user configuration..."
    # shellcheck source=/dev/null
    source "$ROOT_DIR/config/user_config.env"
fi

# Display configuration summary
echo "Configuration:"
echo "  Network:    ${ETH_NETWORK:-mainnet}"
echo "  Execution:  ${EXEC_CLIENT:-not set}"
echo "  Consensus:  ${CONS_CLIENT:-not set}"
echo "  MEV:        ${MEV_SOLUTION:-not set}"
echo ""

# Confirm before proceeding
echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
read -r

# Execute phases
log "INFO" "Beginning installation phases..."

progress "System Setup"
log "DEBUG" "Running run_1.sh"
./run_1.sh 2>&1 | tee -a "$LOG_FILE"

if [[ -n "${EXEC_CLIENT:-}" ]]; then
    progress "Execution Client ($EXEC_CLIENT)"
    log "DEBUG" "Installing execution client: $EXEC_CLIENT"
    if [[ -f "./install/execution/$EXEC_CLIENT.sh" ]]; then
        ./install/execution/"$EXEC_CLIENT".sh 2>&1 | tee -a "$LOG_FILE"
    else
        log "WARN" "Execution client script not found: $EXEC_CLIENT.sh"
    fi
fi

if [[ -n "${CONS_CLIENT:-}" ]]; then
    progress "Consensus Client ($CONS_CLIENT)"
    log "DEBUG" "Installing consensus client: $CONS_CLIENT"
    if [[ -f "./install/consensus/$CONS_CLIENT.sh" ]]; then
        ./install/consensus/"$CONS_CLIENT".sh 2>&1 | tee -a "$LOG_FILE"
    else
        log "WARN" "Consensus client script not found: $CONS_CLIENT.sh"
    fi
fi

progress "MEV Solution (${MEV_SOLUTION:-none})"
case "${MEV_SOLUTION:-none}" in
    "mev-boost")
        log "DEBUG" "Installing MEV-Boost"
        if [[ -f "./install/mev/install_mev_boost.sh" ]]; then
            ./install/mev/install_mev_boost.sh 2>&1 | tee -a "$LOG_FILE"
        fi
        ;;
    "commit-boost")
        log "DEBUG" "Installing Commit-Boost"
        if [[ -f "./install/mev/install_commit_boost.sh" ]]; then
            ./install/mev/install_commit_boost.sh 2>&1 | tee -a "$LOG_FILE"
        fi
        ;;
    *)
        log "INFO" "Skipping MEV installation"
        ;;
esac

# Success
log "INFO" "Installation completed successfully"

echo ""
echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo ""
echo "Next steps:"
echo "  1. Verify installation: ./install/utils/doctor.sh"
echo "  2. Check service status: sudo systemctl status eth1 cl"
echo "  3. View logs: sudo journalctl -u eth1 -u cl -f"
echo ""
