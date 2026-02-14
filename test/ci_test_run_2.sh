#!/bin/bash
# CI Test Script for run_2.sh (Phase 2 - Client Installation)
# Runs inside Docker container as non-root (testuser)
# Tests script structure, client install scripts, and run_2.sh flag flow

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  CI Test: run_2.sh (Phase 2 - Structure Validation)           ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

# Verify we're running as non-root (required for run_2.sh)
if is_root; then
    log_error "This test must run as non-root (run_2.sh requires regular user)"
    exit 1
fi
log_info "✓ Running as $(whoami)"

cd "$PROJECT_ROOT"

source_exports
source_common_functions

# Install all dependencies first (like run_2.sh does when not using --skip-deps)
# Ensures Rust, Go, Node, etc. are available for all client installs
log_info "Installing dependencies (install_dependencies --production)..."
export CI_E2E=true
if ! "$PROJECT_ROOT/install/utils/install_dependencies.sh" --production; then
    log_error "Failed to install dependencies"
    exit 1
fi
log_info "✓ Dependencies installed"

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
# Dependencies installed above. Each script: source, check_requirements, firewall, download, systemd.
# Path/source errors and install failures both cause CI failure.
log_info "Test 8: Run all client install scripts (execution + consensus + MEV)..."
load_fail=0
install_fail=0
total=${#CLIENT_SCRIPTS[@]}
idx=0
for script in "${CLIENT_SCRIPTS[@]}"; do
    [[ -f "$PROJECT_ROOT/$script" ]] || continue
    idx=$((idx + 1))
    log_info "  [$idx/$total] Running $(basename "$script")..."
    script_log="/tmp/ci_client_$$_${idx}.log"
    set +e
    "$PROJECT_ROOT/$script" 2>&1 | tee "$script_log"
    exit_code=${PIPESTATUS[0]}
    set -e
    output=$(cat "$script_log")
    rm -f "$script_log"
    if output_has_path_errors "$output"; then
        log_error "  ✗ $(basename "$script"): path/source error (exit=$exit_code)"
        dump_output_tail "$output" 30 "    "
        load_fail=$((load_fail + 1))
    elif [[ $exit_code -ne 0 ]]; then
        log_error "  ✗ $(basename "$script"): install failed (exit=$exit_code)"
        dump_output_tail "$output" 30 "    "
        install_fail=$((install_fail + 1))
    else
        log_info "  ✓ $(basename "$script"): installed (exit=0)"
    fi
done
if [[ $load_fail -gt 0 ]]; then
    log_error "  $load_fail script(s) had path/source errors - CI fails"
    exit 1
fi
if [[ $install_fail -gt 0 ]]; then
    log_error "  $install_fail script(s) failed to install - CI fails"
    exit 1
fi

# Test 9: run_2.sh with --execution --consensus --mev flags (non-interactive)
log_info "Test 9: run_2.sh with flags (--execution --consensus --mev)..."
mkdir -p "$PROJECT_ROOT/config"
echo "export LOGIN_UNAME='$(whoami)'" > "$PROJECT_ROOT/config/user_config.env"
run2_log="/tmp/run2_ci_$$.log"
if ! run_script_with_log "$run2_log" "$PROJECT_ROOT/run_2.sh" --execution=geth --consensus=prysm --mev=mev-boost --skip-deps; then
    log_error "  ✗ run_2.sh failed"
    dump_log_tail "$run2_log" 50 "    "
    rm -f "$run2_log"
    exit 1
fi
rm -f "$run2_log"
log_info "  ✓ run_2.sh flag flow completed"

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  ✓ run_2.sh CI Test PASSED                                    ║"
log_info "║  Validated: 16 client scripts + run_2.sh flags (geth+prysm+mev-boost) ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
