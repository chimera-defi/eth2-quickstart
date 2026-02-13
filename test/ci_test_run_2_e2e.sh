#!/bin/bash
# E2E Test for run_2.sh - Actually executes run_2.sh and verifies results
# Run inside Docker with systemd: docker exec <container> /workspace/test/ci_test_run_2_e2e.sh
# Requires: CI_E2E=true, LOGIN_UNAME=testuser (or current user)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/test_utils.sh"

LOG_PREFIX="E2E"

log_header "run_2.sh End-to-End Test"
log_info "This test ACTUALLY runs run_2.sh and verifies the results"
log_info "Running as: $(whoami)"

if ! command -v systemctl &>/dev/null; then
    log_error "systemctl not found - run container with systemd init"
    exit 1
fi

cd "$PROJECT_ROOT"

# Ensure LOGIN_UNAME matches current user
mkdir -p config
echo "export LOGIN_UNAME='$(whoami)'" > config/user_config.env

# =============================================================================
# PHASE 1: Execute run_2.sh with flags
# =============================================================================
log_header "Phase 1: Executing run_2.sh (--execution=geth --consensus=prysm --mev=mev-boost)"

export CI_E2E=true
export DEBIAN_FRONTEND=noninteractive

if ./run_2.sh --execution=geth --consensus=prysm --mev=mev-boost --skip-deps; then
    record_test "run_2.sh executed successfully" "PASS"
else
    record_test "run_2.sh executed successfully" "FAIL"
    print_test_summary
    exit 1
fi

# =============================================================================
# PHASE 2: Verify Results
# =============================================================================
log_header "Phase 2: Verifying run_2.sh Results"

if command -v geth &>/dev/null; then
    record_test "Geth binary installed" "PASS"
else
    record_test "Geth binary installed" "FAIL"
fi

if [[ -f "$HOME/prysm/prysm.sh" ]]; then
    record_test "Prysm installed" "PASS"
else
    record_test "Prysm installed" "FAIL"
fi

if [[ -f "$HOME/mev-boost/mev-boost" ]]; then
    record_test "MEV-Boost installed" "PASS"
else
    record_test "MEV-Boost installed" "FAIL"
fi

if [[ -f "$HOME/secrets/jwt.hex" ]]; then
    record_test "JWT secret exists" "PASS"
else
    record_test "JWT secret exists" "FAIL"
fi

if systemctl list-unit-files 2>/dev/null | grep -q "eth1.service"; then
    record_test "eth1 systemd service created" "PASS"
else
    record_test "eth1 systemd service created" "FAIL"
fi

print_test_summary
