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
  plan [args...]          Detect the next safe install step
  ensure [args...]        Preview or execute the next safe install step
  phase1 [args...]        Run run_1.sh (root/system hardening)
  phase2 [args...]        Run run_2.sh (node install/config)
  monad-install [args...] Run monad_install.sh (Monad install/config)

Operations:
  doctor [--json]         Run health checks (human output by default)
  status                  Alias for: doctor
  start                   Start all node services
  stop                    Stop all node services
  restart                 Restart all node services
  stats                   Show current service status and system stats
  logs [args...]          View run logs (passed to install/utils/view_logs.sh)
  clean-data [args...]    Purge default node data dirs (safe by default)
  update-all [args...]    Comprehensive updater

Utility:
  help                    Show this help text

Examples:
  ./scripts/eth2qs.sh bootstrap --non-interactive
  ./scripts/eth2qs.sh plan --json
  ./scripts/eth2qs.sh ensure
  ./scripts/eth2qs.sh configure --interactive
  ./scripts/eth2qs.sh doctor --json
  ./scripts/eth2qs.sh logs --run2 -n 200
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
    start)
        run_cmd "$ROOT_DIR/install/utils/start.sh" "$@"
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
    update-all)
        run_cmd "$ROOT_DIR/install/utils/update_all.sh" "$@"
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        echo "Run './scripts/eth2qs.sh help' for supported commands." >&2
        exit 1
        ;;
esac
