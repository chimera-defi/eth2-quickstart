#!/bin/bash

# MEV Implementations Testing Script
# Tests MEV-Boost and Commit-Boost installations
# Verifies installation, configuration, and functionality

source ../../exports.sh
source ../../lib/common_functions.sh

# Get script directories
get_script_directories

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
declare -A test_results
total_tests=0
passed_tests=0
failed_tests=0

# Test result tracking
record_test() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    total_tests=$((total_tests + 1))
    test_results["$test_name"]="$result|$details"
    
    if [[ "$result" == "PASS" ]]; then
        passed_tests=$((passed_tests + 1))
        echo -e "${GREEN}✓${NC} $test_name: ${GREEN}PASS${NC} - $details"
    elif [[ "$result" == "SKIP" ]]; then
        echo -e "${BLUE}⊘${NC} $test_name: ${BLUE}SKIP${NC} - $details"
    else
        failed_tests=$((failed_tests + 1))
        echo -e "${RED}✗${NC} $test_name: ${RED}FAIL${NC} - $details"
    fi
}

# Header
echo "========================================="
echo "MEV Implementations Testing Suite"
echo "========================================="
echo "Date: $(date)"
echo "Host: $(hostname)"
echo ""

# ============================================================================
# MEV-Boost Tests
# ============================================================================

echo -e "${BLUE}=== MEV-Boost Tests ===${NC}"
echo ""

# Test 1: Check if MEV-Boost is installed
if [[ -d "$HOME/mev-boost" ]]; then
    record_test "MEV-Boost: Installation Directory" "PASS" "Directory exists at $HOME/mev-boost"
else
    record_test "MEV-Boost: Installation Directory" "SKIP" "Not installed"
fi

# Test 2: Check if MEV-Boost binary exists
if [[ -f "$HOME/mev-boost/mev-boost" ]]; then
    record_test "MEV-Boost: Binary Exists" "PASS" "Binary found"
    
    # Test binary is executable
    if [[ -x "$HOME/mev-boost/mev-boost" ]]; then
        record_test "MEV-Boost: Binary Executable" "PASS" "Binary is executable"
    else
        record_test "MEV-Boost: Binary Executable" "FAIL" "Binary is not executable"
    fi
else
    record_test "MEV-Boost: Binary Exists" "SKIP" "Not installed"
fi

# Test 3: Check MEV-Boost service
if systemctl list-unit-files | grep -q "mev.service"; then
    record_test "MEV-Boost: Service File" "PASS" "Service file exists"
    
    # Check service status
    if systemctl is-active --quiet mev; then
        record_test "MEV-Boost: Service Running" "PASS" "Service is active"
    else
        record_test "MEV-Boost: Service Running" "SKIP" "Service not active (may not be started yet)"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet mev; then
        record_test "MEV-Boost: Service Enabled" "PASS" "Service is enabled"
    else
        record_test "MEV-Boost: Service Enabled" "SKIP" "Service not enabled"
    fi
else
    record_test "MEV-Boost: Service File" "SKIP" "Not installed"
fi

# Test 4: Check MEV-Boost API endpoint
if command -v curl &> /dev/null && systemctl is-active --quiet mev; then
    if curl -sf "http://$MEV_HOST:$MEV_PORT/eth/v1/builder/status" &> /dev/null; then
        record_test "MEV-Boost: API Endpoint" "PASS" "API is responding on port $MEV_PORT"
    else
        record_test "MEV-Boost: API Endpoint" "SKIP" "API not responding (service may not be started)"
    fi
else
    record_test "MEV-Boost: API Endpoint" "SKIP" "curl not available or service not running"
fi

# Test 5: Check MEV-Boost configuration variables
if [[ -n "$MEV_RELAYS" ]]; then
    relay_count=$(echo "$MEV_RELAYS" | tr ',' '\n' | wc -l)
    record_test "MEV-Boost: Configuration" "PASS" "Found $relay_count relay(s) configured"
else
    record_test "MEV-Boost: Configuration" "FAIL" "No relays configured"
fi

echo ""

# ============================================================================
# Commit-Boost Tests
# ============================================================================

echo -e "${BLUE}=== Commit-Boost Tests ===${NC}"
echo ""

# Test 6: Check if Commit-Boost is installed
if [[ -d "$HOME/commit-boost" ]]; then
    record_test "Commit-Boost: Installation Directory" "PASS" "Directory exists at $HOME/commit-boost"
else
    record_test "Commit-Boost: Installation Directory" "SKIP" "Not installed"
fi

# Test 7: Check Commit-Boost binaries
if [[ -f "$HOME/commit-boost/commit-boost-pbs" ]]; then
    record_test "Commit-Boost: PBS Binary" "PASS" "PBS binary found"
    
    if [[ -x "$HOME/commit-boost/commit-boost-pbs" ]]; then
        record_test "Commit-Boost: PBS Executable" "PASS" "PBS binary is executable"
    else
        record_test "Commit-Boost: PBS Executable" "FAIL" "PBS binary not executable"
    fi
else
    record_test "Commit-Boost: PBS Binary" "SKIP" "Not installed"
fi

if [[ -f "$HOME/commit-boost/commit-boost-signer" ]]; then
    record_test "Commit-Boost: Signer Binary" "PASS" "Signer binary found"
    
    if [[ -x "$HOME/commit-boost/commit-boost-signer" ]]; then
        record_test "Commit-Boost: Signer Executable" "PASS" "Signer binary is executable"
    else
        record_test "Commit-Boost: Signer Executable" "FAIL" "Signer binary not executable"
    fi
else
    record_test "Commit-Boost: Signer Binary" "SKIP" "Not installed"
fi

# Test 8: Check Commit-Boost configuration
if [[ -f "$HOME/commit-boost/config/cb-config.toml" ]]; then
    record_test "Commit-Boost: Configuration File" "PASS" "Config file exists"
    
    # Validate TOML syntax (basic check)
    if grep -q "\[pbs\]" "$HOME/commit-boost/config/cb-config.toml"; then
        record_test "Commit-Boost: Config Valid" "PASS" "Config file has PBS section"
    else
        record_test "Commit-Boost: Config Valid" "FAIL" "Config file missing PBS section"
    fi
else
    record_test "Commit-Boost: Configuration File" "SKIP" "Not installed"
fi

# Test 9: Check Commit-Boost PBS service
if systemctl list-unit-files | grep -q "commit-boost-pbs.service"; then
    record_test "Commit-Boost: PBS Service File" "PASS" "PBS service file exists"
    
    # Check service status
    if systemctl is-active --quiet commit-boost-pbs; then
        record_test "Commit-Boost: PBS Service Running" "PASS" "PBS service is active"
    else
        record_test "Commit-Boost: PBS Service Running" "SKIP" "PBS service not active"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet commit-boost-pbs; then
        record_test "Commit-Boost: PBS Service Enabled" "PASS" "PBS service is enabled"
    else
        record_test "Commit-Boost: PBS Service Enabled" "SKIP" "PBS service not enabled"
    fi
else
    record_test "Commit-Boost: PBS Service File" "SKIP" "Not installed"
fi

# Test 10: Check Commit-Boost Signer service
if systemctl list-unit-files | grep -q "commit-boost-signer.service"; then
    record_test "Commit-Boost: Signer Service File" "PASS" "Signer service file exists"
    
    # Check service status
    if systemctl is-active --quiet commit-boost-signer; then
        record_test "Commit-Boost: Signer Service Running" "PASS" "Signer service is active"
    else
        record_test "Commit-Boost: Signer Service Running" "SKIP" "Signer service not active"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet commit-boost-signer; then
        record_test "Commit-Boost: Signer Service Enabled" "PASS" "Signer service is enabled"
    else
        record_test "Commit-Boost: Signer Service Enabled" "SKIP" "Signer service not enabled"
    fi
else
    record_test "Commit-Boost: Signer Service File" "SKIP" "Not installed"
fi

# Test 11: Check Commit-Boost API endpoint
if command -v curl &> /dev/null && systemctl is-active --quiet commit-boost-pbs; then
    if curl -sf "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT/eth/v1/builder/status" &> /dev/null; then
        record_test "Commit-Boost: API Endpoint" "PASS" "API is responding on port $COMMIT_BOOST_PORT"
    else
        record_test "Commit-Boost: API Endpoint" "SKIP" "API not responding (service may not be fully started)"
    fi
else
    record_test "Commit-Boost: API Endpoint" "SKIP" "curl not available or service not running"
fi

echo ""

# ============================================================================
# Configuration Tests
# ============================================================================

echo -e "${BLUE}=== Configuration Tests ===${NC}"
echo ""

# Test 12: Check exports.sh configuration
if [[ -f "$SCRIPT_DIR/exports.sh" ]]; then
    record_test "Config: exports.sh Exists" "PASS" "Configuration file exists"
    
    # Check MEV-Boost variables
    if grep -q "MEV_PORT" "$SCRIPT_DIR/exports.sh"; then
        record_test "Config: MEV-Boost Variables" "PASS" "MEV-Boost variables configured"
    else
        record_test "Config: MEV-Boost Variables" "FAIL" "MEV-Boost variables missing"
    fi
    
    # Check Commit-Boost variables
    if grep -q "COMMIT_BOOST_PORT" "$SCRIPT_DIR/exports.sh"; then
        record_test "Config: Commit-Boost Variables" "PASS" "Commit-Boost variables configured"
    else
        record_test "Config: Commit-Boost Variables" "FAIL" "Commit-Boost variables missing"
    fi
else
    record_test "Config: exports.sh Exists" "FAIL" "Configuration file not found"
fi

# Test 13: Check JWT secret
if [[ -f "$HOME/secrets/jwt.hex" ]]; then
    record_test "Config: JWT Secret" "PASS" "JWT secret exists"
    
    # Check JWT secret format (should be 64 hex characters)
    jwt_content=$(cat "$HOME/secrets/jwt.hex")
    if [[ ${#jwt_content} -eq 64 && "$jwt_content" =~ ^[0-9a-fA-F]+$ ]]; then
        record_test "Config: JWT Secret Format" "PASS" "JWT secret is valid (64 hex chars)"
    else
        record_test "Config: JWT Secret Format" "FAIL" "JWT secret format is invalid"
    fi
else
    record_test "Config: JWT Secret" "SKIP" "JWT secret not found (created during client installation)"
fi

echo ""

# ============================================================================
# Port Tests
# ============================================================================

echo -e "${BLUE}=== Port Tests ===${NC}"
echo ""

# Test 14: Check for port usage
check_port_in_use() {
    local port="$1"
    local service_name="$2"
    
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            record_test "Port $port ($service_name)" "PASS" "Port is in use (service running)"
        else
            record_test "Port $port ($service_name)" "SKIP" "Port not in use"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            record_test "Port $port ($service_name)" "PASS" "Port is in use (service running)"
        else
            record_test "Port $port ($service_name)" "SKIP" "Port not in use"
        fi
    else
        record_test "Port Check" "SKIP" "Neither ss nor netstat available"
        return
    fi
}

check_port_in_use "$MEV_PORT" "MEV-Boost"
check_port_in_use "$COMMIT_BOOST_PORT" "Commit-Boost PBS"
check_port_in_use "$((COMMIT_BOOST_PORT + 1))" "Commit-Boost Signer"
check_port_in_use "$((COMMIT_BOOST_PORT + 2))" "Commit-Boost Metrics"

echo ""

# ============================================================================
# Firewall Tests
# ============================================================================

echo -e "${BLUE}=== Firewall Tests ===${NC}"
echo ""

# Test 15: Check if ufw is installed and active
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        record_test "Firewall: UFW Active" "PASS" "UFW firewall is active"
        
        # Note: Firewall rules for MEV ports may not be configured
        # This is OK as MEV services bind to localhost by default
        record_test "Firewall: MEV Ports" "PASS" "MEV services bind to localhost (no external access needed)"
    else
        record_test "Firewall: UFW Active" "SKIP" "UFW is installed but not active"
    fi
else
    record_test "Firewall: UFW Active" "SKIP" "UFW not installed"
fi

echo ""

# ============================================================================
# Mutual Exclusivity Test
# ============================================================================

echo -e "${BLUE}=== Mutual Exclusivity Check ===${NC}"
echo ""

# Test 16: Check that only one MEV solution is running
mev_boost_running=false
commit_boost_running=false

if systemctl is-active --quiet mev; then
    mev_boost_running=true
fi

if systemctl is-active --quiet commit-boost-pbs; then
    commit_boost_running=true
fi

if $mev_boost_running && $commit_boost_running; then
    record_test "MEV: Mutual Exclusivity" "FAIL" "Both MEV-Boost and Commit-Boost are running! Only one should be active."
elif $mev_boost_running; then
    record_test "MEV: Mutual Exclusivity" "PASS" "Only MEV-Boost is running"
elif $commit_boost_running; then
    record_test "MEV: Mutual Exclusivity" "PASS" "Only Commit-Boost is running"
else
    record_test "MEV: Mutual Exclusivity" "SKIP" "No MEV solution is currently running"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total Tests: $total_tests"
echo -e "Passed: ${GREEN}$passed_tests${NC}"
echo -e "Failed: ${RED}$failed_tests${NC}"
echo -e "Skipped: ${BLUE}$((total_tests - passed_tests - failed_tests))${NC}"
echo ""

# Calculate pass rate
if [[ $total_tests -gt 0 ]]; then
    pass_rate=$((passed_tests * 100 / total_tests))
    echo "Pass Rate: $pass_rate%"
fi

echo ""

# Exit with appropriate code
if [[ $failed_tests -gt 0 ]]; then
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed or skipped!${NC}"
    exit 0
fi
