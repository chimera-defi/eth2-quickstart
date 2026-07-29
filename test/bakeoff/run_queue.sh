#!/bin/bash
# run_queue.sh — async re-run queue for the bake-off harness.
#
# Drains a queue of candidates that need (re-)measuring, waiting until it is
# safe to run each one, then invoking run_candidate.sh for it. Designed to be
# left running (e.g. under tmux/systemd) while other bake-off activity — a
# still-running candidate, an anchor EL still catching up — finishes.
#
# Usage:
#   ETH2QS_BAKEOFF_CONFIRMED=yes test/bakeoff/run_queue.sh [--dry-run]
#
# Queue file (TAB-separated; # comments and blank lines ignored; columns
# execution, consensus, reason): see rerun_queue.tsv.example for the format.
#
# Env vars:
#   ETH2QS_BAKEOFF_QUEUE_FILE          default: test/bakeoff/rerun_queue.tsv
#   ETH2QS_BAKEOFF_CONFIRMED           must be "yes" (same gate as run_candidate.sh)
#   ETH2QS_BAKEOFF_ANCHOR_EL           if set, gate each row on the anchor EL
#                                      (eth1.service) being active + synced,
#                                      same as run_candidate.sh's anchor mode
#   ETH2QS_BAKEOFF_QUEUE_WAIT_SECONDS  bounded wait per row for preconditions
#                                      (default 7200)
#   ETH2QS_BAKEOFF_QUEUE_POLL_SECONDS  poll interval while waiting (default 60)
#   ETH2QS_BAKEOFF_QUEUE_FORCE         "yes" (default) reruns a pair even when it
#                                      already has a .done marker, which is the point
#                                      of a rerun queue; set "no" to skip completed
#                                      pairs instead. Forcing overwrites that pair's
#                                      previous artifacts.
#   ETH2QS_BAKEOFF_RUN_ID              same run_id used by run_candidate.sh;
#                                      determines the shared artifact dir
#   ETH2QS_BAKEOFF_ALERT_LOG           advisor-alert JSONL path (see lib.sh);
#                                      defaults under the same artifact dir

set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"
# shellcheck source=lib.sh
source "$REPO_ROOT/test/bakeoff/lib.sh"

dry_run="no"
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run="yes" ;;
    *)
      log_error "run_queue.sh: unknown argument: $arg (only --dry-run is supported)"
      exit 64
      ;;
  esac
done

queue_file="${ETH2QS_BAKEOFF_QUEUE_FILE:-$REPO_ROOT/test/bakeoff/rerun_queue.tsv}"
anchor_el="${ETH2QS_BAKEOFF_ANCHOR_EL:-}"
queue_wait_seconds="${ETH2QS_BAKEOFF_QUEUE_WAIT_SECONDS:-7200}"
queue_poll_seconds="${ETH2QS_BAKEOFF_QUEUE_POLL_SECONDS:-60}"
artifact_root="$REPO_ROOT/artifacts/${ETH2QS_BAKEOFF_RUN_ID:-client-bakeoff-2026-06-22}"
# Same advisor-alert channel run_candidate.sh writes to (shared per run_id) so
# an operator/supervising-AI can tail one file for the whole run, including
# rows driven through this queue.
export ETH2QS_BAKEOFF_ALERT_LOG="${ETH2QS_BAKEOFF_ALERT_LOG:-$artifact_root/advisor-alerts.jsonl}"
queue_log="$artifact_root/run_queue.log"
run_candidate_bin="$REPO_ROOT/test/bakeoff/run_candidate.sh"

# Operator gate — mirrors run_candidate.sh's message/exit-code exactly. Applies
# in --dry-run too: previewing the plan for a destructive harness still implies
# the operator has looked at this host and confirmed it is not a production
# validator host.
if [[ "${ETH2QS_BAKEOFF_CONFIRMED:-}" != "yes" ]]; then
  log_error "Refusing destructive bake-off. Set ETH2QS_BAKEOFF_CONFIRMED=yes after operator confirms this is not a production validator host."
  exit 2
fi

if [[ ! -f "$queue_file" ]]; then
  log_error "run_queue.sh: queue file not found: $queue_file (see rerun_queue.tsv.example)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

# True (exit 0) when some OTHER run_candidate.sh process is currently running.
# Excludes this process's own PID defensively (this script's own argv never
# matches "run_candidate.sh", but a synchronously-invoked child has already
# exited by the time the NEXT row's precondition check runs, so this is a
# pure safety net, not load-bearing).
_other_candidate_running() {
  local self_pid=$$ pids
  pids="$(pgrep -f 'run_candidate\.sh' 2>/dev/null | grep -v -x "$self_pid" || true)"
  [[ -n "$pids" ]]
}

# True (exit 0) when the anchor precondition holds: no anchor configured, or
# the anchor EL's unit is active AND the execution client is synced to head.
# Deliberately EXECUTION-ONLY (bakeoff_is_execution_synced, lib.sh) rather than
# bakeoff_is_synced: anchor-mode cleanup stops the CL and purges its datadir
# between candidates, so a beacon-inclusive predicate could never be satisfied
# here and every queued row would wait out the timeout and be skipped. This
# matches run_candidate.sh's own anchor preflight, which also checks the EL only.
_anchor_ready() {
  [[ -z "$anchor_el" ]] && return 0
  systemctl is-active --quiet eth1.service 2>/dev/null || return 1
  bakeoff_is_execution_synced
}

# wait_for_preconditions <pair-or-dash>
# Polls until both preconditions hold or the bounded timeout elapses.
# Returns 0 once ready, 1 on timeout. Never raises past its own caller.
wait_for_preconditions() {
  local label="$1" deadline
  deadline=$(( $(date +%s) + queue_wait_seconds ))
  while true; do
    if ! _other_candidate_running && _anchor_ready; then
      return 0
    fi
    if [[ "$(date +%s)" -ge "$deadline" ]]; then
      return 1
    fi
    log_info "run_queue: $label: preconditions not met yet, waiting ${queue_poll_seconds}s (timeout in $(( deadline - $(date +%s) ))s)..."
    sleep "$queue_poll_seconds"
  done
}

# ---------------------------------------------------------------------------
# Row processing
# ---------------------------------------------------------------------------

row_count=0
malformed_count=0
skipped_count=0
failed_count=0
succeeded_count=0

if [[ "$dry_run" == "yes" ]]; then
  echo "[dry-run] run_queue.sh plan (no side effects; nothing will be run)"
  echo "[dry-run] queue file: $queue_file"
  echo "[dry-run] operator gate: ETH2QS_BAKEOFF_CONFIRMED=yes (checked)"
  if [[ -n "$anchor_el" ]]; then
    echo "[dry-run] anchor precondition: eth1.service active AND bakeoff_is_execution_synced (execution-only; anchor_el=$anchor_el)"
  else
    echo "[dry-run] anchor precondition: none (ETH2QS_BAKEOFF_ANCHOR_EL not set)"
  fi
  echo "[dry-run] concurrency precondition: no other run_candidate.sh process running"
  echo "[dry-run] precondition wait: up to ${queue_wait_seconds}s, polled every ${queue_poll_seconds}s"
  echo "[dry-run]"
else
  mkdir -p "$artifact_root"
  : > "$queue_log"
  log_info "run_queue: draining $queue_file (wait timeout ${queue_wait_seconds}s, poll ${queue_poll_seconds}s); queue log: $queue_log"
fi

while IFS=$'\t' read -r execution consensus reason || [[ -n "${execution:-}" ]]; do
  # Strip a trailing CR (queue file edited on/copied from a CRLF host).
  execution="${execution%$'\r'}"

  # Blank line (nothing at all in the first field).
  if [[ -z "${execution//[[:space:]]/}" ]]; then
    continue
  fi
  # Full-line comment.
  case "$execution" in
    \#*) continue ;;
  esac

  row_count=$((row_count + 1))

  if [[ -z "${consensus:-}" ]]; then
    malformed_count=$((malformed_count + 1))
    if [[ "$dry_run" == "yes" ]]; then
      echo "[dry-run] row $row_count: MALFORMED (expected TAB-separated execution<TAB>consensus[<TAB>reason]), got: '${execution}' — would be skipped"
    else
      log_warn "run_queue: row $row_count malformed (missing consensus column): '${execution}'; skipping"
      bakeoff_advisor_alert warn "-" queue_malformed_row "row $row_count: '${execution}' (expected TAB-separated execution/consensus[/reason])" || true
      printf '%s\trow=%d\tpair=-\tresult=malformed\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$row_count" >> "$queue_log"
    fi
    continue
  fi

  pair="${execution}__${consensus}"
  reason="${reason:-}"

  if [[ "$dry_run" == "yes" ]]; then
    printf '[dry-run] row %d: execution=%s consensus=%s reason="%s"\n' "$row_count" "$execution" "$consensus" "$reason"
    printf '[dry-run]   would wait for preconditions, then run: %s %s %s\n' "$run_candidate_bin" "$execution" "$consensus"
    continue
  fi

  log_info "run_queue: row $row_count ($pair): waiting for preconditions"
  if ! wait_for_preconditions "$pair"; then
    log_error "run_queue: row $row_count ($pair): preconditions not met within ${queue_wait_seconds}s; skipping"
    bakeoff_advisor_alert warn "$pair" queue_precondition_timeout "preconditions (no-other-candidate / anchor-synced) not met within ${queue_wait_seconds}s; row skipped" || true
    printf '%s\trow=%d\tpair=%s\tresult=skipped_precondition_timeout\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$row_count" "$pair" >> "$queue_log"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # The queue's purpose is re-measuring pairs that already have a .done marker
  # (that is what a "rerun queue" is for), and run_candidate.sh exits 0 without
  # running anything when .done exists and FORCE is unset. Without this the
  # queue would record a successful rerun while taking no measurement at all.
  # Opt out with ETH2QS_BAKEOFF_QUEUE_FORCE=no if a row should be skipped when
  # already complete.
  log_info "run_queue: row $row_count ($pair): preconditions met; running run_candidate.sh (force=${ETH2QS_BAKEOFF_QUEUE_FORCE:-yes})"
  set +e
  ETH2QS_BAKEOFF_FORCE="${ETH2QS_BAKEOFF_QUEUE_FORCE:-yes}" "$run_candidate_bin" "$execution" "$consensus"
  rc=$?
  set -e
  printf '%s\trow=%d\tpair=%s\trc=%d\treason=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$row_count" "$pair" "$rc" "$reason" >> "$queue_log"
  if [[ "$rc" -ne 0 ]]; then
    log_error "run_queue: row $row_count ($pair): run_candidate.sh exited $rc"
    bakeoff_advisor_alert error "$pair" queue_candidate_failed "run_candidate.sh exited $rc" || true
    failed_count=$((failed_count + 1))
  else
    log_info "run_queue: row $row_count ($pair): completed rc=0"
    succeeded_count=$((succeeded_count + 1))
  fi
  # Continue the drain regardless of this row's outcome — one bad row must
  # never abort the rest of the queue.
done < "$queue_file"

if [[ "$dry_run" == "yes" ]]; then
  echo "[dry-run] rows found: $row_count (malformed: $malformed_count)"
else
  log_info "run_queue: drain complete. rows=$row_count succeeded=$succeeded_count failed=$failed_count skipped=$skipped_count malformed=$malformed_count"
  log_info "run_queue: per-row results in $queue_log"
fi
