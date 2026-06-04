#!/bin/bash
# E2E Test - Executes run_1.sh (Phase 1) or run_2.sh (Phase 2) and verifies results
# Phase 1 = run_1.sh (system setup, root). Phase 2 = run_2.sh (client install, testuser).
# Run inside Docker with systemd. Requires PHASE=1|2 set by run_e2e.sh.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

LOG_PREFIX="E2E"
PHASE="${PHASE:-}"

if [[ -z "$PHASE" ]] || [[ "$PHASE" != "1" && "$PHASE" != "2" ]]; then
    log_error "PHASE=1 or PHASE=2 required (set by run_e2e.sh)"
    exit 1
fi

# run_1.sh = Phase 1, run_2.sh = Phase 2
log_header "run_${PHASE}.sh - E2E"
log_info "Running as: $(whoami)"

if ! command -v systemctl &>/dev/null; then
    log_error "systemctl not found - run container with systemd init"
    exit 1
fi

cd "$PROJECT_ROOT"

edge_http_code() {
    local host="$1"
    local path="$2"
    curl -sS -o /dev/null -w '%{http_code}' \
        -H "Host: ${host}" \
        "http://127.0.0.1${path}" || true
}

assert_http_code_any() {
    local label="$1"
    local actual_code="$2"
    shift 2

    local expected
    for expected in "$@"; do
        if [[ "$actual_code" == "$expected" ]]; then
            record_test "$label" "PASS"
            return 0
        fi
    done

    record_test "$label" "FAIL"
    log_error "Unexpected HTTP status for ${label}: ${actual_code} (expected: $*)"
    print_test_summary
    exit 1
}

wait_for_edge_listener() {
    local host="$1"
    local max_attempts="${2:-20}"

    for _ in $(seq 1 "$max_attempts"); do
        if curl -sS -o /dev/null -H "Host: ${host}" "http://127.0.0.1/rpc" 2>/dev/null; then
            return 0
        fi
        sleep 1
    done

    return 1
}

# =============================================================================
# PHASE 1: run_1.sh (system setup) - delegates to ci_test_run_1_e2e.sh (single source)
# =============================================================================
if [[ "$PHASE" == "1" ]]; then
    if ! is_root; then
        log_error "Phase 1 E2E must run as root"
        exit 1
    fi
    exec "$SCRIPT_DIR/ci_test_run_1_e2e.sh"
fi

# =============================================================================
# PHASE 2: run_2.sh (client installation) - E2E (template matches run_1)
# =============================================================================
if [[ "$PHASE" == "2" ]]; then
    mkdir -p config
    echo "export LOGIN_UNAME='$(whoami)'" > config/user_config.env
    export CI_E2E=true
    export DEBIAN_FRONTEND=noninteractive
    export DEBIAN_PRIORITY=critical

    # Re-apply debconf preseed (like Phase 1) to prevent tzdata/postfix/cron hangs
    log_header "Pre-seeding debconf (prevent tty hangs)"
    sudo bash "$PROJECT_ROOT/install/utils/debconf_preseed.sh"

    # Step 1a/1b: Dependency install (can be skipped in pre-baked Docker test image)
    # This keeps e2e focused on run_2/client wiring while preserving a force-reinstall option.
    if [[ "${E2E_FORCE_DEPS_INSTALL:-false}" == "true" ]]; then
        log_info "E2E_FORCE_DEPS_INSTALL=true; running full dependency installers"
    fi

    if [[ "${E2E_FORCE_DEPS_INSTALL:-false}" != "true" ]] && [[ -f /etc/ethqs-phase1-deps-ready ]] && [[ -f /etc/ethqs-phase2-deps-ready ]]; then
        log_header "Dependency install fast path (pre-baked image markers found)"
        # Rust tools are installed in user space; ensure non-login shell resolves them.
        export PATH="$HOME/.cargo/bin:$PATH"
        verify_installed "phase1 deps marker" test -f /etc/ethqs-phase1-deps-ready
        verify_installed "phase2 deps marker" test -f /etc/ethqs-phase2-deps-ready
        verify_installed "base tool: curl" command -v curl
        verify_installed "base tool: jq" command -v jq
        verify_installed "phase2 tool: cargo" command -v cargo
        verify_installed "phase2 tool: rustup" command -v rustup
        record_test "install_dependencies (phase1)" "PASS"
        record_test "install_dependencies (phase2)" "PASS"
    else
        # In production, run_1.sh does this as root. In Docker E2E, testuser has sudo.
        log_header "Installing system dependencies (Phase 1)"
        if ! sudo bash "$PROJECT_ROOT/install/utils/install_dependencies.sh" --phase1; then
            record_test "install_dependencies (phase1)" "FAIL"
            print_test_summary
            exit 1
        fi
        record_test "install_dependencies (phase1)" "PASS"

        log_header "Installing user-level tools (Phase 2)"
        if ! "$PROJECT_ROOT/install/utils/install_dependencies.sh" --phase2; then
            record_test "install_dependencies (phase2)" "FAIL"
            print_test_summary
            exit 1
        fi
        record_test "install_dependencies (phase2)" "PASS"
    fi

    # Step 2: Run run_2.sh (client selection via E2E_* env or defaults)
    E2E_EXEC="${E2E_EXECUTION:-geth}"
    E2E_CONS="${E2E_CONSENSUS:-prysm}"
    E2E_MEV="${E2E_MEV:-mev-boost}"
    E2E_ETHGAS_FLAG="${E2E_ETHGAS:-false}"

    # Docker E2E runs inside a systemd container without a nested Docker daemon.
    # Production/install defaults still prefer prebuilt images; this explicit test-only
    # override ensures ETHGas can be exercised end-to-end in CI when requested.
    if [[ "$E2E_ETHGAS_FLAG" == "true" && "${CI_E2E:-false}" == "true" ]]; then
        export ETHGAS_INSTALL_METHOD="${ETHGAS_INSTALL_METHOD:-source}"
        log_info "CI_E2E ETHGas: using ETHGAS_INSTALL_METHOD=$ETHGAS_INSTALL_METHOD"
    fi

    # Build run_2.sh command with optional flags
    RUN2_CMD=("$PROJECT_ROOT/run_2.sh" --execution="$E2E_EXEC" --consensus="$E2E_CONS" --mev="$E2E_MEV" --skip-deps)
    [[ "$E2E_ETHGAS_FLAG" == "true" ]] && RUN2_CMD+=(--ethgas)

    log_header "Executing run_2.sh ($E2E_EXEC + $E2E_CONS + $E2E_MEV${E2E_ETHGAS_FLAG:+ + ethgas})"
    run2_log="/tmp/run2_e2e_$$.log"
    if ! run_script_with_log "$run2_log" "${RUN2_CMD[@]}"; then
        record_test "run_2.sh execution" "FAIL"
        dump_log_tail "$run2_log" 50 "  "
        rm -f "$run2_log"
        print_test_summary
        exit 1
    fi
    rm -f "$run2_log"
    record_test "run_2.sh execution" "PASS"

    # Dummy keys (lighthouse+commit-boost): created by run_2.sh before Commit-Boost install
    # so signer starts during install — no post-install step needed

    log_header "Verifying run_2.sh Results"

    # Verify execution client
    case "$E2E_EXEC" in
        geth) verify_installed "Geth" command -v geth ;;
        besu) verify_installed "Besu" test -f "$HOME/besu/bin/besu" ;;
        nethermind) verify_installed "Nethermind" test -d "$HOME/nethermind" ;;
        nimbus_eth1) verify_installed "Nimbus-eth1" test -d "$HOME/nimbus-eth1" ;;
        erigon) verify_installed "Erigon" test -f "$HOME/erigon/erigon" ;;
        reth) verify_installed "Reth" test -f "$HOME/reth/reth" ;;
        ethrex) verify_installed "Ethrex" test -f "$HOME/ethrex/ethrex" ;;
        *) verify_installed "Execution client" command -v geth ;;
    esac

    # Verify consensus client
    case "$E2E_CONS" in
        prysm) verify_installed "Prysm" test -f "$HOME/prysm/prysm.sh" ;;
        lighthouse) verify_installed "Lighthouse" test -f "$HOME/lighthouse/lighthouse" ;;
        teku) verify_installed "Teku" test -f "$HOME/teku/bin/teku" ;;
        nimbus) verify_installed "Nimbus" test -f "$HOME/nimbus/build/nimbus_beacon_node" ;;
        lodestar) verify_installed "Lodestar" test -f "$HOME/lodestar/node_modules/.bin/lodestar" ;;
        grandine) verify_installed "Grandine" test -f "$HOME/grandine/grandine" ;;
        *) verify_installed "Consensus client" test -f "$HOME/prysm/prysm.sh" ;;
    esac

    # Verify MEV (if not none)
    if [[ "$E2E_MEV" != "none" ]]; then
        case "$E2E_MEV" in
            mev-boost)
                verify_installed "MEV-Boost" test -f "$HOME/mev-boost/mev-boost"
                _verify_service_active "mev" 30
                ;;
            commit-boost)
                verify_installed "Commit-Boost" test -f "$HOME/commit-boost/commit-boost-pbs"
                # shellcheck disable=SC2016
                verify_installed "commit-boost-pbs service registered" bash -c 'systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk "{print \$1}" | grep -Fxq "commit-boost-pbs.service"'
                # shellcheck disable=SC2016
                verify_installed "commit-boost-signer service registered" bash -c 'systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk "{print \$1}" | grep -Fxq "commit-boost-signer.service"'
                _verify_service_active "commit-boost-pbs" 30
                # For clients with dummy key generation support, signer must be active.
                if [[ "$E2E_CONS" == "lighthouse" || "$E2E_CONS" == "prysm" ]]; then
                    _verify_service_active "commit-boost-signer" 30
                    if [[ "$E2E_CONS" == "lighthouse" ]]; then
                        if [[ -n "$(find "$HOME/.lighthouse/mainnet/validators" -name "*.json" -maxdepth 3 2>/dev/null | head -1)" ]]; then
                            record_test "Dummy validator keys (run_2 created before Commit-Boost)" "PASS"
                        else
                            record_test "Dummy validator keys (run_2 created before Commit-Boost)" "FAIL"
                        fi
                    fi
                    if [[ "$E2E_CONS" == "prysm" ]]; then
                        if [[ -s "$HOME/.eth2validators/prysm-wallet-v2/direct/accounts/all-accounts.keystore.json" ]]; then
                            record_test "Dummy validator keys (prysm wallet keystore created)" "PASS"
                        else
                            record_test "Dummy validator keys (prysm wallet keystore created)" "FAIL"
                        fi
                    fi
                else
                    # Other clients may not have non-interactive key import in CI yet.
                    if systemctl is-enabled --quiet commit-boost-signer 2>/dev/null; then
                        _verify_service_active "commit-boost-signer" 30
                    else
                        record_test "commit-boost-signer deferred (no validator keys yet)" "PASS"
                    fi
                fi
                ;;
            *) verify_installed "MEV" test -f "$HOME/mev-boost/mev-boost" ;;
        esac
    fi

    # ETHGas is optional with Commit-Boost; validate if present
    if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "ethgas.service"; then
        _verify_service_active "ethgas" 30
    fi

    verify_installed "JWT secret" test -f "$HOME/secrets/jwt.hex"
    verify_installed "eth1 systemd service" bash -c 'systemctl list-unit-files 2>/dev/null | grep -q "eth1.service"'

    # Block: verify core services are actually running (not just installed)
    _verify_service_active "eth1" 60
    _verify_service_active "cl" 60
    if systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "validator.service"; then
        _verify_service_active "validator" 60
    fi

    if [[ "$E2E_EXEC" == "geth" && "$E2E_CONS" == "prysm" ]]; then
        log_header "Running validator withdrawal change helper smoke test"
        if bash "$PROJECT_ROOT/install/test/test_validator_withdrawal_changes.sh"; then
            record_test "validator withdrawal change helper smoke" "PASS"
        else
            record_test "validator withdrawal change helper smoke" "FAIL"
            print_test_summary
            exit 1
        fi
    fi

    # Optional live Prysm checkpoint-sync smoke (opt-in).
    if [[ "$E2E_CONS" == "prysm" && "${E2E_PRYSM_CHECKPOINT_SMOKE:-false}" == "true" ]]; then
        log_header "Running Prysm checkpoint-sync smoke test"
        if sudo HOME="$HOME" ENABLE_PRYSM_CHECKPOINT_SMOKE=true \
            PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG="${PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG:-false}" \
            bash "$PROJECT_ROOT/test/prysm_checkpoint_smoke.sh"; then
            record_test "prysm checkpoint-sync smoke" "PASS"
        else
            record_test "prysm checkpoint-sync smoke" "FAIL"
            print_test_summary
            exit 1
        fi
    fi

    # Caddy and Nginx — always install in Docker E2E (no skip)
    log_header "Installing and verifying Caddy"
    if ! run_script_with_log "/tmp/caddy_e2e_$$.log" "$PROJECT_ROOT/install/web/install_caddy.sh"; then
        record_test "install_caddy" "FAIL"
        dump_log_tail "/tmp/caddy_e2e_$$.log" 50 "  "
        rm -f "/tmp/caddy_e2e_$$.log"
        print_test_summary
        exit 1
    fi
    rm -f "/tmp/caddy_e2e_$$.log"
    record_test "install_caddy" "PASS"
    verify_installed "Caddy" command -v caddy

    log_header "Caddy edge hardening smoke checks"
    edge_host="${SERVER_NAME:-rpc.sharedtools.org}"

    if ! wait_for_edge_listener "$edge_host" 20; then
        record_test "caddy listener readiness" "FAIL"
        log_error "Caddy did not accept HTTP connections for host ${edge_host} within timeout"
        print_test_summary
        exit 1
    fi
    record_test "caddy listener readiness" "PASS"

    caddy_spam_code="$(edge_http_code "$edge_host" "/acehd001/master.m3u8")"
    assert_http_code_any "caddy spam path blocked" "$caddy_spam_code" 403 404

    caddy_rpc_get_code="$(edge_http_code "$edge_host" "/rpc")"
    assert_http_code_any "caddy rpc method restriction" "$caddy_rpc_get_code" 405

    log_info "Stopping Caddy before Nginx (port conflict)"
    sudo systemctl stop caddy 2>/dev/null || true

    log_header "Installing and verifying Nginx"
    if ! run_script_with_log "/tmp/nginx_e2e_$$.log" "$PROJECT_ROOT/install/web/install_nginx.sh"; then
        record_test "install_nginx" "FAIL"
        dump_log_tail "/tmp/nginx_e2e_$$.log" 50 "  "
        rm -f "/tmp/nginx_e2e_$$.log"
        print_test_summary
        exit 1
    fi
    rm -f "/tmp/nginx_e2e_$$.log"
    record_test "install_nginx" "PASS"
    verify_installed "Nginx" command -v nginx

    log_header "Nginx cache + hardening E2E checks"

    nginx_spam_code="$(edge_http_code "$edge_host" "/acehd001/master.m3u8")"
    assert_http_code_any "nginx spam path blocked" "$nginx_spam_code" 403 404 000

    nginx_rpc_get_code="$(edge_http_code "$edge_host" "/rpc")"
    assert_http_code_any "nginx rpc method restriction" "$nginx_rpc_get_code" 405

    rpc_payload='{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'
    rpc_headers_1="/tmp/nginx_rpc_headers_1_$$.txt"
    rpc_headers_2="/tmp/nginx_rpc_headers_2_$$.txt"
    rpc_body_1="/tmp/nginx_rpc_body_1_$$.json"
    rpc_body_2="/tmp/nginx_rpc_body_2_$$.json"

    if ! curl -sS -D "$rpc_headers_1" -o "$rpc_body_1" \
        -H "Host: ${edge_host}" \
        -H "Content-Type: application/json" \
        --data "$rpc_payload" \
        "http://127.0.0.1/rpc"; then
        record_test "nginx rpc cache smoke request 1" "FAIL"
        print_test_summary
        exit 1
    fi

    if ! curl -sS -D "$rpc_headers_2" -o "$rpc_body_2" \
        -H "Host: ${edge_host}" \
        -H "Content-Type: application/json" \
        --data "$rpc_payload" \
        "http://127.0.0.1/rpc"; then
        record_test "nginx rpc cache smoke request 2" "FAIL"
        print_test_summary
        exit 1
    fi

    rpc_cache_header_2="$(grep -i '^X-RPC-Cache:' "$rpc_headers_2" | awk '{print toupper($2)}' | tr -d '\r' | head -1)"
    rpc_cache_bypass_2="$(grep -i '^X-RPC-Cache-Bypass:' "$rpc_headers_2" | awk '{print $2}' | tr -d '\r' | head -1)"

    if [[ "$rpc_cache_bypass_2" == "0" ]] && [[ "$rpc_cache_header_2" == "HIT" || "$rpc_cache_header_2" == "MISS" ]]; then
        record_test "nginx rpc cache classification" "PASS"
    else
        record_test "nginx rpc cache classification" "FAIL"
        log_error "Expected cacheable read call (bypass=0 and cache status HIT/MISS), got bypass=$rpc_cache_bypass_2 cache=$rpc_cache_header_2"
        print_test_summary
        exit 1
    fi

    if [[ "$rpc_cache_header_2" == "HIT" ]]; then
        record_test "nginx rpc cache hit" "PASS"
    else
        record_test "nginx rpc cache hit" "FAIL"
        log_error "Expected second eth_chainId request to be cache HIT, got: $rpc_cache_header_2"
        print_test_summary
        exit 1
    fi

    rm -f "$rpc_headers_1" "$rpc_headers_2" "$rpc_body_1" "$rpc_body_2"
fi

# =============================================================================
# SUMMARY - exit with failure code so CI fails on any FAIL
# =============================================================================
print_test_summary
exit $?
