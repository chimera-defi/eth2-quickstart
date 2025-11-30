#!/bin/bash
# CI Test Script for run_1.sh (Phase 1 - System Setup)
# Runs inside Docker container as root
# Tests script structure and key components
# Note: Full systemd services don't work in standard Docker

set -Eeuo pipefail

# Setup paths and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  CI Test: run_1.sh (Phase 1 - Structure Validation)           ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

# Verify we're running as root (required for run_1.sh)
if ! is_root; then
    log_error "This test must run as root"
    exit 1
fi
log_info "✓ Running as root"

cd "$PROJECT_ROOT"

# Test 1: Verify required files exist
log_info "Test 1: Verify required files..."
for file in run_1.sh exports.sh lib/common_functions.sh; do
    assert_file_exists "$PROJECT_ROOT/$file" "$file"
done

# Test 2: Source exports and verify variables
log_info "Test 2: Load and verify configuration..."
source_exports
if [[ -n "${LOGIN_UNAME:-}" ]]; then
    log_info "  ✓ LOGIN_UNAME=$LOGIN_UNAME"
else
    log_error "  ✗ LOGIN_UNAME not set"
    exit 1
fi
if [[ -n "${YourSSHPortNumber:-}" ]]; then
    log_info "  ✓ YourSSHPortNumber=$YourSSHPortNumber"
else
    log_error "  ✗ YourSSHPortNumber not set"
    exit 1
fi

# Test 3: Verify run_1.sh syntax
log_info "Test 3: Verify run_1.sh syntax..."
if bash -n "$PROJECT_ROOT/run_1.sh"; then
    log_info "  ✓ Syntax valid"
else
    log_error "  ✗ Syntax error in run_1.sh"
    exit 1
fi

# Test 4: Source common functions and verify they load
log_info "Test 4: Verify common functions..."
source_common_functions

functions_to_check=(
    "log_info" "log_error" "require_root" "check_system_compatibility"
    "configure_ssh" "generate_secure_password" "setup_secure_user"
    "configure_sudo_nopasswd" "secure_config_files" "apply_network_security"
)
for func in "${functions_to_check[@]}"; do
    if declare -f "$func" >/dev/null 2>&1; then
        log_info "  ✓ $func"
    else
        log_error "  ✗ Missing function: $func"
        exit 1
    fi
done

# Test 5: Verify security script exists and has valid syntax
log_info "Test 5: Verify security scripts..."
security_scripts=(
    "install/security/consolidated_security.sh"
    "install/security/nginx_harden.sh"
    "install/security/caddy_harden.sh"
)
for script in "${security_scripts[@]}"; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            log_info "  ✓ $script (exists, syntax valid)"
        else
            log_error "  ✗ $script has syntax errors"
            exit 1
        fi
    else
        log_error "  ✗ Missing: $script"
        exit 1
    fi
done

# Test 6: Test generate_secure_password function
log_info "Test 6: Test generate_secure_password..."
password=$(generate_secure_password 16)
if [[ ${#password} -ge 16 ]]; then
    log_info "  ✓ Generated password (${#password} chars)"
else
    log_error "  ✗ Password generation failed"
    exit 1
fi

# Test 7: Test apt update works (basic system test)
log_info "Test 7: Test apt update..."
if apt-get update -qq 2>/dev/null; then
    log_info "  ✓ apt-get update works"
else
    log_warn "  ⚠ apt-get update had issues"
fi

# Test 8: Test user creation
log_info "Test 8: Test user creation..."
TEST_USER="ci_test_user_$$"
if useradd -m -s /bin/bash "$TEST_USER" 2>/dev/null; then
    log_info "  ✓ User creation works"
    userdel -r "$TEST_USER" 2>/dev/null || true
else
    log_warn "  ⚠ User creation had issues"
fi

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  ✓ run_1.sh CI Test PASSED                                    ║"
log_info "║  Validated: Structure, syntax, functions, basic operations    ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
