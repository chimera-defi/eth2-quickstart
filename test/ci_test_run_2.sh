#!/bin/bash
# CI Test Script for run_2.sh (Phase 2 - Client Installation)
# Runs inside Docker container
# Tests full E2E installation: Dependencies + Geth + Prysm + MEV-Boost
# Expected runtime: ~5-7 minutes

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
log_info "║  CI Test: run_2.sh (Phase 2 - Full E2E Installation)          ║"
log_info "║  Expected runtime: ~5-7 minutes                               ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

# Source exports to get variables
source ./exports.sh
source ./lib/common_functions.sh

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

# Test 2: Install dependencies
log_info "Test 2: Install dependencies (~1-2 min)..."
if ./install/utils/install_dependencies.sh; then
    log_info "  ✓ Dependencies installed"
else
    log_error "  ✗ Dependencies installation failed"
    exit 1
fi

# Test 3: Verify key tools are available
log_info "Test 3: Verify key tools installed..."
tools=(curl wget git jq go)
for tool in "${tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        log_info "  ✓ $tool available"
    else
        log_error "  ✗ $tool not found"
        exit 1
    fi
done

# Test 4: Create JWT secret
log_info "Test 4: Create JWT secret..."
mkdir -p "$HOME/secrets"
# shellcheck disable=SC2119
if ensure_jwt_secret; then
    log_info "  ✓ JWT secret created"
else
    log_error "  ✗ JWT secret creation failed"
    exit 1
fi

# Test 5: Install Geth via PPA (~30s)
log_info "Test 5: Install Geth (~30s)..."
if ./install/execution/install_geth.sh; then
    log_info "  ✓ Geth installed"
else
    log_error "  ✗ Geth installation failed"
    exit 1
fi

# Verify Geth binary
if command -v geth &>/dev/null; then
    log_info "  ✓ Geth binary available: $(geth version | head -1)"
else
    log_error "  ✗ Geth binary not found"
    exit 1
fi

# Test 6: Install Prysm (~1-2 min)
log_info "Test 6: Install Prysm (~1-2 min)..."
if ./install/consensus/install_prysm.sh; then
    log_info "  ✓ Prysm installed"
else
    log_error "  ✗ Prysm installation failed"
    exit 1
fi

# Verify Prysm script
if [[ -x "$HOME/prysm/prysm.sh" ]]; then
    log_info "  ✓ Prysm script available"
else
    log_error "  ✗ Prysm script not found"
    exit 1
fi

# Test 7: Install MEV-Boost (~2-3 min)
log_info "Test 7: Install MEV-Boost (~2-3 min)..."
if ./install/mev/install_mev_boost.sh; then
    log_info "  ✓ MEV-Boost installed"
else
    log_error "  ✗ MEV-Boost installation failed"
    exit 1
fi

# Verify MEV-Boost binary
if [[ -x "$HOME/mev-boost/mev-boost" ]]; then
    log_info "  ✓ MEV-Boost binary available"
else
    log_error "  ✗ MEV-Boost binary not found"
    exit 1
fi

# Test 8: Verify systemd services were created
log_info "Test 8: Verify systemd services..."
services=(eth1 cl validator mev)
for svc in "${services[@]}"; do
    if [[ -f "/etc/systemd/system/${svc}.service" ]]; then
        log_info "  ✓ ${svc}.service exists"
    else
        log_warn "  ⚠ ${svc}.service not found (may require root)"
    fi
done

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  ✓ run_2.sh Full E2E Test PASSED                              ║"
log_info "║  Installed: Geth, Prysm, MEV-Boost                            ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
