#!/bin/bash

# Unified Security Validation Script
# Combines all security validation functionality into a single, efficient script
# Replaces: test_security_fixes.sh, docs/validate_security_safe.sh, docs/server_security_validation.sh

set -Eeuo pipefail

# Source common functions
if [[ -f "../../lib/common_functions.sh" ]]; then
    source ../../lib/common_functions.sh
elif [[ -f "lib/common_functions.sh" ]]; then
    source lib/common_functions.sh
else
    echo "Error: common_functions.sh not found"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Enhanced logging functions
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

# Test counters
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

# Unified test runner
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

# Custom test runner
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

# Test categories
test_code_quality() {
    log_section "Code Quality Validation"
    
    # Test 1: No duplicate functions
    test_no_duplicate_functions() {
        local common_functions_file
        if [[ -f "../../lib/common_functions.sh" ]]; then
            common_functions_file="../../lib/common_functions.sh"
        elif [[ -f "lib/common_functions.sh" ]]; then
            common_functions_file="lib/common_functions.sh"
        else
            log_error "common_functions.sh not found"
            return 1
        fi
        
        local duplicates
        duplicates=$(grep -n "^[a-zA-Z_][a-zA-Z0-9_]*()" "$common_functions_file" | cut -d: -f2 | cut -d'(' -f1 | sort | uniq -d)
        [[ -z "$duplicates" ]]
    }
    run_custom_test "No duplicate functions in common_functions.sh" test_no_duplicate_functions
    
    # Test 2: Required security functions exist
    test_security_functions_exist() {
        local common_functions_file
        if [[ -f "../../lib/common_functions.sh" ]]; then
            common_functions_file="../../lib/common_functions.sh"
        elif [[ -f "lib/common_functions.sh" ]]; then
            common_functions_file="lib/common_functions.sh"
        else
            log_error "common_functions.sh not found"
            return 1
        fi
        
        local required_functions=(
            "setup_security_monitoring" "setup_intrusion_detection" "secure_config_files"
            "apply_network_security" "validate_user_input" "secure_error_handling"
            "safe_command_execution" "secure_file_permissions"
        )
        
        for func in "${required_functions[@]}"; do
            if ! grep -q "^${func}()" "$common_functions_file"; then
                log_error "Missing security function: $func"
                return 1
            fi
        done
        return 0
    }
    run_custom_test "All required security functions exist" test_security_functions_exist
    
    # Test 3: Script syntax validation
    test_script_syntax() {
        local scripts=()
        
        # Add scripts with correct paths
        if [[ -f "../../lib/common_functions.sh" ]]; then
            scripts+=("../../lib/common_functions.sh")
        elif [[ -f "lib/common_functions.sh" ]]; then
            scripts+=("lib/common_functions.sh")
        fi
        
        if [[ -f "../../run_1.sh" ]]; then
            scripts+=("../../run_1.sh")
        elif [[ -f "run_1.sh" ]]; then
            scripts+=("run_1.sh")
        fi
        
        if [[ -f "../../run_2.sh" ]]; then
            scripts+=("../../run_2.sh")
        elif [[ -f "run_2.sh" ]]; then
            scripts+=("run_2.sh")
        fi
        
        scripts+=("$0")  # This script
        
        for script in "${scripts[@]}"; do
            if [[ -f "$script" ]]; then
                if ! bash -n "$script" 2>/dev/null; then
                    log_error "Syntax error in $script"
                    return 1
                fi
            fi
        done
        return 0
    }
    run_custom_test "All scripts have valid syntax" test_script_syntax
}

test_security_implementations() {
    log_section "Security Implementation Validation"
    
    # Test 1: Network exposure
    test_network_exposure() {
        local issues_found=0
        
        # Check for 0.0.0.0 bindings in config files
        if grep -r "0\.0\.0\.0" ../../configs/ >/dev/null 2>&1; then
            log_error "Found 0.0.0.0 bindings in config files"
            issues_found=$((issues_found + 1))
        else
            log_info "✓ No 0.0.0.0 bindings found in config files"
        fi
        
        # Check for localhost bindings
        if grep -r "127\.0\.0\.1" ../../configs/ >/dev/null 2>&1; then
            log_info "✓ Localhost bindings found in config files"
        else
            log_warn "No localhost bindings found in config files"
        fi
        
        return $issues_found
    }
    run_custom_test "Network exposure is secure" test_network_exposure
    
    # Test 2: Input validation functions
    test_input_validation() {
        local issues_found=0
        
        # Test validate_user_input function
        if validate_user_input "test123" "^[a-zA-Z0-9]+$" 10; then
            log_info "✓ validate_user_input works correctly"
        else
            log_error "validate_user_input failed"
            issues_found=$((issues_found + 1))
        fi
        
        # Test invalid input rejection
        if ! validate_user_input "test<script>" "^[a-zA-Z0-9]+$" 10; then
            log_info "✓ Invalid input correctly rejected"
        else
            log_error "Invalid input not rejected"
            issues_found=$((issues_found + 1))
        fi
        
        return $issues_found
    }
    run_custom_test "Input validation functions work correctly" test_input_validation
    
    # Test 3: File permissions
    test_file_permissions() {
        local test_file="/tmp/security_test_file_$(date +%s)"
        echo "test" > "$test_file"
        secure_file_permissions "$test_file" 600
        
        local perms
        perms=$(stat -c "%a" "$test_file")
        rm -f "$test_file"
        
        if [[ "$perms" == "600" ]]; then
            log_info "✓ File permissions set correctly (600)"
            return 0
        else
            log_error "File permissions not set correctly: $perms"
            return 1
        fi
    }
    run_custom_test "File permission functions work correctly" test_file_permissions
    
    # Test 4: Error handling
    test_error_handling() {
        # Test safe_command_execution function
        if safe_command_execution "echo test" "Test command failed" "false" >/dev/null 2>&1; then
            log_info "✓ safe_command_execution works correctly"
            return 0
        else
            log_error "safe_command_execution failed"
            return 1
        fi
    }
    run_custom_test "Error handling functions work correctly" test_error_handling
}

test_server_security() {
    log_section "Server Security Validation"
    
    # Test 1: Security monitoring
    test_security_monitoring() {
        if [[ -f "/usr/local/bin/security_monitor.sh" && -x "/usr/local/bin/security_monitor.sh" ]]; then
            if /usr/local/bin/security_monitor.sh >/dev/null 2>&1; then
                if [[ -f "/var/log/security_monitor.log" ]]; then
                    return 0
                else
                    log_error "Security monitoring log file not created"
                    return 1
                fi
            else
                log_error "Security monitoring script execution failed"
                return 1
            fi
        else
            log_error "Security monitoring script not found or not executable"
            return 1
        fi
    }
    run_custom_test "Security monitoring is working" test_security_monitoring
    
    # Test 2: AIDE intrusion detection
    test_aide_detection() {
        if command -v aide >/dev/null 2>&1; then
            if [[ -f "/var/lib/aide/aide.db" ]]; then
                if [[ -f "/usr/local/bin/aide_check.sh" && -x "/usr/local/bin/aide_check.sh" ]]; then
                    if /usr/local/bin/aide_check.sh >/dev/null 2>&1; then
                        return 0
                    else
                        log_error "AIDE check script execution failed"
                        return 1
                    fi
                else
                    log_error "AIDE check script not found or not executable"
                    return 1
                fi
            else
                log_error "AIDE database not found"
                return 1
            fi
        else
            log_error "AIDE not installed"
            return 1
        fi
    }
    run_custom_test "AIDE intrusion detection is working" test_aide_detection
    
    # Test 3: Firewall configuration
    test_firewall_config() {
        if ufw status | grep -q "Status: active"; then
            if ufw status | grep -q "8545/tcp.*DENY" && ufw status | grep -q "8551/tcp.*DENY"; then
                return 0
            else
                log_error "Critical ports not blocked by firewall"
                return 1
            fi
        else
            log_error "UFW not active"
            return 1
        fi
    }
    run_custom_test "Firewall configuration is correct" test_firewall_config
    
    # Test 4: Fail2ban
    test_fail2ban() {
        if systemctl is-active --quiet fail2ban; then
            if fail2ban-client status | grep -q "Number of jail:"; then
                return 0
            else
                log_error "Fail2ban has no jails configured"
                return 1
            fi
        else
            log_error "Fail2ban not running"
            return 1
        fi
    }
    run_custom_test "Fail2ban configuration is correct" test_fail2ban
    
    # Test 5: Network binding
    test_network_binding() {
        if ss -tuln | grep -q "0.0.0.0"; then
            log_error "Services found binding to 0.0.0.0 (security risk)"
            return 1
        else
            if ss -tuln | grep -q "127.0.0.1"; then
                return 0
            else
                log_warn "No services found binding to localhost"
                return 0
            fi
        fi
    }
    run_custom_test "Network binding is secure" test_network_binding
    
    # Test 6: File permissions
    test_file_permissions() {
        if [[ -d "$HOME/secrets" ]]; then
            local perms
            perms=$(stat -c %a "$HOME/secrets")
            if [[ "$perms" == "700" ]]; then
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
    run_custom_test "File permissions are secure" test_file_permissions
    
    # Test 7: Systemd services
    test_systemd_services() {
        local services=("ufw" "fail2ban")
        local failed_services=()
        
        for service in "${services[@]}"; do
            if ! systemctl is-active --quiet "$service"; then
                failed_services+=("$service")
            fi
        done
        
        if [[ ${#failed_services[@]} -eq 0 ]]; then
            return 0
        else
            log_error "Services not running: ${failed_services[*]}"
            return 1
        fi
    }
    run_custom_test "Critical systemd services are running" test_systemd_services
}

# Main execution
main() {
    log_info "Starting unified security validation..."
    echo
    
    # Determine what tests to run based on context
    local run_mode="${1:-all}"
    
    case "$run_mode" in
        "code")
            test_code_quality
            ;;
        "implementation")
            test_security_implementations
            ;;
        "server")
            test_server_security
            ;;
        "all"|*)
            test_code_quality
            test_security_implementations
            test_server_security
            ;;
    esac
    
    # Summary
    log_section "Validation Summary"
    
    echo "Total tests performed: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Warnings: $warnings"
    echo
    
    # Calculate validation score
    if [[ $total_tests -gt 0 ]]; then
        local validation_score=$(( (passed_tests * 100) / total_tests ))
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
    
    # Additional information
    log_section "Additional Information"
    
    echo "Security monitoring log location: /var/log/security_monitor.log"
    echo "AIDE intrusion detection log: /var/log/aide_check.log"
    echo "Security monitoring runs every 15 minutes"
    echo "AIDE intrusion detection runs daily at 2 AM"
    echo
    
    # Show recent security log entries
    if [[ -f "/var/log/security_monitor.log" ]]; then
        echo "Recent security monitoring entries:"
        tail -5 /var/log/security_monitor.log
        echo
    fi
    
    # Show firewall status
    echo "Firewall status:"
    if command -v ufw >/dev/null 2>&1; then
        ufw status
    else
        echo "UFW not available"
    fi
    echo
    
    # Show fail2ban status
    echo "Fail2ban status:"
    if command -v fail2ban-client >/dev/null 2>&1; then
        fail2ban-client status
    else
        echo "Fail2ban not available"
    fi
    echo
    
    # Exit with appropriate code
    if [[ $failed_tests -gt 0 ]]; then
        exit 1
    elif [[ $warnings -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Run main function with all arguments
main "$@"