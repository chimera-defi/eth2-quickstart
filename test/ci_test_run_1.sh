#!/bin/bash
# CI Test Script for run_1.sh (Phase 1 - System Setup)
# Runs inside Docker container as root
# Tests that run_1.sh executes without errors

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
log_info "║  CI Test: run_1.sh (Phase 1 - System Setup)                   ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

# Verify we're running as root (required for run_1.sh)
if [[ $EUID -ne 0 ]]; then
    log_error "This test must run as root"
    exit 1
fi
log_info "✓ Running as root"

# Verify we're in Docker
if [[ ! -f /.dockerenv ]] && ! grep -q docker /proc/1/cgroup 2>/dev/null; then
    log_warn "Not running in Docker - this test may affect your system!"
fi

cd "$PROJECT_ROOT"

# Verify required files exist
log_info "Checking required files..."
for file in run_1.sh exports.sh lib/common_functions.sh; do
    if [[ -f "$file" ]]; then
        log_info "  ✓ $file"
    else
        log_error "  ✗ Missing: $file"
        exit 1
    fi
done

# Source exports to get variables
log_info "Loading configuration..."
source ./exports.sh
log_info "  LOGIN_UNAME=$LOGIN_UNAME"
log_info "  YourSSHPortNumber=$YourSSHPortNumber"

# Test 1: Verify run_1.sh syntax
log_info "Test 1: Verify run_1.sh syntax..."
if bash -n run_1.sh; then
    log_info "  ✓ Syntax valid"
else
    log_error "  ✗ Syntax error in run_1.sh"
    exit 1
fi

# Test 2: Run run_1.sh
log_info "Test 2: Execute run_1.sh..."
log_info "  This will perform full system setup (SSH, user, security)..."

# Run the actual script
if bash run_1.sh; then
    log_info "  ✓ run_1.sh completed successfully"
else
    exit_code=$?
    log_error "  ✗ run_1.sh failed with exit code $exit_code"
    exit $exit_code
fi

# Test 3: Verify run_1.sh results
log_info "Test 3: Verify run_1.sh results..."

# Check user was created
if id "$LOGIN_UNAME" &>/dev/null; then
    log_info "  ✓ User $LOGIN_UNAME exists"
else
    log_error "  ✗ User $LOGIN_UNAME was not created"
    exit 1
fi

# Check sudoers
if sudo -l -U "$LOGIN_UNAME" 2>/dev/null | grep -q "NOPASSWD"; then
    log_info "  ✓ User has NOPASSWD sudo"
else
    log_warn "  ⚠ Could not verify NOPASSWD sudo"
fi

# Check UFW installed
if command -v ufw &>/dev/null; then
    log_info "  ✓ UFW is installed"
else
    log_warn "  ⚠ UFW not found"
fi

# Check fail2ban installed
if command -v fail2ban-client &>/dev/null; then
    log_info "  ✓ fail2ban is installed"
else
    log_warn "  ⚠ fail2ban not found"
fi

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  ✓ run_1.sh CI Test PASSED                                    ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
