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

    # Step 1a: Install system dependencies (Phase 1 equivalent -- runs as root in Docker)
    # In production, run_1.sh does this as root. In Docker E2E, testuser has sudo.
    log_header "Installing system dependencies (Phase 1)"
    if ! sudo bash "$PROJECT_ROOT/install/utils/install_dependencies.sh" --phase1; then
        record_test "install_dependencies (phase1)" "FAIL"
        print_test_summary
        exit 1
    fi
    record_test "install_dependencies (phase1)" "PASS"

    # Step 1b: Install user-level tools (Phase 2)
    log_header "Installing user-level tools (Phase 2)"
    if ! "$PROJECT_ROOT/install/utils/install_dependencies.sh" --phase2; then
        record_test "install_dependencies (phase2)" "FAIL"
        print_test_summary
        exit 1
    fi
    record_test "install_dependencies (phase2)" "PASS"

    # Step 2: Run run_2.sh (client selection via E2E_* env or defaults)
    E2E_EXEC="${E2E_EXECUTION:-geth}"
    E2E_CONS="${E2E_CONSENSUS:-prysm}"
    E2E_MEV="${E2E_MEV:-mev-boost}"
    E2E_ETHGAS_FLAG="${E2E_ETHGAS:-false}"

    # Build run_2.sh command with optional flags
    RUN2_CMD=("$PROJECT_ROOT/run_2.sh" --execution="$E2E_EXEC" --consensus="$E2E_CONS" --mev="$E2E_MEV" --skip-deps)
    [[ "$E2E_ETHGAS_FLAG" == "true" ]] && RUN2_CMD+=(--ethgas)

    ETHGAS_LABEL=""
    [[ "$E2E_ETHGAS_FLAG" == "true" ]] && ETHGAS_LABEL=" + ethgas"
    log_header "Executing run_2.sh ($E2E_EXEC + $E2E_CONS + $E2E_MEV${ETHGAS_LABEL})"
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
            mev-boost) verify_installed "MEV-Boost" test -f "$HOME/mev-boost/mev-boost" ;;
            commit-boost)
                verify_installed "Commit-Boost PBS" test -f "$HOME/commit-boost/commit-boost-pbs"
                verify_installed "Commit-Boost Signer" test -f "$HOME/commit-boost/commit-boost-signer"
                verify_installed "Commit-Boost config" test -f "$HOME/commit-boost/config/cb-config.toml"
                verify_installed "Commit-Boost PBS service" bash -c 'systemctl list-unit-files 2>/dev/null | grep -q "commit-boost-pbs.service"'
                ;;
            *) verify_installed "MEV" test -f "$HOME/mev-boost/mev-boost" ;;
        esac
    fi

    # Verify ETHGas (if enabled)
    if [[ "$E2E_ETHGAS_FLAG" == "true" ]]; then
        verify_installed "ETHGas binary" test -f "$HOME/ethgas/target/release/ethgas_commit"
        verify_installed "ETHGas config" test -f "$HOME/ethgas/config/ethgas.toml"
        verify_installed "ETHGas service" bash -c 'systemctl list-unit-files 2>/dev/null | grep -q "ethgas.service"'
        verify_installed "Commit-Boost PBS (ETHGas dep)" test -f "$HOME/commit-boost/commit-boost-pbs"
        verify_installed "Rust/Cargo (ETHGas build)" bash -c 'command -v cargo &>/dev/null'
    fi

    verify_installed "JWT secret" test -f "$HOME/secrets/jwt.hex"
    verify_installed "eth1 systemd service" bash -c 'systemctl list-unit-files 2>/dev/null | grep -q "eth1.service"'

    # Caddy and Nginx (main job only - skip in client matrix to save time)
    if [[ -z "${E2E_EXECUTION:-}" && -z "${E2E_CONSENSUS:-}" ]]; then
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
    fi
fi

# =============================================================================
# SUMMARY - exit with failure code so CI fails on any FAIL
# =============================================================================
print_test_summary
exit $?
