#!/bin/bash
# run_2.sh - Structure
# run_2.sh = Phase 2 (client install, non-root). Structure validation only. E2E in run_e2e.sh --phase=2.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  run_2.sh - Structure                                         ║"
log_info "╚════════════════════════════════════════════════════════════════╝"

# Verify we're running as non-root (required for run_2.sh)
if is_root; then
    log_error "This test must run as non-root (run_2.sh requires regular user)"
    exit 1
fi
log_info "✓ Running as $(whoami)"

cd "$PROJECT_ROOT" || exit 1

# Need common_functions for ensure_directory before creating config
source_common_functions

# Override LOGIN_UNAME for Docker testuser (exports.sh loads config/user_config.env)
ensure_directory config
echo "export LOGIN_UNAME='$(whoami)'" > config/user_config.env

source_exports

# Structure validation only - no actual installs. E2E (actual execution) is in ci_test_e2e.sh
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

# Test 2b: Verify --help exits before log side effects
log_info "Test 2b: Verify run_2.sh --help is clean..."
log_dir="$PROJECT_ROOT/logs"
before_count=0
if [[ -d "$log_dir" ]]; then
    before_count=$(find "$log_dir" -maxdepth 1 -type f -name 'run_2_*.log' | wc -l)
fi

if bash "$PROJECT_ROOT/run_2.sh" --help | grep -q "Phase 2: client installation"; then
    log_info "  ✓ --help output is available"
else
    log_error "  ✗ run_2.sh --help missing expected output"
    exit 1
fi

after_count=0
if [[ -d "$log_dir" ]]; then
    after_count=$(find "$log_dir" -maxdepth 1 -type f -name 'run_2_*.log' | wc -l)
fi
if [[ "$after_count" -eq "$before_count" ]]; then
    log_info "  ✓ --help does not create run_2 logs"
else
    log_error "  ✗ --help created a run_2 log file"
    exit 1
fi

# Test 3: Verify ALL install scripts exist and have valid syntax
# Covers: execution (7), consensus (6), MEV (3), web (caddy, nginx), utils
log_info "Test 3: Verify all install scripts (syntax)..."
syntax_fail=0
for script in "${CLIENT_SCRIPTS[@]}" "install/utils/install_dependencies.sh" "install/utils/select_clients.sh" "install/web/install_caddy.sh" "install/web/install_nginx.sh"; do
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

# Service helper regressions (must exist for install/utils/*.sh commands)
for fn in start_all_services restart_all_services show_service_status choose_mev_stack; do
    if declare -f "$fn" >/dev/null 2>&1; then
        log_info "  ✓ $fn exists"
    else
        log_error "  ✗ Missing function: $fn"
        exit 1
    fi
done

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

# Test 5b: MEV service naming consistency in doctor utility
log_info "Test 5b: Verify doctor MEV service naming..."
if grep -q 'check_service "mev"' "$PROJECT_ROOT/install/utils/doctor.sh" && \
   ! grep -q 'check_service "mev-boost"' "$PROJECT_ROOT/install/utils/doctor.sh"; then
    log_info "  ✓ doctor.sh checks mev unit name"
else
    log_error "  ✗ doctor.sh MEV service name mismatch"
    exit 1
fi

# Test 6: Create JWT secret
log_info "Test 6: Test JWT secret creation..."
jwt_file="$HOME/secrets/jwt.hex"
ensure_directory "$HOME/secrets"
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
    assert_file_exists "$PROJECT_ROOT/$config" "$config" || exit 1
done

# Test 8: Besu config should not include deprecated/removed options
log_info "Test 8: Verify Besu config compatibility..."
if grep -q "fast-sync-min-peers" "$PROJECT_ROOT/configs/besu/besu_base.toml"; then
    log_error "  ✗ configs/besu/besu_base.toml contains deprecated key: fast-sync-min-peers"
    exit 1
else
    log_info "  ✓ Besu config does not include deprecated fast-sync-min-peers"
fi

# Test 9: Prysm install script must configure checkpoint URL-based sync
log_info "Test 9: Verify Prysm checkpoint-sync URL configuration..."
if grep -q "checkpoint-sync-url: \\$PRYSM_CPURL" "$PROJECT_ROOT/install/consensus/prysm.sh" && \
   grep -q "genesis-beacon-api-url: \\$PRYSM_CPURL" "$PROJECT_ROOT/install/consensus/prysm.sh" && \
   ! grep -q "checkpoint-block" "$PROJECT_ROOT/install/consensus/prysm.sh"; then
    log_info "  ✓ Prysm script uses checkpoint URL config and no legacy SSZ checkpoint flags"
else
    log_error "  ✗ Prysm script checkpoint sync config is missing or contains legacy SSZ flag usage"
    exit 1
fi

# Test 10: SSL scripts should call canonical install/web paths
log_info "Test 10: Verify SSL script path correctness..."
if grep -q "./install/web/install_nginx.sh" "$PROJECT_ROOT/install/ssl/install_acme_ssl.sh" && \
   grep -q "./install/web/install_nginx_ssl.sh" "$PROJECT_ROOT/install/ssl/install_acme_ssl.sh" && \
   grep -q "./install/web/install_nginx.sh" "$PROJECT_ROOT/install/ssl/install_ssl_certbot.sh" && \
   grep -q "./install/web/install_nginx_ssl.sh" "$PROJECT_ROOT/install/ssl/install_ssl_certbot.sh"; then
    log_info "  ✓ SSL scripts use canonical install/web script paths"
else
    log_error "  ✗ SSL scripts contain stale nginx script paths"
    exit 1
fi

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  run_2.sh - Structure PASSED                                  ║"
log_info "║  Full E2E: ./test/run_e2e.sh --phase=2                        ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
exit 0
