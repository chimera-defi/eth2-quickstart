#!/bin/bash

# Eth2 Quick Start - Health Check (Doctor) Script
# Verifies system health and installation status
#
# This script checks:
# 1. System requirements (RAM, disk, architecture)
# 2. Network connectivity
# 3. Service status
# 4. Configuration validity
# 5. Port availability
# 6. JWT secret status
# 7. Client sync status

set -e

# =============================================================================
# SETUP
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

# Source common functions for logging (required - no fallback)
# shellcheck source=../../lib/common_functions.sh
source "$ROOT_DIR/lib/common_functions.sh"

# Source exports for configuration values
# shellcheck source=../../exports.sh
if [[ -f "$ROOT_DIR/exports.sh" ]]; then
    source "$ROOT_DIR/exports.sh" 2>/dev/null || true
fi

# Source user config if available
if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT_DIR/config/user_config.env" 2>/dev/null || true
fi

JSON_OUTPUT=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_OUTPUT=true
            ;;
        --help|-h)
            echo "Usage: ./install/utils/doctor.sh [--json]"
            echo "  --json    Output machine-readable JSON summary"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: ./install/utils/doctor.sh [--json]" >&2
            exit 1
            ;;
    esac
    shift
done

# =============================================================================
# TEST TRACKING
# =============================================================================

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0
CHECK_NAMES=()
CHECK_STATUSES=()
CHECK_DETAILS=()

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/}
    printf '%s' "$s"
}

record_result() {
    local status="$1"
    local test_name="$2"
    local details="${3:-}"
    CHECK_STATUSES+=("$status")
    CHECK_NAMES+=("$test_name")
    CHECK_DETAILS+=("$details")
}

record_pass() {
    local test_name="$1"
    record_result "pass" "$test_name"
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "  ${GREEN}✓${NC} $test_name"
    fi
    ((TESTS_PASSED+=1))
}

record_fail() {
    local test_name="$1"
    local details="${2:-}"
    record_result "fail" "$test_name" "$details"
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "  ${RED}✗${NC} $test_name"
        [[ -n "$details" ]] && echo -e "    ${RED}→ $details${NC}"
    fi
    ((TESTS_FAILED+=1))
}

record_warn() {
    local test_name="$1"
    local details="${2:-}"
    record_result "warn" "$test_name" "$details"
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        echo -e "  ${YELLOW}⚠${NC} $test_name"
        [[ -n "$details" ]] && echo -e "    ${YELLOW}→ $details${NC}"
    fi
    ((TESTS_WARNED+=1))
}

# =============================================================================
# HELPER FUNCTIONS (uses check_port, check_service_status from common_functions.sh)
# =============================================================================

# Alias for backward compatibility
check_service() {
    check_service_status "$1"
}

# =============================================================================
# HEALTH CHECKS
# =============================================================================

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}  Eth2 Quick Start - Health Check (Doctor)${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo ""
fi

# -----------------------------------------------------------------------------
# 1. System Requirements
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[1/7] System Requirements${NC}"
fi

# Check RAM
total_ram_gb=$(free -g | awk 'NR==2{print $2}')
if [[ $total_ram_gb -ge 16 ]]; then
    record_pass "RAM: ${total_ram_gb}GB (recommended: 16GB+)"
elif [[ $total_ram_gb -ge 8 ]]; then
    record_warn "RAM: ${total_ram_gb}GB" "Minimum met, but 16GB+ recommended"
else
    record_fail "RAM: ${total_ram_gb}GB" "Minimum 8GB required, 16GB+ recommended"
fi

# Check disk space
available_disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
if [[ $available_disk_gb -ge 500 ]]; then
    record_pass "Disk: ${available_disk_gb}GB available (recommended: 500GB+)"
elif [[ $available_disk_gb -ge 200 ]]; then
    record_warn "Disk: ${available_disk_gb}GB available" "Minimum met, but 500GB+ recommended for mainnet"
else
    record_fail "Disk: ${available_disk_gb}GB available" "Minimum 200GB required, 500GB+ recommended"
fi

# Check architecture
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    record_pass "Architecture: $arch"
else
    record_fail "Architecture: $arch" "x86_64 required"
fi

# Check OS
if [[ -f /etc/os-release ]]; then
    os_name=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
    os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
    if [[ "$os_id" == "ubuntu" ]] || [[ "$os_id" == "debian" ]]; then
        record_pass "OS: $os_name"
    else
        record_warn "OS: $os_name" "Ubuntu/Debian recommended"
    fi
fi

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# -----------------------------------------------------------------------------
# 2. Network Connectivity
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[2/7] Network Connectivity${NC}"
fi

# Check internet connectivity
if curl -sf --connect-timeout 5 https://api.github.com >/dev/null 2>&1; then
    record_pass "Internet connectivity (GitHub API reachable)"
else
    record_fail "Internet connectivity" "Cannot reach GitHub API"
fi

# Check Ethereum network connectivity
if curl -sf --connect-timeout 5 https://beaconstate.ethstaker.cc >/dev/null 2>&1; then
    record_pass "Beacon checkpoint sync endpoint reachable"
else
    record_warn "Beacon checkpoint sync endpoint" "May affect initial sync speed"
fi

# Check DNS resolution
if host eth.llamarpc.com >/dev/null 2>&1; then
    record_pass "DNS resolution working"
elif nslookup eth.llamarpc.com >/dev/null 2>&1; then
    record_pass "DNS resolution working"
else
    record_warn "DNS resolution" "Could not verify DNS"
fi

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# -----------------------------------------------------------------------------
# 3. Service Status
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[3/7] Service Status${NC}"
fi

# Check execution client service
eth1_status=$(check_service "eth1")
case "$eth1_status" in
    "running")
        record_pass "Execution client (eth1): Running"
        ;;
    "stopped")
        record_warn "Execution client (eth1): Stopped but enabled"
        ;;
    "disabled")
        record_warn "Execution client (eth1): Disabled"
        ;;
    "not_installed")
        record_warn "Execution client (eth1): Not installed"
        ;;
esac

# Check consensus client service
cl_status=$(check_service "cl")
case "$cl_status" in
    "running")
        record_pass "Consensus client (cl): Running"
        ;;
    "stopped")
        record_warn "Consensus client (cl): Stopped but enabled"
        ;;
    "disabled")
        record_warn "Consensus client (cl): Disabled"
        ;;
    "not_installed")
        record_warn "Consensus client (cl): Not installed"
        ;;
esac

# Check validator service
validator_status=$(check_service "validator")
case "$validator_status" in
    "running")
        record_pass "Validator: Running"
        ;;
    "stopped")
        record_warn "Validator: Stopped but enabled"
        ;;
    "disabled")
        if [[ "$JSON_OUTPUT" == "false" ]]; then
            log_info "  - Validator: Not configured (optional)"
        fi
        ;;
    "not_installed")
        if [[ "$JSON_OUTPUT" == "false" ]]; then
            log_info "  - Validator: Not installed (optional)"
        fi
        ;;
esac

# Check MEV service
mev_status=$(check_service "mev")
case "$mev_status" in
    "running")
        record_pass "MEV service (mev): Running"
        ;;
    "stopped")
        record_warn "MEV service (mev): Stopped but enabled"
        ;;
    "disabled"|"not_installed")
        if [[ "$JSON_OUTPUT" == "false" ]]; then
            log_info "  - MEV service (mev): Not configured (optional)"
        fi
        ;;
esac

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# -----------------------------------------------------------------------------
# 4. Configuration Files
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[4/7] Configuration${NC}"
fi

# Check exports.sh
if [[ -f "$ROOT_DIR/exports.sh" ]]; then
    record_pass "exports.sh exists"
else
    record_fail "exports.sh missing" "Required configuration file"
fi

# Check user config
if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    record_pass "User configuration (config/user_config.env)"
else
    record_warn "User configuration not found" "Run configure.sh to generate"
fi

# Check fee recipient is set
if [[ -n "${FEE_RECIPIENT:-}" ]] && [[ "$FEE_RECIPIENT" != "0x0000000000000000000000000000000000000000" ]]; then
    record_pass "Fee recipient configured: ${FEE_RECIPIENT:0:10}..."
else
    record_warn "Fee recipient not configured" "Set in config/user_config.env for validator rewards"
fi

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# -----------------------------------------------------------------------------
# 5. Port Availability
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[5/7] Port Status${NC}"
fi

# Execution client ports
if check_port 30303; then
    record_pass "P2P port 30303: In use (expected if eth1 running)"
else
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "  - P2P port 30303: Available"
    fi
fi

if check_port 8545; then
    record_pass "HTTP RPC port 8545: In use"
else
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "  - HTTP RPC port 8545: Available"
    fi
fi

if check_port 8551; then
    record_pass "Engine API port 8551: In use (expected if eth1 running)"
else
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "  - Engine API port 8551: Available"
    fi
fi

# Consensus client ports
if check_port 9000; then
    record_pass "Beacon P2P port 9000: In use (expected if cl running)"
else
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "  - Beacon P2P port 9000: Available"
    fi
fi

if check_port 5052; then
    record_pass "Beacon API port 5052: In use"
else
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "  - Beacon API port 5052: Available"
    fi
fi

# MEV-Boost port
if check_port 18550; then
    record_pass "MEV-Boost port 18550: In use"
else
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        log_info "  - MEV service port 18550: Available"
    fi
fi

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# -----------------------------------------------------------------------------
# 6. JWT Secret
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[6/7] JWT Authentication${NC}"
fi

jwt_locations=(
    "$HOME/secrets/jwt.hex"
    "/var/lib/ethereum/jwt.hex"
    "/etc/ethereum/jwt.hex"
)

jwt_found=false
for jwt_path in "${jwt_locations[@]}"; do
    if [[ -f "$jwt_path" ]]; then
        jwt_found=true
        jwt_perms=$(stat -c %a "$jwt_path" 2>/dev/null || stat -f %p "$jwt_path" 2>/dev/null | tail -c 4)
        
        if [[ "$jwt_perms" == "600" ]] || [[ "$jwt_perms" == "0600" ]]; then
            record_pass "JWT secret: $jwt_path (permissions: $jwt_perms)"
        else
            record_warn "JWT secret: $jwt_path" "Permissions should be 600, got $jwt_perms"
        fi
        break
    fi
done

if [[ "$jwt_found" == "false" ]]; then
    record_warn "JWT secret not found" "Will be created during client installation"
fi

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# -----------------------------------------------------------------------------
# 7. Security Status
# -----------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo -e "${BLUE}[7/7] Security Status${NC}"
fi

# Check firewall
if command -v ufw &>/dev/null; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        record_pass "Firewall (UFW): Active"
    else
        record_warn "Firewall (UFW): Inactive" "Run: sudo ufw enable"
    fi
else
    record_warn "Firewall (UFW): Not installed"
fi

# Check fail2ban
f2b_status=$(check_service "fail2ban")
if [[ "$f2b_status" == "running" ]]; then
    record_pass "Fail2ban: Running"
else
    record_warn "Fail2ban: Not running" "Recommended for SSH protection"
fi

# Check SSH port
ssh_port=$(grep "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
if [[ "$ssh_port" != "22" ]]; then
    record_pass "SSH port: $ssh_port (non-default)"
else
    record_warn "SSH port: 22 (default)" "Consider changing for security"
fi

# Check root login
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    record_pass "Root SSH login: Disabled"
elif grep -q "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null; then
    root_login=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    record_warn "Root SSH login: $root_login" "Recommend disabling"
else
    record_warn "Root SSH login: Default (may be enabled)"
fi

if [[ "$JSON_OUTPUT" == "false" ]]; then
    echo ""
fi

# =============================================================================
# SUMMARY
# =============================================================================

if [[ "$JSON_OUTPUT" == "true" ]]; then
    overall_status="pass"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        overall_status="fail"
    elif [[ $TESTS_WARNED -gt 0 ]]; then
        overall_status="warn"
    fi

    echo "{"
    echo "  \"summary\": {"
    echo "    \"passed\": $TESTS_PASSED,"
    echo "    \"warnings\": $TESTS_WARNED,"
    echo "    \"failed\": $TESTS_FAILED,"
    echo "    \"status\": \"${overall_status}\""
    echo "  },"
    echo "  \"checks\": ["
    for i in "${!CHECK_NAMES[@]}"; do
        name_escaped=$(json_escape "${CHECK_NAMES[$i]}")
        details_escaped=$(json_escape "${CHECK_DETAILS[$i]}")
        echo -n "    {\"status\":\"${CHECK_STATUSES[$i]}\",\"name\":\"${name_escaped}\",\"details\":\"${details_escaped}\"}"
        if [[ $i -lt $((${#CHECK_NAMES[@]} - 1)) ]]; then
            echo ","
        else
            echo
        fi
    done
    echo "  ]"
    echo "}"
else
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}  Health Check Summary${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo ""
    echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "  ${YELLOW}Warnings:${NC} $TESTS_WARNED"
    echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        if [[ $TESTS_WARNED -eq 0 ]]; then
            echo -e "${GREEN}✓ All checks passed! Your system is ready.${NC}"
        else
            echo -e "${YELLOW}⚠ System is functional but has warnings to review.${NC}"
        fi
    else
        echo -e "${RED}✗ Some checks failed. Please address the issues above.${NC}"
    fi
fi

if [[ $TESTS_FAILED -eq 0 ]]; then
    exit 0
else
    exit 1
fi
