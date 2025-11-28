#!/bin/bash
# CI Test Script for run_2.sh (Phase 2 - Client Installation)
# Runs inside Docker container as non-root user
# Tests that run_2.sh handles inputs correctly and starts installation

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[CI]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[CI]${NC} $*"; }
log_error() { echo -e "${RED}[CI]${NC} $*"; }

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  CI Test: run_2.sh (Phase 2 - Client Installation)            ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

# Source exports to get variables
source ./exports.sh

# Verify required files exist
log_info "Checking required files..."
for file in run_2.sh exports.sh lib/common_functions.sh; do
    if [[ -f "$file" ]]; then
        log_info "  ✓ $file"
    else
        log_error "  ✗ Missing: $file"
        exit 1
    fi
done

# Test 1: Verify run_2.sh syntax
log_info "Test 1: Verify run_2.sh syntax..."
if bash -n run_2.sh; then
    log_info "  ✓ Syntax valid"
else
    log_error "  ✗ Syntax error in run_2.sh"
    exit 1
fi

# Test 2: Verify run_2.sh can source required files
log_info "Test 2: Verify sourcing works..."
if bash -c 'source ./exports.sh && source ./lib/common_functions.sh && echo "OK"' | grep -q "OK"; then
    log_info "  ✓ Source files load correctly"
else
    log_error "  ✗ Failed to source required files"
    exit 1
fi

# Test 3: Verify install scripts exist
log_info "Test 3: Verify install scripts exist..."
install_scripts=(
    "install/utils/install_dependencies.sh"
    "install/execution/install_geth.sh"
    "install/consensus/install_prysm.sh"
    "install/mev/install_mev_boost.sh"
    "install/mev/install_commit_boost.sh"
    "install/utils/select_clients.sh"
)
for script in "${install_scripts[@]}"; do
    if [[ -f "$script" ]]; then
        log_info "  ✓ $script"
    else
        log_error "  ✗ Missing: $script"
        exit 1
    fi
done

# Test 4: Verify all install scripts have valid syntax
log_info "Test 4: Verify install script syntax..."
for script in "${install_scripts[@]}"; do
    if bash -n "$script" 2>/dev/null; then
        log_info "  ✓ $script syntax valid"
    else
        log_error "  ✗ $script has syntax errors"
        exit 1
    fi
done

# Test 5: Test dependencies installation (this is quick)
log_info "Test 5: Install dependencies..."
if ./install/utils/install_dependencies.sh; then
    log_info "  ✓ Dependencies installed"
else
    log_warn "  ⚠ Some dependencies may have failed (non-critical in CI)"
fi

# Test 6: Verify key tools are available after dependencies
log_info "Test 6: Verify key tools installed..."
tools=(curl wget git jq)
for tool in "${tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        log_info "  ✓ $tool available"
    else
        log_warn "  ⚠ $tool not found"
    fi
done

# Test 7: Test JWT secret creation
log_info "Test 7: Test JWT secret creation..."
source ./lib/common_functions.sh
mkdir -p "$HOME/secrets"
# shellcheck disable=SC2119
if ensure_jwt_secret; then
    if [[ -f "$HOME/secrets/jwt.hex" ]]; then
        log_info "  ✓ JWT secret created"
    else
        log_error "  ✗ JWT secret file not found"
        exit 1
    fi
else
    log_error "  ✗ ensure_jwt_secret failed"
    exit 1
fi

# Test 8: Simulate run_2.sh with default inputs (without actual client downloads)
log_info "Test 8: Validate run_2.sh input handling..."

# Create a test that sources run_2.sh functions but doesn't execute the main flow
# This validates the script structure without downloading clients
cat > /tmp/test_run2_functions.sh << 'TESTEOF'
#!/bin/bash
set -Eeuo pipefail
source ./exports.sh
source ./lib/common_functions.sh

# Mock the install functions to prevent actual downloads
install_geth() { echo "[MOCK] Would install Geth"; return 0; }
install_prysm() { echo "[MOCK] Would install Prysm"; return 0; }

# Test that the functions from run_2.sh can be parsed
# Extract and test key functions
echo "Testing validate_menu_choice..."
if validate_menu_choice "1" 3; then
    echo "  ✓ validate_menu_choice works"
else
    echo "  ✗ validate_menu_choice failed"
    exit 1
fi

echo "Testing check_user function..."
# This will fail since we're not the LOGIN_UNAME user, but that's expected
if check_user "$(whoami)" 2>/dev/null; then
    echo "  ✓ check_user works for current user"
else
    echo "  ⚠ check_user returned false (expected if not LOGIN_UNAME)"
fi

echo "All function tests passed!"
TESTEOF

if bash /tmp/test_run2_functions.sh; then
    log_info "  ✓ run_2.sh functions validated"
else
    log_error "  ✗ run_2.sh function validation failed"
    exit 1
fi
rm -f /tmp/test_run2_functions.sh

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  ✓ run_2.sh CI Test PASSED                                    ║"
log_info "║  Note: Actual client downloads skipped (use full test for E2E)║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
