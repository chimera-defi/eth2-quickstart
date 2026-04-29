#!/usr/bin/env bash
set -euo pipefail

DEFAULT_CRON_MARKER="eth2qs-cli-pr-watch"

usage() {
  cat <<'EOF'
usage: ./scripts/uninstall-cli-anything-pr-watch-cron.sh [options]

options:
  --cron-marker <text>  Marker used to identify/remove watch cron line
  --help                Show this help
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 2
  fi
}

cron_marker="$DEFAULT_CRON_MARKER"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cron-marker)
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
require_cmd mktemp

tmpfile="$(mktemp)"
before="$(crontab -l 2>/dev/null || true)"
after="$(printf '%s\n' "$before" | awk -v marker="$cron_marker" 'index($0, marker) == 0')"

if [[ "$before" == "$after" ]]; then
  echo "no matching cron entry found for marker: $cron_marker"
  rm -f "$tmpfile"
  exit 0
fi

printf '%s\n' "$after" > "$tmpfile"
crontab "$tmpfile"
rm -f "$tmpfile"

echo "removed cron entries with marker: $cron_marker"
