#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CRON_MARKER="eth2qs-cli-pr-watch"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common_functions.sh
source "$ROOT_DIR/lib/common_functions.sh"

usage() {
  cat <<'EOF'
usage: ./scripts/uninstall-cli-anything-pr-watch-cron.sh [options]

options:
  --cron-marker <text>  Marker used to identify/remove watch cron line
  --help                Show this help
EOF
}

cron_marker="$DEFAULT_CRON_MARKER"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cron-marker)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      cron_marker="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_cmd crontab
require_cmd awk

before="$(crontab -l 2>/dev/null || true)"
after="$(printf '%s\n' "$before" | cron_filter_by_marker "$cron_marker")"

if [[ "$before" == "$after" ]]; then
  echo "no matching cron entry found for marker: $cron_marker"
  rm -f "$tmpfile"
  exit 0
fi

cron_remove_by_marker "$cron_marker"

echo "removed cron entries with marker: $cron_marker"
