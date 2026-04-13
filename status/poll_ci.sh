#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO="${ETH2QS_STATUS_REPO:-chimera-defi/eth2-quickstart}"
AUTHOR="${ETH2QS_STATUS_AUTHOR:-chimera-defi}"
STATUS_DIR="${ETH2QS_STATUS_DIR:-$REPO_ROOT/status}"
WATCH_ENABLED="${ETH2QS_STATUS_WATCH_ENABLED:-true}"
WATCH_REPO="${ETH2QS_STATUS_WATCH_REPO:-$REPO}"
WATCH_PR="${ETH2QS_STATUS_WATCH_PR:-167}"
WATCH_STATE_DIR="${ETH2QS_PR_WATCH_STATE_DIR:-$HOME/.eth2qs-pr-watch}"
WATCH_MARKER="${ETH2QS_PR_WATCH_CRON_MARKER:-eth2qs-cli-pr-watch}"

mkdir -p "$STATUS_DIR"

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
prs_json="$(gh pr list --repo "$REPO" --state open --author "$AUTHOR" --limit 20 --json number,title,updatedAt,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup)"

printf '%s\n' "$prs_json" > "$STATUS_DIR/open-prs.json"

jq -n \
  --arg checked_at "$timestamp" \
  --arg repo "$REPO" \
  --arg author "$AUTHOR" \
  --argjson prs "$prs_json" '
    {
      checked_at: $checked_at,
      repo: $repo,
      author: $author,
      open_pr_count: ($prs | length),
      open_prs: (
        $prs
        | map({
            number,
            title,
            updatedAt,
            mergeable,
            mergeStateStatus,
            reviewDecision,
            checks: (
              (.statusCheckRollup // [])
              | map({
                  name,
                  status,
                  conclusion
                })
            )
          })
      )
    }
  ' > "$STATUS_DIR/ci-summary.json"

if [[ "$WATCH_ENABLED" == "true" ]]; then
  watch_script="$REPO_ROOT/scripts/check-cli-anything-pr.sh"
  if [[ -x "$watch_script" ]]; then
    "$watch_script" \
      --repo "$WATCH_REPO" \
      --pr "$WATCH_PR" \
      --state-dir "$WATCH_STATE_DIR" \
      --disable-cron-on-closed \
      --cron-marker "$WATCH_MARKER" \
      > "$STATUS_DIR/pr-watch-last.json" || true
  fi
fi

echo "polled at $timestamp"
