#!/bin/bash
# run_anchor_rotation.sh — multi-EL anchor-rotation driver for the bake-off harness.
#
# For each anchor EL:
#   1. Establish (KEEP_EL=yes, no anchor, prysm): wipe prior EL, install fresh, sync to tip.
#   2. If not synced to tip → warn, skip CL sweep.
#   3. CL sweep (anchor mode): set ANCHOR_EL, run each CL against the live anchor.
#   4. Rotate (next establish step wipes the current anchor EL).
# Finally calls summarize.sh.
#
# Usage:
#   ETH2QS_BAKEOFF_CONFIRMED=yes \
#   run_anchor_rotation.sh <anchors_csv> [<cls_csv>]
#
#   anchors_csv  e.g. "geth,nimbus_eth1"
#   cls_csv      default "lighthouse,teku,nimbus,lodestar,grandine"

set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"
# shellcheck source=lib.sh
source "$REPO_ROOT/test/bakeoff/lib.sh"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
anchors_arg="${1:?usage: run_anchor_rotation.sh <anchors_csv> [<cls_csv>]}"
cls_arg="${2:-lighthouse,teku,nimbus,lodestar,grandine}"

IFS=',' read -r -a anchors <<< "$anchors_arg"
IFS=',' read -r -a cls_sweep <<< "$cls_arg"

# ---------------------------------------------------------------------------
# Operator gate (mirror run_candidate.sh)
# ---------------------------------------------------------------------------
if [[ "${ETH2QS_BAKEOFF_CONFIRMED:-}" != "yes" ]]; then
  log_error "Refusing destructive anchor-rotation. Set ETH2QS_BAKEOFF_CONFIRMED=yes after operator confirms this is not a production validator host."
  exit 2
fi

# ---------------------------------------------------------------------------
# Artifact dir + summary log
# ---------------------------------------------------------------------------
artifact_root="$REPO_ROOT/artifacts/${ETH2QS_BAKEOFF_RUN_ID:-client-bakeoff-2026-06-22}"
mkdir -p "$artifact_root"
summary_log="$artifact_root/anchor-rotation.log"
: > "$summary_log"

log_info "Anchor rotation starting. Anchors: ${anchors[*]}  CLs: ${cls_sweep[*]}"
log_info "Summary log: $summary_log"

# ---------------------------------------------------------------------------
# Main rotation loop
# ---------------------------------------------------------------------------
for anchor in "${anchors[@]}"; do
  log_info "=== Anchor: $anchor — establishing EL to tip ==="

  # Step 1: establish (non-anchor, KEEP_EL=yes) using prysm as the paired CL.
  unset ETH2QS_BAKEOFF_ANCHOR_EL || true
  export ETH2QS_BAKEOFF_KEEP_EL=yes
  establish_rc=0
  set +e
  "$REPO_ROOT/test/bakeoff/run_candidate.sh" "$anchor" "prysm"
  establish_rc=$?
  set -e
  unset ETH2QS_BAKEOFF_KEEP_EL
  echo "establish anchor=$anchor rc=$establish_rc" | tee -a "$summary_log"

  # Step 2: check tip.
  env_file="$artifact_root/${anchor}__prysm/env.txt"
  if [[ ! -f "$env_file" ]] || ! grep -q '^fully_synced=yes$' "$env_file"; then
    log_warn "Anchor $anchor did not reach tip (establish rc=$establish_rc or fully_synced!=yes). Skipping CL sweep."
    echo "anchor=$anchor established=no sweep=skipped" | tee -a "$summary_log"
    continue
  fi
  log_info "Anchor $anchor reached tip. Proceeding to CL sweep."
  echo "anchor=$anchor established=yes" | tee -a "$summary_log"

  # Step 3: CL sweep in anchor mode.
  export ETH2QS_BAKEOFF_ANCHOR_EL="$anchor"
  for cl in "${cls_sweep[@]}"; do
    log_info "=== [$anchor anchor] CL candidate: $cl ==="
    sweep_rc=0
    set +e
    "$REPO_ROOT/test/bakeoff/run_candidate.sh" "$anchor" "$cl"
    sweep_rc=$?
    set -e
    echo "anchor=$anchor cl=$cl rc=$sweep_rc" | tee -a "$summary_log"
  done
  unset ETH2QS_BAKEOFF_ANCHOR_EL

  log_info "=== Anchor $anchor sweep complete ==="
done

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
log_info "Anchor rotation complete. Results in $summary_log"
"$REPO_ROOT/test/bakeoff/summarize.sh" || log_warn "summarize.sh reported an issue"
