#!/bin/bash

# MEV Implementations Testing Script
# Tests all MEV implementations (MEV-Boost, Commit-Boost, ETHGas)
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
        record_test "MEV-Boost: Service Running" "FAIL" "Service is not active"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet mev; then
        record_test "MEV-Boost: Service Enabled" "PASS" "Service is enabled"
    else
        record_test "MEV-Boost: Service Enabled" "FAIL" "Service is not enabled"
    fi
else
    record_test "MEV-Boost: Service File" "SKIP" "Not installed"
fi

# Test 4: Check MEV-Boost API endpoint
if command -v curl &> /dev/null; then
    if curl -sf "http://$MEV_HOST:$MEV_PORT/eth/v1/builder/status" &> /dev/null; then
        record_test "MEV-Boost: API Endpoint" "PASS" "API is responding on port $MEV_PORT"
    else
        record_test "MEV-Boost: API Endpoint" "FAIL" "API not responding or service not running"
    fi
else
    record_test "MEV-Boost: API Endpoint" "SKIP" "curl not available"
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

# Test 7: Check Commit-Boost configuration
if [[ -f "$HOME/commit-boost/config/commit-boost.toml" ]]; then
    record_test "Commit-Boost: Configuration File" "PASS" "Config file exists"
    
    # Validate TOML syntax (basic check)
    if grep -q "\[pbs\]" "$HOME/commit-boost/config/commit-boost.toml"; then
        record_test "Commit-Boost: Config Valid" "PASS" "Config file has PBS section"
    else
        record_test "Commit-Boost: Config Valid" "FAIL" "Config file missing PBS section"
    fi
else
    record_test "Commit-Boost: Configuration File" "SKIP" "Not installed"
fi

# Test 8: Check Commit-Boost service
if systemctl list-unit-files | grep -q "commit-boost.service"; then
    record_test "Commit-Boost: Service File" "PASS" "Service file exists"
    
    # Check service status
    if systemctl is-active --quiet commit-boost; then
        record_test "Commit-Boost: Service Running" "PASS" "Service is active"
    else
        record_test "Commit-Boost: Service Running" "FAIL" "Service is not active"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet commit-boost; then
        record_test "Commit-Boost: Service Enabled" "PASS" "Service is enabled"
    else
        record_test "Commit-Boost: Service Enabled" "FAIL" "Service is not enabled"
    fi
else
    record_test "Commit-Boost: Service File" "SKIP" "Not installed"
fi

# Test 9: Check Docker availability for Commit-Boost
if command -v docker &> /dev/null; then
    record_test "Commit-Boost: Docker Available" "PASS" "Docker is installed"
    
    # Check if Docker is running
    if docker ps &> /dev/null; then
        record_test "Commit-Boost: Docker Running" "PASS" "Docker daemon is running"
        
        # Check if Commit-Boost container exists
        if docker ps -a | grep -q "commit-boost"; then
            record_test "Commit-Boost: Container Exists" "PASS" "Docker container exists"
            
            # Check if container is running
            if docker ps | grep -q "commit-boost"; then
                record_test "Commit-Boost: Container Running" "PASS" "Container is running"
            else
                record_test "Commit-Boost: Container Running" "FAIL" "Container exists but not running"
            fi
        else
            record_test "Commit-Boost: Container Exists" "SKIP" "Container not found"
        fi
    else
        record_test "Commit-Boost: Docker Running" "FAIL" "Docker daemon not running"
    fi
else
    record_test "Commit-Boost: Docker Available" "SKIP" "Docker not installed"
fi

# Test 10: Check Commit-Boost API endpoint
if command -v curl &> /dev/null; then
    if curl -sf "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT/eth/v1/builder/status" &> /dev/null; then
        record_test "Commit-Boost: API Endpoint" "PASS" "API is responding on port $COMMIT_BOOST_PORT"
    else
        record_test "Commit-Boost: API Endpoint" "FAIL" "API not responding or service not running"
    fi
else
    record_test "Commit-Boost: API Endpoint" "SKIP" "curl not available"
fi

# Test 11: Check Commit-Boost metrics endpoint
if command -v curl &> /dev/null; then
    metrics_port=$((COMMIT_BOOST_PORT + 2))
    if curl -sf "http://$COMMIT_BOOST_HOST:$metrics_port/metrics" &> /dev/null; then
        record_test "Commit-Boost: Metrics Endpoint" "PASS" "Metrics available on port $metrics_port"
    else
        record_test "Commit-Boost: Metrics Endpoint" "FAIL" "Metrics not available"
    fi
else
    record_test "Commit-Boost: Metrics Endpoint" "SKIP" "curl not available"
fi

echo ""

# ============================================================================
# ETHGas Tests
# ============================================================================

echo -e "${BLUE}=== ETHGas Tests ===${NC}"
echo ""

# Test 12: Check if ETHGas is installed
if [[ -d "$HOME/ethgas" ]]; then
    record_test "ETHGas: Installation Directory" "PASS" "Directory exists at $HOME/ethgas"
else
    record_test "ETHGas: Installation Directory" "SKIP" "Not installed"
fi

# Test 13: Check ETHGas configuration
if [[ -f "$HOME/ethgas/config/ethgas.toml" ]]; then
    record_test "ETHGas: Configuration File" "PASS" "Config file exists"
    
    # Validate TOML syntax (basic check)
    if grep -q "\[cb_ethgas_commit\]" "$HOME/ethgas/config/ethgas.toml"; then
        record_test "ETHGas: Config Valid" "PASS" "Config has ETHGas commit section"
    else
        record_test "ETHGas: Config Valid" "FAIL" "Config missing ETHGas commit section"
    fi
else
    record_test "ETHGas: Configuration File" "SKIP" "Not installed"
fi

# Test 14: Check Docker Compose file
if [[ -f "$HOME/ethgas/docker-compose.yml" ]]; then
    record_test "ETHGas: Docker Compose File" "PASS" "Docker Compose file exists"
else
    record_test "ETHGas: Docker Compose File" "SKIP" "Not installed"
fi

# Test 15: Check ETHGas service
if systemctl list-unit-files | grep -q "ethgas.service"; then
    record_test "ETHGas: Service File" "PASS" "Service file exists"
    
    # Check service status
    if systemctl is-active --quiet ethgas; then
        record_test "ETHGas: Service Running" "PASS" "Service is active"
    else
        record_test "ETHGas: Service Running" "FAIL" "Service is not active"
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet ethgas; then
        record_test "ETHGas: Service Enabled" "PASS" "Service is enabled"
    else
        record_test "ETHGas: Service Enabled" "FAIL" "Service is not enabled"
    fi
else
    record_test "ETHGas: Service File" "SKIP" "Not installed"
fi

# Test 16: Check ETHGas Docker containers
if command -v docker &> /dev/null; then
    if docker ps &> /dev/null; then
        # Check for cb_pbs container
        if docker ps | grep -q "ethgas_pbs"; then
            record_test "ETHGas: PBS Container" "PASS" "PBS container is running"
        else
            record_test "ETHGas: PBS Container" "SKIP" "PBS container not running"
        fi
        
        # Check for cb_signer container
        if docker ps | grep -q "ethgas_signer"; then
            record_test "ETHGas: Signer Container" "PASS" "Signer container is running"
        else
            record_test "ETHGas: Signer Container" "SKIP" "Signer container not running"
        fi
        
        # Check for cb_ethgas_commit container
        if docker ps | grep -q "ethgas_commit"; then
            record_test "ETHGas: Commit Container" "PASS" "Commit container is running"
        else
            record_test "ETHGas: Commit Container" "SKIP" "Commit container not running"
        fi
    fi
fi

# Test 17: Check ETHGas logs directory
if [[ -d "$HOME/ethgas/logs" ]]; then
    record_test "ETHGas: Logs Directory" "PASS" "Logs directory exists"
else
    record_test "ETHGas: Logs Directory" "SKIP" "Not created yet"
fi

# Test 18: Check Commit-Boost dependency for ETHGas
if [[ -d "$HOME/ethgas" ]]; then
    if systemctl is-active --quiet commit-boost; then
        record_test "ETHGas: Commit-Boost Dependency" "PASS" "Required Commit-Boost is running"
    else
        record_test "ETHGas: Commit-Boost Dependency" "FAIL" "ETHGas requires Commit-Boost to be running"
    fi
fi

echo ""

# ============================================================================
# Configuration Tests
# ============================================================================

echo -e "${BLUE}=== Configuration Tests ===${NC}"
echo ""

# Test 19: Check exports.sh configuration
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
    
    # Check ETHGas variables
    if grep -q "ETHGAS_PORT" "$SCRIPT_DIR/exports.sh"; then
        record_test "Config: ETHGas Variables" "PASS" "ETHGas variables configured"
    else
        record_test "Config: ETHGas Variables" "FAIL" "ETHGas variables missing"
    fi
else
    record_test "Config: exports.sh Exists" "FAIL" "Configuration file not found"
fi

# Test 20: Check JWT secret
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
    record_test "Config: JWT Secret" "FAIL" "JWT secret not found"
fi

echo ""

# ============================================================================
# Port Conflict Tests
# ============================================================================

echo -e "${BLUE}=== Port Conflict Tests ===${NC}"
echo ""

# Test 21: Check for port conflicts
check_port_in_use() {
    local port="$1"
    local service_name="$2"
    
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            record_test "Port $port ($service_name)" "PASS" "Port is in use (service running)"
        else
            record_test "Port $port ($service_name)" "SKIP" "Port not in use (service may not be running)"
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            record_test "Port $port ($service_name)" "PASS" "Port is in use (service running)"
        else
            record_test "Port $port ($service_name)" "SKIP" "Port not in use (service may not be running)"
        fi
    else
        record_test "Port Check" "SKIP" "Neither ss nor netstat available"
    fi
}

check_port_in_use "$MEV_PORT" "MEV-Boost"
check_port_in_use "$COMMIT_BOOST_PORT" "Commit-Boost PBS"
check_port_in_use "$((COMMIT_BOOST_PORT + 1))" "Commit-Boost Signer"
check_port_in_use "$((COMMIT_BOOST_PORT + 2))" "Commit-Boost Metrics"
check_port_in_use "$ETHGAS_PORT" "ETHGas PBS"
check_port_in_use "$((ETHGAS_PORT + 1))" "ETHGas Signer"
check_port_in_use "$((ETHGAS_PORT + 2))" "ETHGas Commit"

echo ""

# ============================================================================
# Firewall Tests
# ============================================================================

echo -e "${BLUE}=== Firewall Tests ===${NC}"
echo ""

# Test 22: Check if ufw is installed and active
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        record_test "Firewall: UFW Active" "PASS" "UFW firewall is active"
        
        # Check if MEV ports are allowed
        if sudo ufw status | grep -q "$MEV_PORT"; then
            record_test "Firewall: MEV-Boost Port" "PASS" "Port $MEV_PORT is allowed"
        else
            record_test "Firewall: MEV-Boost Port" "SKIP" "Port $MEV_PORT not configured in firewall"
        fi
        
        if sudo ufw status | grep -q "$COMMIT_BOOST_PORT"; then
            record_test "Firewall: Commit-Boost Port" "PASS" "Port $COMMIT_BOOST_PORT is allowed"
        else
            record_test "Firewall: Commit-Boost Port" "SKIP" "Port $COMMIT_BOOST_PORT not configured in firewall"
        fi
        
        if sudo ufw status | grep -q "$ETHGAS_PORT"; then
            record_test "Firewall: ETHGas Port" "PASS" "Port $ETHGAS_PORT is allowed"
        else
            record_test "Firewall: ETHGas Port" "SKIP" "Port $ETHGAS_PORT not configured in firewall"
        fi
    else
        record_test "Firewall: UFW Active" "SKIP" "UFW is installed but not active"
    fi
else
    record_test "Firewall: UFW Active" "SKIP" "UFW not installed"
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
