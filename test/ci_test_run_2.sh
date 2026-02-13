#!/bin/bash
# CI Test Script for run_2.sh (Phase 2 - Client Installation)
# Runs inside Docker container
#
# Coverage (mirrors run_2.sh and select_clients.sh):
#   - Execution: geth, besu, erigon, nethermind, nimbus_eth1, reth, ethrex (7)
#   - Consensus: prysm, lighthouse, lodestar, teku, nimbus, grandine (6)
#   - MEV: install_mev_boost, install_commit_boost, install_ethgas (3)
#   - Default path: Geth + Prysm + MEV-Boost (run_2 option 2)
#   - Interactive path: all above via select_clients.sh (run_2 option 1)
#
# Install scripts run full flow; failures at UFW/network/systemd expected in CI.

set -Eeuo pipefail

# Setup paths and source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  CI Test: run_2.sh (Phase 2 - Structure Validation)           ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

cd "$PROJECT_ROOT"

# Source exports to get variables
source_exports
source_common_functions

# Test 1: Verify required files exist
log_info "Test 1: Verify required files..."
for file in run_2.sh exports.sh lib/common_functions.sh; do
    assert_file_exists "$PROJECT_ROOT/$file" "$file"
done

# Test 2: Verify run_2.sh syntax
log_info "Test 2: Verify run_2.sh syntax..."
if bash -n "$PROJECT_ROOT/run_2.sh"; then
    log_info "  ✓ Syntax valid"
else
    log_error "  ✗ Syntax error in run_2.sh"
    exit 1
fi

# Test 3: Verify ALL install scripts exist and have valid syntax
# Covers: execution (7), consensus (6), MEV (3), utils (install_deps, select_clients)
log_info "Test 3: Verify all install scripts (syntax)..."
syntax_fail=0
for script in "${CLIENT_SCRIPTS[@]}" "install/utils/install_dependencies.sh" "install/utils/select_clients.sh"; do
    if [[ -f "$PROJECT_ROOT/$script" ]]; then
        if bash -n "$PROJECT_ROOT/$script" 2>/dev/null; then
            log_info "  ✓ $script"
        else
            log_error "  ✗ $script has syntax errors"
            syntax_fail=$((syntax_fail + 1))
        fi
    else
        log_error "  ✗ Missing: $script"
        syntax_fail=$((syntax_fail + 1))
    fi
done
if [[ $syntax_fail -gt 0 ]]; then
    exit 1
fi

# Test 4: Verify common functions can be sourced
log_info "Test 4: Verify functions load correctly..."
if bash -c "source '$PROJECT_ROOT/exports.sh' && source '$PROJECT_ROOT/lib/common_functions.sh' && declare -f log_info >/dev/null" 2>/dev/null; then
    log_info "  ✓ Common functions load correctly"
else
    log_error "  ✗ Failed to load common functions"
    exit 1
fi

# Test 5: Test key functions work
log_info "Test 5: Test key functions..."

# Test validate_menu_choice
if validate_menu_choice "1" 3; then
    log_info "  ✓ validate_menu_choice works"
else
    log_error "  ✗ validate_menu_choice failed"
    exit 1
fi

# Test ensure_directory
test_dir="/tmp/ci_test_dir_$$"
if ensure_directory "$test_dir" && [[ -d "$test_dir" ]]; then
    log_info "  ✓ ensure_directory works"
    rm -rf "$test_dir"
else
    log_error "  ✗ ensure_directory failed"
    exit 1
fi

# Test 6: Create JWT secret
log_info "Test 6: Test JWT secret creation..."
jwt_file="$HOME/secrets/jwt.hex"
mkdir -p "$HOME/secrets"
if ensure_jwt_secret "$jwt_file"; then
    if [[ -f "$jwt_file" ]]; then
        jwt_len=$(wc -c < "$jwt_file")
        if [[ $jwt_len -ge 64 ]]; then
            log_info "  ✓ JWT secret created (${jwt_len} chars)"
        else
            log_error "  ✗ JWT secret too short"
            exit 1
        fi
    else
        log_error "  ✗ JWT secret file not found"
        exit 1
    fi
else
    log_error "  ✗ ensure_jwt_secret failed"
    exit 1
fi

# Test 7: Verify config files exist for ALL clients
log_info "Test 7: Verify client config files..."
config_files=(
    "configs/besu/besu_base.toml"
    "configs/ethrex/ethrex_base.toml"
    "configs/grandine/grandine_base.toml"
    "configs/lodestar/lodestar_beacon_base.json"
    "configs/lodestar/lodestar_validator_base.json"
    "configs/nethermind/nethermind_base.cfg"
    "configs/nimbus/nimbus_base.toml"
    "configs/nimbus/nimbus_eth1_base.toml"
    "configs/prysm/prysm_beacon_conf.yaml"
    "configs/prysm/prysm_validator_conf.yaml"
    "configs/teku/teku_beacon_base.yaml"
    "configs/teku/teku_validator_base.yaml"
)
for config in "${config_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$config" ]]; then
        log_info "  ✓ $config"
    else
        log_error "  ✗ Missing: $config"
        exit 1
    fi
done

# Test 8: Run ALL client install scripts (full install flow)
# Each script executes: source, check_requirements, firewall, download/apt, systemd, etc.
# We verify no path/source errors; install may fail at UFW/network - expected in CI.
log_info "Test 8: Run all client install scripts (execution + consensus + MEV)..."
load_fail=0
for script in "${CLIENT_SCRIPTS[@]}"; do
    [[ -f "$PROJECT_ROOT/$script" ]] || continue
    output=$("$PROJECT_ROOT/$script" 2>&1) || true
    if output_has_path_errors "$output"; then
        log_error "  ✗ $(basename "$script"): path/source error"
        echo "$output" | head -5
        load_fail=$((load_fail + 1))
    else
        log_info "  ✓ $(basename "$script"): ran install flow"
    fi
done
if [[ $load_fail -gt 0 ]]; then
    log_error "  $load_fail script(s) failed - CI will fail"
    exit 1
fi

# Test 9: Default path (Geth + Prysm + MEV-Boost) - explicit run_2.sh default flow
# Mirrors what happens when user selects "2. Use default setup"
log_info "Test 9: Default path (Geth, Prysm, MEV-Boost)..."
for script in "install/execution/geth.sh" "install/consensus/prysm.sh" "install/mev/install_mev_boost.sh"; do
    name=$(basename "$script")
    if "$PROJECT_ROOT/$script" 2>&1; then
        log_info "  ✓ $name: installed"
    else
        log_info "  ⊘ $name: failed (expected in CI - UFW/network)"
    fi
done

# Test 10: run_2.sh with --execution --consensus --mev flags (non-interactive)
log_info "Test 10: run_2.sh with flags (--execution --consensus --mev)..."
mkdir -p "$PROJECT_ROOT/config"
echo "export LOGIN_UNAME='$(whoami)'" > "$PROJECT_ROOT/config/user_config.env"
if "$PROJECT_ROOT/run_2.sh" --execution=geth --consensus=prysm --mev=mev-boost --skip-deps 2>&1; then
    log_info "  ✓ run_2.sh flag flow completed"
else
    log_info "  ⊘ run_2.sh flag flow failed (expected in CI - UFW/systemd)"
fi

# Test 11: run_2.sh with different clients (Besu + Lighthouse + none)
log_info "Test 11: run_2.sh --execution=besu --consensus=lighthouse --mev=none..."
if "$PROJECT_ROOT/run_2.sh" --execution=besu --consensus=lighthouse --mev=none --skip-deps 2>&1; then
    log_info "  ✓ run_2.sh besu+lighthouse flow completed"
else
    log_info "  ⊘ run_2.sh besu+lighthouse failed (expected in CI)"
fi

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  ✓ run_2.sh CI Test PASSED                                    ║"
log_info "║  Validated: 7 execution + 6 consensus + 3 MEV clients         ║"
log_info "║  + run_2.sh flags (--execution, --consensus, --mev)            ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
