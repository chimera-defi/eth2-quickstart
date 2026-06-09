#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO="chimera-defi/eth2-quickstart"
DEFAULT_PR="167"
DEFAULT_SCHEDULE="15 9 * * *"
DEFAULT_STATE_DIR="${HOME}/.eth2qs-pr-watch"
CRON_MARKER="eth2qs-cli-pr-watch"

usage() {
  cat <<'EOF'
usage: ./scripts/install-cli-anything-pr-watch-cron.sh [options]

options:
  --repo <owner/name>      Repository to watch (default: chimera-defi/eth2-quickstart)
  --pr <number>            Pull request number to watch (default: 167)
  --schedule "<cron expr>" Cron schedule (default: 15 9 * * *)
  --state-dir <path>       State/log directory (default: ~/.eth2qs-pr-watch)
  --autofix-cmd <command>  Optional command invoked when actionable feedback appears
  --disable-on-closed      Auto-remove cron entry when PR is no longer open (default: enabled)
  --no-disable-on-closed   Do not auto-remove cron entry on closed/merged PR
  --cron-marker <text>     Marker used for idempotent replace (default: eth2qs-cli-pr-watch)
  --help                   Show this help

notes:
  - installer is idempotent (replaces existing eth2qs watch entry)
  - cron writes output to ~/.eth2qs-pr-watch/cron.log by default
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 2
  fi
}

repo="$DEFAULT_REPO"
pr_number="$DEFAULT_PR"
schedule="$DEFAULT_SCHEDULE"
state_dir="$DEFAULT_STATE_DIR"
autofix_cmd=""
disable_on_closed="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      repo="$2"
      shift 2
      ;;
    --pr)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      pr_number="$2"
      shift 2
      ;;
    --schedule)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      schedule="$2"
      shift 2
      ;;
    --state-dir)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      state_dir="$2"
      shift 2
      ;;
    --autofix-cmd)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      autofix_cmd="$2"
      shift 2
      ;;
    --disable-on-closed)
      disable_on_closed="true"
      shift
      ;;
    --no-disable-on-closed)
      disable_on_closed="false"
      shift
      ;;
    --cron-marker)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      CRON_MARKER="$2"
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
require_cmd mktemp
require_cmd awk

watch_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-cli-anything-pr.sh"
if [[ ! -x "$watch_script" ]]; then
  echo "watch script is missing or not executable: $watch_script" >&2
  exit 2
fi

mkdir -p "$state_dir" "${state_dir}/reports"
log_file="${state_dir}/cron.log"

cron_env=""
if [[ -n "$autofix_cmd" ]]; then
  require_cmd base64
  autofix_b64="$(printf '%s' "$autofix_cmd" | base64 | tr -d '\n')"
  cron_env="ETH2QS_PR_WATCH_AUTOFIX_B64='${autofix_b64}' "
fi

disable_flag=""
if [[ "$disable_on_closed" == "true" ]]; then
  disable_flag="--disable-cron-on-closed --cron-marker ${CRON_MARKER}"
fi

cron_line="${schedule} ${cron_env}${watch_script} --repo ${repo} --pr ${pr_number} --state-dir ${state_dir} ${disable_flag} >> ${log_file} 2>&1 # ${CRON_MARKER}"

tmpfile="$(mktemp)"
{
  crontab -l 2>/dev/null | awk -v marker="$CRON_MARKER" 'index($0, marker) == 0' || true
  echo "$cron_line"
} > "$tmpfile"

crontab "$tmpfile"
rm -f "$tmpfile"

echo "installed cron entry:"
echo "$cron_line"
