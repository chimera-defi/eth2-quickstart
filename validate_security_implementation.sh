#!/bin/bash

# Security Implementation Validation Script
# This script validates that all security implementations actually work in a real environment

set -Eeuo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo -e "${BLUE}[SECTION]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "This script should not be run as root"
    exit 1
fi

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

# Function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="${3:-0}"
    
    total_tests=$((total_tests + 1))
    
    if eval "$test_command" >/dev/null 2>&1; then
        if [[ $? -eq $expected_result ]]; then
            log_info "✓ $test_name"
            passed_tests=$((passed_tests + 1))
            return 0
        else
            log_warn "⚠ $test_name (unexpected result)"
            warnings=$((warnings + 1))
            return 1
        fi
    else
        log_error "✗ $test_name"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# Function to run a test with custom logic
run_custom_test() {
    local test_name="$1"
    local test_function="$2"
    
    total_tests=$((total_tests + 1))
    
    if $test_function; then
        log_info "✓ $test_name"
        passed_tests=$((passed_tests + 1))
        return 0
    else
        log_error "✗ $test_name"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

log_info "Starting comprehensive security implementation validation..."
echo

# Test 1: Verify common_functions.sh has no duplicate functions
log_section "Testing Common Functions Library"

test_no_duplicate_functions() {
    local duplicates
    duplicates=$(grep -n "^[a-zA-Z_][a-zA-Z0-9_]*()" lib/common_functions.sh | cut -d: -f2 | cut -d'(' -f1 | sort | uniq -d)
    if [[ -z "$duplicates" ]]; then
        return 0
    else
        log_error "Duplicate functions found: $duplicates"
        return 1
    fi
}

run_custom_test "No duplicate functions in common_functions.sh" test_no_duplicate_functions

# Test 2: Verify security functions exist
test_security_functions_exist() {
    local required_functions=(
        "setup_security_monitoring"
        "setup_intrusion_detection"
        "secure_config_files"
        "apply_network_security"
        "validate_user_input"
        "secure_error_handling"
        "safe_command_execution"
    )
    
    for func in "${required_functions[@]}"; do
        if ! grep -q "^${func}()" lib/common_functions.sh; then
            log_error "Missing security function: $func"
            return 1
        fi
    done
    return 0
}

run_custom_test "All required security functions exist" test_security_functions_exist

# Test 3: Verify run_1.sh calls security functions
test_run1_security_calls() {
    if grep -q "setup_security_monitoring" run_1.sh && grep -q "setup_intrusion_detection" run_1.sh; then
        return 0
    else
        log_error "run_1.sh missing security function calls"
        return 1
    fi
}

run_custom_test "run_1.sh calls security functions" test_run1_security_calls

# Test 4: Verify run_2.sh calls security functions
test_run2_security_calls() {
    if grep -q "secure_config_files" run_2.sh && grep -q "apply_network_security" run_2.sh; then
        return 0
    else
        log_error "run_2.sh missing security function calls"
        return 1
    fi
}

run_custom_test "run_2.sh calls security functions" test_run2_security_calls

echo

# Test 5: Test security monitoring script creation
log_section "Testing Security Monitoring Implementation"

test_security_monitoring_script() {
    # Source the common functions
    source lib/common_functions.sh
    
    # Test if setup_security_monitoring function exists and can be called
    if declare -f setup_security_monitoring >/dev/null; then
        # Test the function (this will create the script)
        setup_security_monitoring
        
        # Check if the script was created
        if [[ -f "/usr/local/bin/security_monitor.sh" ]]; then
            # Check if it's executable
            if [[ -x "/usr/local/bin/security_monitor.sh" ]]; then
                # Test if it runs without errors
                if /usr/local/bin/security_monitor.sh >/dev/null 2>&1; then
                    return 0
                else
                    log_error "Security monitoring script execution failed"
                    return 1
                fi
            else
                log_error "Security monitoring script not executable"
                return 1
            fi
        else
            log_error "Security monitoring script not created"
            return 1
        fi
    else
        log_error "setup_security_monitoring function not found"
        return 1
    fi
}

run_custom_test "Security monitoring script creation and execution" test_security_monitoring_script

# Test 6: Test AIDE intrusion detection setup
log_section "Testing AIDE Intrusion Detection Implementation"

test_aide_setup() {
    # Source the common functions
    source lib/common_functions.sh
    
    # Test if setup_intrusion_detection function exists and can be called
    if declare -f setup_intrusion_detection >/dev/null; then
        # Test the function (this will install and configure AIDE)
        setup_intrusion_detection
        
        # Check if AIDE is installed
        if command -v aide >/dev/null 2>&1; then
            # Check if AIDE database exists
            if [[ -f "/var/lib/aide/aide.db" ]]; then
                # Check if AIDE check script was created
                if [[ -f "/usr/local/bin/aide_check.sh" ]]; then
                    # Check if it's executable
                    if [[ -x "/usr/local/bin/aide_check.sh" ]]; then
                        return 0
                    else
                        log_error "AIDE check script not executable"
                        return 1
                    fi
                else
                    log_error "AIDE check script not created"
                    return 1
                fi
            else
                log_error "AIDE database not created"
                return 1
            fi
        else
            log_error "AIDE not installed"
            return 1
        fi
    else
        log_error "setup_intrusion_detection function not found"
        return 1
    fi
}

run_custom_test "AIDE intrusion detection setup" test_aide_setup

echo

# Test 7: Test input validation functions
log_section "Testing Input Validation Functions"

test_input_validation() {
    # Source the common functions
    source lib/common_functions.sh
    
    # Test validate_user_input function
    if declare -f validate_user_input >/dev/null; then
        # Test valid input
        if validate_user_input "test123" 10; then
            # Test invalid input (too long)
            if ! validate_user_input "thisinputistoolong" 10; then
                return 0
            else
                log_error "Input validation failed to reject long input"
                return 1
            fi
        else
            log_error "Input validation failed to accept valid input"
            return 1
        fi
    else
        log_error "validate_user_input function not found"
        return 1
    fi
}

run_custom_test "Input validation functions work correctly" test_input_validation

# Test 8: Test file permission functions
log_section "Testing File Permission Functions"

test_file_permissions() {
    # Source the common functions
    source lib/common_functions.sh
    
    # Create a test file
    local test_file="/tmp/security_test_file_$(date +%s)"
    echo "test content" > "$test_file"
    
    # Test secure_config_files function
    if declare -f secure_config_files >/dev/null; then
        secure_config_files
        
        # Check if the test file has correct permissions
        local perms
        perms=$(stat -c %a "$test_file")
        if [[ "$perms" == "600" ]]; then
            rm -f "$test_file"
            return 0
        else
            log_error "File permissions not set correctly (expected 600, got $perms)"
            rm -f "$test_file"
            return 1
        fi
    else
        log_error "secure_config_files function not found"
        rm -f "$test_file"
        return 1
    fi
}

run_custom_test "File permission functions work correctly" test_file_permissions

echo

# Test 9: Test network security functions
log_section "Testing Network Security Functions"

test_network_security() {
    # Source the common functions
    source lib/common_functions.sh
    
    # Test apply_network_security function
    if declare -f apply_network_security >/dev/null; then
        apply_network_security
        
        # Check if UFW is active
        if ufw status | grep -q "Status: active"; then
            return 0
        else
            log_error "UFW not active after network security setup"
            return 1
        fi
    else
        log_error "apply_network_security function not found"
        return 1
    fi
}

run_custom_test "Network security functions work correctly" test_network_security

echo

# Test 10: Test error handling functions
log_section "Testing Error Handling Functions"

test_error_handling() {
    # Source the common functions
    source lib/common_functions.sh
    
    # Test secure_error_handling function
    if declare -f secure_error_handling >/dev/null; then
        # Test safe_command_execution function
        if declare -f safe_command_execution >/dev/null; then
            # Test with a valid command
            if safe_command_execution "echo 'test'" >/dev/null 2>&1; then
                # Test with an invalid command (should not crash)
                if ! safe_command_execution "nonexistentcommand12345" >/dev/null 2>&1; then
                    return 0
                else
                    log_error "Error handling failed to handle invalid command"
                    return 1
                fi
            else
                log_error "Error handling failed with valid command"
                return 1
            fi
        else
            log_error "safe_command_execution function not found"
            return 1
        fi
    else
        log_error "secure_error_handling function not found"
        return 1
    fi
}

run_custom_test "Error handling functions work correctly" test_error_handling

echo

# Test 11: Test crontab scheduling
log_section "Testing Crontab Scheduling"

test_crontab_scheduling() {
    # Check if security monitoring is scheduled
    if crontab -l 2>/dev/null | grep -q "security_monitor"; then
        # Check if AIDE is scheduled
        if crontab -l 2>/dev/null | grep -q "aide_check"; then
            return 0
        else
            log_error "AIDE not scheduled in crontab"
            return 1
        fi
    else
        log_error "Security monitoring not scheduled in crontab"
        return 1
    fi
}

run_custom_test "Crontab scheduling configured correctly" test_crontab_scheduling

echo

# Test 12: Test log rotation configuration
log_section "Testing Log Rotation Configuration"

test_log_rotation() {
    # Check if security monitoring log rotation is configured
    if [[ -f "/etc/logrotate.d/security_monitor" ]]; then
        return 0
    else
        log_error "Security monitoring log rotation not configured"
        return 1
    fi
}

run_custom_test "Log rotation configuration exists" test_log_rotation

echo

# Test 13: Test security test script
log_section "Testing Security Test Script"

test_security_test_script() {
    # Check if test_security_fixes.sh exists and is executable
    if [[ -f "test_security_fixes.sh" && -x "test_security_fixes.sh" ]]; then
        # Test if it runs without errors
        if ./test_security_fixes.sh >/dev/null 2>&1; then
            return 0
        else
            log_error "Security test script execution failed"
            return 1
        fi
    else
        log_error "Security test script not found or not executable"
        return 1
    fi
}

run_custom_test "Security test script works correctly" test_security_test_script

echo

# Test 14: Test security verification script
log_section "Testing Security Verification Script"

test_security_verification_script() {
    # Check if verify_security.sh exists and is executable
    if [[ -f "docs/verify_security.sh" && -x "docs/verify_security.sh" ]]; then
        # Test if it runs without errors
        if ./docs/verify_security.sh >/dev/null 2>&1; then
            return 0
        else
            log_error "Security verification script execution failed"
            return 1
        fi
    else
        log_error "Security verification script not found or not executable"
        return 1
    fi
}

run_custom_test "Security verification script works correctly" test_security_verification_script

echo

# Test 15: Test actual security monitoring execution
log_section "Testing Security Monitoring Execution"

test_security_monitoring_execution() {
    # Check if security monitoring script exists
    if [[ -f "/usr/local/bin/security_monitor.sh" && -x "/usr/local/bin/security_monitor.sh" ]]; then
        # Run the security monitoring script and capture output
        local output
        output=$(/usr/local/bin/security_monitor.sh 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            # Check if log file was created
            if [[ -f "/var/log/security_monitor.log" ]]; then
                return 0
            else
                log_error "Security monitoring log file not created"
                return 1
            fi
        else
            log_error "Security monitoring script failed with exit code $exit_code"
            return 1
        fi
    else
        log_error "Security monitoring script not found or not executable"
        return 1
    fi
}

run_custom_test "Security monitoring execution works correctly" test_security_monitoring_execution

echo

# Test 16: Test AIDE execution
log_section "Testing AIDE Execution"

test_aide_execution() {
    # Check if AIDE check script exists
    if [[ -f "/usr/local/bin/aide_check.sh" && -x "/usr/local/bin/aide_check.sh" ]]; then
        # Run the AIDE check script and capture output
        local output
        output=$(/usr/local/bin/aide_check.sh 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            # Check if log file was created
            if [[ -f "/var/log/aide_check.log" ]]; then
                return 0
            else
                log_error "AIDE check log file not created"
                return 1
            fi
        else
            log_error "AIDE check script failed with exit code $exit_code"
            return 1
        fi
    else
        log_error "AIDE check script not found or not executable"
        return 1
    fi
}

run_custom_test "AIDE execution works correctly" test_aide_execution

echo

# Test 17: Test firewall rules
log_section "Testing Firewall Rules"

test_firewall_rules() {
    # Check if UFW is active
    if ufw status | grep -q "Status: active"; then
        # Check if common ports are blocked
        if ufw status | grep -q "8545/tcp.*DENY"; then
            if ufw status | grep -q "8551/tcp.*DENY"; then
                return 0
            else
                log_error "Port 8551 not blocked by firewall"
                return 1
            fi
        else
            log_error "Port 8545 not blocked by firewall"
            return 1
        fi
    else
        log_error "UFW not active"
        return 1
    fi
}

run_custom_test "Firewall rules configured correctly" test_firewall_rules

echo

# Test 18: Test file permissions on sensitive files
log_section "Testing File Permissions on Sensitive Files"

test_sensitive_file_permissions() {
    # Check if secrets directory exists and has correct permissions
    if [[ -d "$HOME/secrets" ]]; then
        local perms
        perms=$(stat -c %a "$HOME/secrets")
        if [[ "$perms" == "700" ]]; then
            # Check if JWT secret has correct permissions
            if [[ -f "$HOME/secrets/jwt.hex" ]]; then
                local jwt_perms
                jwt_perms=$(stat -c %a "$HOME/secrets/jwt.hex")
                if [[ "$jwt_perms" == "600" ]]; then
                    return 0
                else
                    log_error "JWT secret permissions incorrect (expected 600, got $jwt_perms)"
                    return 1
                fi
            else
                log_warn "JWT secret not found (may not be created yet)"
                return 0
            fi
        else
            log_error "Secrets directory permissions incorrect (expected 700, got $perms)"
            return 1
        fi
    else
        log_warn "Secrets directory not found (may not be created yet)"
        return 0
    fi
}

run_custom_test "Sensitive file permissions configured correctly" test_sensitive_file_permissions

echo

# Test 19: Test systemd services
log_section "Testing Systemd Services"

test_systemd_services() {
    # Check if fail2ban service is running
    if systemctl is-active --quiet fail2ban; then
        # Check if UFW service is running
        if systemctl is-active --quiet ufw; then
            return 0
        else
            log_error "UFW service not running"
            return 1
        fi
    else
        log_error "Fail2ban service not running"
        return 1
    fi
}

run_custom_test "Systemd services running correctly" test_systemd_services

echo

# Test 20: Test network binding
log_section "Testing Network Binding"

test_network_binding() {
    # Check if any services are binding to 0.0.0.0
    if ss -tuln | grep -q "0.0.0.0"; then
        log_error "Services found binding to 0.0.0.0 (security risk)"
        return 1
    else
        # Check if services are binding to localhost
        if ss -tuln | grep -q "127.0.0.1"; then
            return 0
        else
            log_warn "No services found binding to localhost"
            return 0
        fi
    fi
}

run_custom_test "Network binding configured correctly" test_network_binding

echo

# Summary
log_section "Validation Summary"

echo "Total tests performed: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"
echo "Warnings: $warnings"
echo

# Calculate validation score
if [[ $total_tests -gt 0 ]]; then
    validation_score=$(( (passed_tests * 100) / total_tests ))
    echo "Validation Score: $validation_score%"
    echo
    
    if [[ $validation_score -ge 90 ]]; then
        log_info "🎉 Excellent! Security implementation is working correctly."
    elif [[ $validation_score -ge 75 ]]; then
        log_warn "⚠ Good security implementation, but some areas need attention."
    elif [[ $validation_score -ge 50 ]]; then
        log_warn "⚠ Moderate security implementation. Several issues need to be addressed."
    else
        log_error "❌ Poor security implementation. Major issues need to be fixed."
    fi
fi

echo

# Recommendations
if [[ $failed_tests -gt 0 || $warnings -gt 0 ]]; then
    log_section "Recommendations"
    
    if [[ $failed_tests -gt 0 ]]; then
        echo "Critical issues to address:"
        echo "- Review failed tests above and fix them immediately"
        echo "- Check that all security functions are properly implemented"
        echo "- Verify that security scripts are executable and working"
        echo "- Ensure all required services are installed and running"
        echo
    fi
    
    if [[ $warnings -gt 0 ]]; then
        echo "Areas for improvement:"
        echo "- Address warnings above to improve security implementation"
        echo "- Consider additional security measures"
        echo "- Review system configuration for optimization"
        echo
    fi
fi

# Exit with appropriate code
if [[ $failed_tests -gt 0 ]]; then
    exit 1
elif [[ $warnings -gt 0 ]]; then
    exit 2
else
    exit 0
fi