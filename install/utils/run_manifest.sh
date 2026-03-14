#!/bin/bash

# Compatibility wrapper for the newer planner/ensure flow.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

DRY_RUN=false
FORCE_PHASE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --phase1)
            FORCE_PHASE="1"
            ;;
        --phase2)
            FORCE_PHASE="2"
            ;;
        --help|-h)
            cat <<'EOF'
Usage: ./run_manifest.sh [--dry-run] [--phase1|--phase2]

Compatibility wrapper around the planner/ensure flow.
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

if [[ "$DRY_RUN" == "true" ]]; then
    if [[ "$FORCE_PHASE" == "1" ]]; then
        echo "[DRY RUN] Would execute: ./run_1.sh"
        exit 0
    fi
    if [[ "$FORCE_PHASE" == "2" ]]; then
        echo "[DRY RUN] Would execute: ./run_2.sh"
        exit 0
    fi
    exec "$ROOT_DIR/install/utils/ensure.sh"
fi

case "$FORCE_PHASE" in
    "1")
        exec "$ROOT_DIR/run_1.sh"
        ;;
    "2")
        exec "$ROOT_DIR/run_2.sh"
        ;;
    *)
        exec "$ROOT_DIR/install/utils/ensure.sh" --apply
        ;;
esac
