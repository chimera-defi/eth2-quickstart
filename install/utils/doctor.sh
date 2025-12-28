#!/bin/bash

# Doctor Script for Eth2 Quick Start
# Verifies installation health and diagnoses common issues

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

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

# Parse arguments
VERBOSE=false
FIX_MODE=false
for arg in "$@"; do
    case $arg in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --fix)
            FIX_MODE=true
            shift
            ;;
        --help|-h)
            echo "Eth2 Quick Start - Doctor (Health Check)"
            echo ""
            echo "Usage: ./doctor.sh [options]"
            echo ""
            echo "Options:"
            echo "  --verbose   Show detailed output"
            echo "  --fix       Attempt to fix issues automatically"
            echo "  --help, -h  Show this help message"
            exit 0
            ;;
    esac
done

# Check functions
check_pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

check_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    CHECKS_WARNED=$((CHECKS_WARNED + 1))
}

check_info() {
    echo -e "  ${BLUE}[INFO]${NC} $1"
}

# Header
echo ""
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Eth2 Quick Start - Doctor${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Source configuration if available
if [[ -f "$ROOT_DIR/exports.sh" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT_DIR/exports.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT_DIR/config/user_config.env" 2>/dev/null || true
fi

# ============================================================================
# SYSTEM CHECKS
# ============================================================================
echo -e "${BLUE}[1/7] System Requirements${NC}"

# Check RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [[ $TOTAL_RAM -ge 16 ]]; then
    check_pass "RAM: ${TOTAL_RAM}GB (recommended: 16GB+)"
elif [[ $TOTAL_RAM -ge 8 ]]; then
    check_warn "RAM: ${TOTAL_RAM}GB (minimum met, 16GB+ recommended)"
else
    check_fail "RAM: ${TOTAL_RAM}GB (minimum 8GB required)"
fi

# Check disk space
FREE_DISK=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
if [[ $FREE_DISK -ge 500 ]]; then
    check_pass "Disk Space: ${FREE_DISK}GB free (recommended: 500GB+)"
elif [[ $FREE_DISK -ge 200 ]]; then
    check_warn "Disk Space: ${FREE_DISK}GB free (low, 500GB+ recommended)"
else
    check_fail "Disk Space: ${FREE_DISK}GB free (critical, need 500GB+)"
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [[ $CPU_CORES -ge 4 ]]; then
    check_pass "CPU Cores: $CPU_CORES (recommended: 4+)"
else
    check_warn "CPU Cores: $CPU_CORES (4+ recommended)"
fi

# Check OS
if [[ -f /etc/os-release ]]; then
    OS_NAME=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
    OS_ID=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    case "$OS_ID" in
        ubuntu|debian)
            check_pass "OS: $OS_NAME"
            ;;
        *)
            check_warn "OS: $OS_NAME (Ubuntu/Debian recommended)"
            ;;
    esac
fi

echo ""

# ============================================================================
# CONFIGURATION CHECKS
# ============================================================================
echo -e "${BLUE}[2/7] Configuration${NC}"

# Check exports.sh
if [[ -f "$ROOT_DIR/exports.sh" ]]; then
    check_pass "exports.sh exists"
else
    check_fail "exports.sh not found"
fi

# Check user config
if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    check_pass "User config exists: config/user_config.env"
    if [[ "$VERBOSE" == "true" ]]; then
        echo "    Network: ${ETH_NETWORK:-not set}"
        echo "    Execution: ${EXEC_CLIENT:-not set}"
        echo "    Consensus: ${CONS_CLIENT:-not set}"
    fi
else
    check_info "User config not found (run configure.sh to create)"
fi

# Check manifest
if [[ -f "$ROOT_DIR/install_manifest.sh" ]]; then
    check_pass "Install manifest exists"
else
    check_info "Install manifest not found (run configure.sh to create)"
fi

# Check JWT secret
JWT_PATH="$HOME/secrets/jwt.hex"
if [[ -f "$JWT_PATH" ]]; then
    JWT_LENGTH=$(wc -c < "$JWT_PATH" | tr -d ' ')
    if [[ $JWT_LENGTH -ge 64 ]]; then
        check_pass "JWT secret exists and valid"
    else
        check_fail "JWT secret too short ($JWT_LENGTH chars, need 64)"
    fi
else
    check_warn "JWT secret not found at $JWT_PATH"
fi

echo ""

# ============================================================================
# SERVICE CHECKS
# ============================================================================
echo -e "${BLUE}[3/7] Services${NC}"

check_service() {
    local service_name="$1"
    local description="$2"

    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        check_pass "$description ($service_name) is running"
    elif systemctl is-enabled --quiet "$service_name" 2>/dev/null; then
        check_warn "$description ($service_name) is enabled but not running"
    elif [[ -f "/etc/systemd/system/${service_name}.service" ]]; then
        check_warn "$description ($service_name) is installed but not enabled"
    else
        check_info "$description ($service_name) not installed"
    fi
}

check_service "eth1" "Execution Client"
check_service "cl" "Consensus Client"
check_service "validator" "Validator Client"
check_service "mev-boost" "MEV-Boost"

echo ""

# ============================================================================
# PORT CHECKS
# ============================================================================
echo -e "${BLUE}[4/7] Network Ports${NC}"

check_port() {
    local port="$1"
    local description="$2"
    local protocol="${3:-tcp}"

    # Use ss if available, otherwise fall back to netstat or /proc/net
    local port_in_use=false
    if command -v ss &> /dev/null; then
        if ss -ln 2>/dev/null | grep -q ":$port "; then
            port_in_use=true
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            port_in_use=true
        fi
    else
        # Fall back to checking /proc/net/tcp
        local hex_port
        hex_port=$(printf '%04X' "$port")
        if grep -q ":$hex_port " /proc/net/tcp 2>/dev/null; then
            port_in_use=true
        fi
    fi

    if [[ "$port_in_use" == "true" ]]; then
        check_pass "Port $port ($description) is in use"
    else
        check_info "Port $port ($description) not in use"
    fi
}

# Common Ethereum ports
check_port 8545 "Execution RPC"
check_port 8551 "Engine API (JWT)"
check_port 5052 "Beacon API"
check_port 30303 "Execution P2P"
check_port 9000 "Consensus P2P"
check_port 18550 "MEV-Boost"

echo ""

# ============================================================================
# FIREWALL CHECKS
# ============================================================================
echo -e "${BLUE}[5/7] Firewall${NC}"

if command -v ufw &> /dev/null; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        check_pass "UFW firewall is active"

        # Check if key ports are allowed
        if ufw status | grep -q "30303"; then
            check_pass "Port 30303 (Execution P2P) is allowed"
        else
            check_warn "Port 30303 (Execution P2P) may be blocked"
        fi

        if ufw status | grep -q "9000"; then
            check_pass "Port 9000 (Consensus P2P) is allowed"
        else
            check_warn "Port 9000 (Consensus P2P) may be blocked"
        fi
    else
        check_warn "UFW firewall is not active"
    fi
else
    check_info "UFW not installed"
fi

echo ""

# ============================================================================
# SYNC STATUS CHECKS
# ============================================================================
echo -e "${BLUE}[6/7] Sync Status${NC}"

# Check execution client sync
if command -v curl &> /dev/null; then
    # Try to query execution client
    if EXEC_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        http://localhost:8545 2>/dev/null); then

        if echo "$EXEC_RESPONSE" | grep -q '"result":false'; then
            check_pass "Execution client is synced"
        elif echo "$EXEC_RESPONSE" | grep -q '"result"'; then
            check_info "Execution client is syncing..."
        else
            check_info "Could not determine execution client sync status"
        fi
    else
        check_info "Execution client RPC not responding"
    fi

    # Try to query beacon node
    if BEACON_RESPONSE=$(curl -s http://localhost:5052/eth/v1/node/syncing 2>/dev/null); then
        if echo "$BEACON_RESPONSE" | grep -q '"is_syncing":false'; then
            check_pass "Beacon node is synced"
        elif echo "$BEACON_RESPONSE" | grep -q '"is_syncing":true'; then
            check_info "Beacon node is syncing..."
        else
            check_info "Could not determine beacon node sync status"
        fi
    else
        check_info "Beacon node API not responding"
    fi
else
    check_info "curl not available for sync checks"
fi

echo ""

# ============================================================================
# COMMON ISSUES CHECKS
# ============================================================================
echo -e "${BLUE}[7/7] Common Issues${NC}"

# Check for common log errors
if [[ -d "$ROOT_DIR/logs" ]]; then
    RECENT_LOG=$(ls -t "$ROOT_DIR/logs"/*.log 2>/dev/null | head -1)
    if [[ -n "$RECENT_LOG" ]]; then
        ERROR_COUNT=$(grep -c "ERROR" "$RECENT_LOG" 2>/dev/null || echo "0")
        if [[ $ERROR_COUNT -eq 0 ]]; then
            check_pass "No errors in recent install log"
        else
            check_warn "$ERROR_COUNT errors in recent install log"
        fi
    fi
fi

# Check time sync
if timedatectl status 2>/dev/null | grep -q "synchronized: yes"; then
    check_pass "System time is synchronized"
else
    check_warn "System time may not be synchronized (important for validators)"
fi

# Check disk I/O (simple check)
if [[ -d "/var/lib" ]]; then
    if touch /var/lib/.eth2_io_test 2>/dev/null; then
        rm /var/lib/.eth2_io_test
        check_pass "Disk I/O appears normal"
    else
        check_warn "May have disk I/O issues"
    fi
fi

echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $CHECKS_PASSED"
echo -e "  ${YELLOW}Warnings:${NC} $CHECKS_WARNED"
echo -e "  ${RED}Failed:${NC}  $CHECKS_FAILED"
echo ""

if [[ $CHECKS_FAILED -eq 0 && $CHECKS_WARNED -eq 0 ]]; then
    echo -e "${GREEN}All checks passed! Your node appears healthy.${NC}"
elif [[ $CHECKS_FAILED -eq 0 ]]; then
    echo -e "${YELLOW}Some warnings detected. Review the items above.${NC}"
else
    echo -e "${RED}Some checks failed. Please address the issues above.${NC}"
fi

echo ""
echo "For detailed logs, check:"
echo "  - Install logs: $ROOT_DIR/logs/"
echo "  - Service logs: sudo journalctl -u eth1 -u cl -f"
echo ""

# Exit with appropriate code
if [[ $CHECKS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
