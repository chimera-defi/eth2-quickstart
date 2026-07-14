#!/bin/bash

# Eth2 Quick Start unified command wrapper
# Human + agent friendly entrypoint for common workflows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: ./scripts/eth2qs.sh <command> [args...]

Core lifecycle:
  bootstrap [args...]     Run one-line bootstrap installer (install.sh)
  configure [args...]     Run configuration wizard
  client-options [args...] Show supported client names and tested presets
  plan [args...]          Detect the next safe install step
  ensure [args...]        Preview or execute the next safe install step
  phase1 [args...]        Run run_1.sh (root/system hardening)
  phase2 [args...]        Run run_2.sh (node install/config)
  monad-install [args...] Run monad_install.sh (Monad install/config)

Operations:
  doctor [--json]         Run health checks (human output by default)
  debug [args...]         Show structured per-service debug details
  update-check [args...]  Compare repo/client versions to latest known releases
  monitor [args...]       Export or snapshot compact monitor summaries
  status                  Alias for: doctor
  start                   Start all node services
  repair [args...]        Preview or apply allowlisted smart repair actions
  stop                    Stop all node services
  restart                 Restart all node services
  stats [--json]          Show current service status and system stats
  logs [args...]          View run logs (passed to install/utils/view_logs.sh)
  clean-data [args...]    Purge default node data dirs (safe by default)
  cleanup-host [args...]  Purge root-managed node data dirs (requires root, preserves secrets)
  update-all [args...]    Comprehensive updater

Validator:
  validators [--json] [--min-balance N] [--max-balance N] [--withdrawal-type 0x00|0x01|0x02] [--status S]
                                   List active validators (filter by balance / withdrawal type / status)
  validator-exit                   Exit local validators using the managed exit flow
  validator-create-0x01            Create standard validators with 0x01 credentials
  validator-create-0x02            Create modern compounding validators with 0x02 credentials
  validator-deploy [opts]          Generate validator keys + deposit_data.json (0x01 or 0x02), import, print deposit cmd
  validator-manage [--exit|--consolidate|--eip7002-exit|--withdraw-change]   Manage validators: exits, EIP-7251/7002, credential changes
  validator-withdrawal-changes      Generate or submit BLS-to-execution changes for 0x00 validators

Utility:
  help                    Show this help text

Examples:
  ./scripts/eth2qs.sh bootstrap --non-interactive
  ./scripts/eth2qs.sh client-options --json
  ./scripts/eth2qs.sh plan --json
  ./scripts/eth2qs.sh ensure
  ./scripts/eth2qs.sh configure --interactive
  ./scripts/eth2qs.sh doctor --json
  ./scripts/eth2qs.sh debug --json --service cl
  ./scripts/eth2qs.sh stats --json
  ./scripts/eth2qs.sh update-check --json
  ./scripts/eth2qs.sh monitor export --json
  ./scripts/eth2qs.sh repair
  ./scripts/eth2qs.sh restart --smart
  ./scripts/eth2qs.sh logs --run2 -n 200
  sudo ./scripts/eth2qs.sh cleanup-host --dry-run
  ./scripts/eth2qs.sh validators
  ./scripts/eth2qs.sh validators --json
  ./scripts/eth2qs.sh validator-exit
  ./scripts/eth2qs.sh validator-create-0x01
  ./scripts/eth2qs.sh validator-create-0x02
  ./scripts/eth2qs.sh validator-manage
  ./scripts/eth2qs.sh validator-manage --exit
  ./scripts/eth2qs.sh validator-manage --consolidate
  ./scripts/eth2qs.sh validator-withdrawal-changes --generate --submit --yes
EOF
}

run_cmd() {
    local cmd="$1"
    shift
    cd "$ROOT_DIR"
    if [[ ! -x "$cmd" ]]; then
        echo "Command target is missing or not executable: $cmd" >&2
        echo "Run from repo root and ensure scripts have execute permissions." >&2
        exit 1
    fi
    "$cmd" "$@"
}

cmd="${1:-help}"
if [[ $# -gt 0 ]]; then
    shift
fi

case "$cmd" in
    help|-h|--help)
        usage
        ;;
    bootstrap)
        run_cmd "$ROOT_DIR/install.sh" "$@"
        ;;
    configure)
        run_cmd "$ROOT_DIR/install/utils/configure.sh" "$@"
        ;;
    client-options)
        run_cmd "$ROOT_DIR/install/utils/client_options.sh" "$@"
        ;;
    plan)
        run_cmd "$ROOT_DIR/install/utils/plan.sh" "$@"
        ;;
    ensure)
        run_cmd "$ROOT_DIR/install/utils/ensure.sh" "$@"
        ;;
    phase1)
        run_cmd "$ROOT_DIR/run_1.sh" "$@"
        ;;
    phase2)
        run_cmd "$ROOT_DIR/run_2.sh" "$@"
        ;;
    monad-install)
        run_cmd "$ROOT_DIR/monad_install.sh" "$@"
        ;;
    doctor|status)
        run_cmd "$ROOT_DIR/install/utils/doctor.sh" "$@"
        ;;
    debug)
        run_cmd "$ROOT_DIR/install/utils/debug.sh" "$@"
        ;;
    update-check)
        run_cmd "$ROOT_DIR/install/utils/update_check.sh" "$@"
        ;;
    monitor)
        run_cmd "$ROOT_DIR/install/utils/monitor.sh" "$@"
        ;;
    start)
        run_cmd "$ROOT_DIR/install/utils/start.sh" "$@"
        ;;
    repair)
        run_cmd "$ROOT_DIR/install/utils/repair.sh" "$@"
        ;;
    stop)
        run_cmd "$ROOT_DIR/install/utils/stop.sh" "$@"
        ;;
    restart)
        run_cmd "$ROOT_DIR/install/utils/refresh.sh" "$@"
        ;;
    stats)
        run_cmd "$ROOT_DIR/install/utils/stats.sh" "$@"
        ;;
    logs)
        run_cmd "$ROOT_DIR/install/utils/view_logs.sh" "$@"
        ;;
    clean-data)
        run_cmd "$ROOT_DIR/install/utils/purge_ethereum_data.sh" "$@"
        ;;
    cleanup-host)
        run_cmd "$ROOT_DIR/install/utils/purge_ethereum_data.sh" --host "$@"
        ;;
    update-all)
        run_cmd "$ROOT_DIR/install/utils/update_all.sh" "$@"
        ;;
    validators)
        run_cmd "$ROOT_DIR/install/utils/validator_list.sh" "$@"
        ;;
    validator-exit)
        run_cmd "$ROOT_DIR/install/utils/validator_exit.sh" "$@"
        ;;
    validator-create-0x01)
        run_cmd "$ROOT_DIR/install/utils/validator_create_0x01.sh" "$@"
        ;;
    validator-create-0x02)
        run_cmd "$ROOT_DIR/install/utils/validator_create_0x02.sh" "$@"
        ;;
    validator-deploy)
        run_cmd "$ROOT_DIR/install/utils/validator_deploy.sh" "$@"
        ;;
    validator-manage)
        run_cmd "$ROOT_DIR/install/utils/validator_manage.sh" "$@"
        ;;
    validator-withdrawal-changes)
        run_cmd "$ROOT_DIR/install/utils/validator_withdrawal_changes.sh" "$@"
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        echo "Run './scripts/eth2qs.sh help' for supported commands." >&2
        exit 1
        ;;
esac
