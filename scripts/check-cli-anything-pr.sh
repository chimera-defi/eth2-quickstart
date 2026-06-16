#!/usr/bin/env bash
set -euo pipefail

DEFAULT_REPO="chimera-defi/eth2-quickstart"
DEFAULT_PR="167"
DEFAULT_IGNORE_AUTHOR="chimera-defi"
DEFAULT_STATE_DIR="${HOME}/.eth2qs-pr-watch"
DEFAULT_ACTIONABLE_REGEX='blocker|request[[:space:]]+changes|should[[:space:]]+fix|must[[:space:]]+fix|please[[:space:]]+fix|needs?[[:space:]]+fix|merge[[:space:]]+conflict|rebase|failing'
DEFAULT_CRON_MARKER="eth2qs-cli-pr-watch"

usage() {
  cat <<'EOF'
usage: ./scripts/check-cli-anything-pr.sh [options]

options:
  --repo <owner/name>        Repository to watch (default: chimera-defi/eth2-quickstart)
  --pr <number>              Pull request number to watch (default: 167)
  --ignore-author <login>    Ignore actionable checks from this author (default: chimera-defi)
  --state-dir <path>         State/report directory (default: ~/.eth2qs-pr-watch)
  --autofix-cmd <command>    Optional command to run when new actionable feedback is found
  --disable-cron-on-closed   Remove cron marker entry when PR is no longer open
  --cron-marker <text>       Cron marker to remove (default: eth2qs-cli-pr-watch)
  --dry-run                  Do not execute autofix command
  --exit-nonzero-on-actionable
                             Exit with code 10 when actionable feedback is found
  --help                     Show this help

env overrides:
  ETH2QS_PR_WATCH_REPO
  ETH2QS_PR_WATCH_PR
  ETH2QS_PR_WATCH_IGNORE_AUTHOR
  ETH2QS_PR_WATCH_STATE_DIR
  ETH2QS_PR_WATCH_AUTOFIX_CMD
  ETH2QS_PR_WATCH_AUTOFIX_B64
  ETH2QS_PR_WATCH_ACTIONABLE_REGEX
  ETH2QS_PR_WATCH_DISABLE_CRON_ON_CLOSED
  ETH2QS_PR_WATCH_CRON_MARKER
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "missing required command: $cmd" >&2
    exit 2
  fi
}

remove_cron_entry() {
  local marker="$1"
  require_cmd crontab
  require_cmd mktemp
  require_cmd awk
  local tmpfile
  tmpfile="$(mktemp)"
  crontab -l 2>/dev/null | awk -v marker="$marker" 'index($0, marker) == 0' > "$tmpfile" || true
  crontab "$tmpfile"
  rm -f "$tmpfile"
}

repo="${ETH2QS_PR_WATCH_REPO:-$DEFAULT_REPO}"
pr_number="${ETH2QS_PR_WATCH_PR:-$DEFAULT_PR}"
ignore_author="${ETH2QS_PR_WATCH_IGNORE_AUTHOR:-$DEFAULT_IGNORE_AUTHOR}"
state_dir="${ETH2QS_PR_WATCH_STATE_DIR:-$DEFAULT_STATE_DIR}"
autofix_cmd="${ETH2QS_PR_WATCH_AUTOFIX_CMD:-}"
actionable_regex="${ETH2QS_PR_WATCH_ACTIONABLE_REGEX:-$DEFAULT_ACTIONABLE_REGEX}"
disable_cron_on_closed="${ETH2QS_PR_WATCH_DISABLE_CRON_ON_CLOSED:-false}"
cron_marker="${ETH2QS_PR_WATCH_CRON_MARKER:-$DEFAULT_CRON_MARKER}"
dry_run="false"
exit_nonzero_on_actionable="false"

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
    --ignore-author)
      if [[ $# -lt 2 ]]; then
        echo "Error: option $1 requires a value" >&2
        exit 2
      fi
      ignore_author="$2"
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
    --disable-cron-on-closed)
      disable_cron_on_closed="true"
      shift
      ;;
    --cron-marker)
      cron_marker="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="true"
      shift
      ;;
    --exit-nonzero-on-actionable)
      exit_nonzero_on_actionable="true"
      shift
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

if [[ -z "$autofix_cmd" && -n "${ETH2QS_PR_WATCH_AUTOFIX_B64:-}" ]]; then
  require_cmd base64
  autofix_cmd="$(printf '%s' "$ETH2QS_PR_WATCH_AUTOFIX_B64" | base64 -d)"
fi

require_cmd gh
require_cmd jq

slug="$(printf '%s' "$repo" | tr '/ ' '__' | tr -cd '[:alnum:]_.-')"
state_file="${state_dir}/${slug}-pr${pr_number}.state.json"
report_dir="${state_dir}/reports"
mkdir -p "$state_dir" "$report_dir"

checked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
pr_meta="$(gh api "repos/${repo}/pulls/${pr_number}")"
pr_state="$(jq -r '.state // "unknown"' <<<"$pr_meta")"
pr_merged_at="$(jq -r '.merged_at // ""' <<<"$pr_meta")"

if [[ "$disable_cron_on_closed" == "true" && "$pr_state" != "open" ]]; then
  remove_cron_entry "$cron_marker"
  jq -n \
    --arg checked_at "$checked_at" \
    --arg repo "$repo" \
    --argjson pr_number "$pr_number" \
    --arg pr_state "$pr_state" \
    --arg pr_merged_at "$pr_merged_at" '
      {
        checked_at: $checked_at,
        repo: $repo,
        pr_number: $pr_number,
        pr_state: $pr_state,
        pr_merged_at: (if $pr_merged_at == "" then null else $pr_merged_at end),
        processed_ids: [],
        last_run: {
          new_count: 0,
          actionable_count: 0,
          report_path: null,
          autofix_status: "skipped_pr_closed",
          cron_removed: true
        }
      }
    ' > "$state_file"

  jq -n \
    --arg checked_at "$checked_at" \
    --arg repo "$repo" \
    --argjson pr_number "$pr_number" \
    --arg pr_state "$pr_state" \
    --arg pr_merged_at "$pr_merged_at" '
      {
        checked_at: $checked_at,
        repo: $repo,
        pr_number: $pr_number,
        pr_state: $pr_state,
        pr_merged_at: (if $pr_merged_at == "" then null else $pr_merged_at end),
        new_count: 0,
        actionable_count: 0,
        report_path: null,
        autofix_status: "skipped_pr_closed",
        cron_removed: true
      }
    '
  exit 0
fi

issue_comments="$(gh api --paginate "repos/${repo}/issues/${pr_number}/comments?per_page=100")"
review_comments="$(gh api --paginate "repos/${repo}/pulls/${pr_number}/comments?per_page=100")"
reviews="$(gh api --paginate "repos/${repo}/pulls/${pr_number}/reviews?per_page=100")"

events="$(
  jq -n \
    --argjson issue_comments "$issue_comments" \
    --argjson review_comments "$review_comments" \
    --argjson reviews "$reviews" '
      [
        ($issue_comments[]? | {
          id: (.id | tostring),
          kind: "issue_comment",
          author: (.user.login // ""),
          created_at: (.created_at // ""),
          body: (.body // "")
        }),
        ($review_comments[]? | {
          id: (.id | tostring),
          kind: "review_comment",
          author: (.user.login // ""),
          created_at: (.created_at // ""),
          body: (.body // "")
        }),
        ($reviews[]? | {
          id: (.id | tostring),
          kind: ("review_" + ((.state // "unknown") | ascii_downcase)),
          author: (.user.login // ""),
          created_at: (.submitted_at // .created_at // ""),
          body: (.body // "")
        })
      ]
      | map(select(.created_at != ""))
      | sort_by(.created_at)
    '
)"

seen_ids="[]"
if [[ -f "$state_file" ]]; then
  seen_ids="$(jq -c '.processed_ids // []' "$state_file" 2>/dev/null || echo '[]')"
fi

new_events="$(
  jq -n \
    --argjson events "$events" \
    --argjson seen_ids "$seen_ids" '
      $events
      | map(select((.id as $id | ($seen_ids | index($id)) == null)))
    '
)"

actionable="$(
  jq -n \
    --argjson events "$new_events" \
    --arg ignore_author "$ignore_author" \
    --arg actionable_regex "$actionable_regex" '
      $events
      | map(
          . + {
            actionable: (
              (.author != $ignore_author)
              and (
                (.kind == "review_changes_requested")
                or (.body | test($actionable_regex; "i"))
              )
            )
          }
        )
      | map(select(.actionable))
    '
)"

new_count="$(jq 'length' <<<"$new_events")"
actionable_count="$(jq 'length' <<<"$actionable")"
report_path=""
autofix_status="not_configured"

if [[ "$actionable_count" -gt 0 ]]; then
  report_path="${report_dir}/${slug}-pr${pr_number}-$(date -u +%Y%m%dT%H%M%SZ).md"
  {
    echo "# CLI-Anything PR Watch Alert"
    echo
    echo "- Checked at: ${checked_at}"
    echo "- PR: https://github.com/${repo}/pull/${pr_number}"
    echo "- State: ${pr_state}"
    if [[ -n "$pr_merged_at" ]]; then
      echo "- Merged at: ${pr_merged_at}"
    fi
    echo "- New events: ${new_count}"
    echo "- Actionable events: ${actionable_count}"
    echo
    echo "## Actionable Items"
    echo
    jq -r '
      .[]
      | "- [\(.kind)] @\(.author) on \(.created_at)\n\n```\n\(.body)\n```\n"
    ' <<<"$actionable"
  } > "$report_path"

  if [[ -n "$autofix_cmd" ]]; then
    if [[ "$dry_run" == "true" ]]; then
      autofix_status="dry_run"
    else
      if ETH2QS_PR_WATCH_REPO="$repo" \
         ETH2QS_PR_WATCH_PR="$pr_number" \
         ETH2QS_PR_WATCH_REPORT="$report_path" \
         bash -lc "$autofix_cmd"; then
        autofix_status="executed"
      else
        autofix_status="failed"
      fi
    fi
  fi
fi

updated_seen_ids="$(
  jq -n \
    --argjson seen_ids "$seen_ids" \
    --argjson events "$events" '
      ($seen_ids + ($events | map(.id)))
      | unique
      | if length > 2000 then .[-2000:] else . end
    '
)"

jq -n \
  --arg checked_at "$checked_at" \
  --arg repo "$repo" \
  --argjson pr_number "$pr_number" \
  --arg pr_state "$pr_state" \
  --arg pr_merged_at "$pr_merged_at" \
  --argjson processed_ids "$updated_seen_ids" \
  --argjson new_count "$new_count" \
  --argjson actionable_count "$actionable_count" \
  --arg report_path "$report_path" \
  --arg autofix_status "$autofix_status" '
    {
      checked_at: $checked_at,
      repo: $repo,
      pr_number: $pr_number,
      pr_state: $pr_state,
      pr_merged_at: (if $pr_merged_at == "" then null else $pr_merged_at end),
      processed_ids: $processed_ids,
      last_run: {
        new_count: $new_count,
        actionable_count: $actionable_count,
        report_path: (if $report_path == "" then null else $report_path end),
        autofix_status: $autofix_status
      }
    }
  ' > "$state_file"

jq -n \
  --arg checked_at "$checked_at" \
  --arg repo "$repo" \
  --argjson pr_number "$pr_number" \
  --arg pr_state "$pr_state" \
  --arg pr_merged_at "$pr_merged_at" \
  --argjson new_count "$new_count" \
  --argjson actionable_count "$actionable_count" \
  --arg report_path "$report_path" \
  --arg autofix_status "$autofix_status" '
    {
      checked_at: $checked_at,
      repo: $repo,
      pr_number: $pr_number,
      pr_state: $pr_state,
      pr_merged_at: (if $pr_merged_at == "" then null else $pr_merged_at end),
      new_count: $new_count,
      actionable_count: $actionable_count,
      report_path: (if $report_path == "" then null else $report_path end),
      autofix_status: $autofix_status
    }
  '

if [[ "$actionable_count" -gt 0 && "$exit_nonzero_on_actionable" == "true" ]]; then
  exit 10
fi

exit 0
