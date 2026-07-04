#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"

artifact_root="$REPO_ROOT/artifacts/${ETH2QS_BAKEOFF_RUN_ID:-client-bakeoff-2026-06-22}"
# Machine-generated results skeleton lands here (gitignored), NOT in the curated doc.
generated_doc="$artifact_root/CLIENT_BAKEOFF_RESULTS.generated.md"
[[ -d "$artifact_root" ]] || { log_error "No artifact root at $artifact_root"; exit 1; }

# --- sync-time helpers ------------------------------------------------------
# Sync TIME is a co-equal ranking axis with disk footprint. These derive it from
# the raw env.txt timestamps already recorded per run (started_at_utc/synced_at_utc)
# plus the install-time.txt wall clock, so nothing is retrofitted into the live
# run_candidate.sh loop and every past/future run is covered.

# Epoch seconds from an ISO-8601 UTC stamp (…Z); empty on failure.
_epoch() {
  [[ -n "${1:-}" ]] || return 0
  date -u -d "$1" +%s 2>/dev/null || true
}

# Wall-clock seconds parsed from a `/usr/bin/time -v` install-time.txt ("h:mm:ss"
# or "m:ss.dd"); empty if unparseable.
_install_wall_s() {
  local f="$1" line hms
  [[ -f "$f" ]] || { echo ""; return; }
  line="$(grep -E 'Elapsed \(wall clock\)' "$f" 2>/dev/null | tail -1 || true)"
  hms="${line##*: }"
  [[ -n "$hms" ]] || { echo ""; return; }
  awk -v t="$hms" 'BEGIN{n=split(t,a,":"); if(n==3){printf "%d", a[1]*3600+a[2]*60+a[3]} else if(n==2){printf "%d", a[1]*60+a[2]}}'
}

# Human "Xh YYm" from integer seconds; "" if not a non-negative integer.
_fmt_hm() {
  local s="${1:-}"
  [[ "$s" =~ ^[0-9]+$ ]] || { echo ""; return; }
  printf '%dh%02dm' $(( s / 3600 )) $(( (s % 3600) / 60 ))
}

# Machine-readable summary.
{
  echo "pair,execution,consensus,install_exit_code,crash,sample_count,last_doctor_status,last_disk_bytes,residual_bytes,config_optimal,config_optimal_detail,fully_synced,sync_duration,sync_only,last_el_block"
  for dir in "$artifact_root"/*__*; do
    [[ -d "$dir" ]] || continue
    pair="$(basename "$dir")"
    execution="${pair%%__*}"; consensus="${pair##*__}"
    install_code="$(grep -E '^install_exit_code=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    crash="$(grep -E '^service_crash_observed=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    sample_count="$(wc -l < "$dir/samples.jsonl" 2>/dev/null || echo 0)"
    last_doctor="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.doctor.summary.status // "unknown"' 2>/dev/null || echo unknown)"
    _synced="$(grep -E '^fully_synced=' "$dir/env.txt" 2>/dev/null | cut -d= -f2-)" || true
    if [[ "${_synced:-}" == "yes" && -f "$dir/disk-synced.tsv" ]]; then
      last_disk="$(awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}' "$dir/disk-synced.tsv")" || true
    elif [[ -f "$dir/disk-final.tsv" ]]; then
      last_disk="$(awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}' "$dir/disk-final.tsv")" || true
    else
      last_disk="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.disk_tsv' 2>/dev/null | awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}')" || true
    fi
    residual="$(awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}' "$dir/disk-after-cleanup.tsv" 2>/dev/null || echo 0)"
    cfg_optimal="$(grep -E '^config_optimal=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    cfg_detail="$(grep -E '^config_optimal_detail=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true

    # --- sync-time axis: derive from recorded timestamps + install wall clock ---
    started="$(grep -E '^started_at_utc=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    synced="$(grep -E '^synced_at_utc=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    started_e="$(_epoch "${started:-}")"; synced_e="$(_epoch "${synced:-}")"
    total_s=""; if [[ -n "$started_e" && -n "$synced_e" ]]; then total_s=$(( synced_e - started_e )); fi
    install_s="$(_install_wall_s "$dir/install-time.txt")"
    sync_only_s=""; if [[ -n "$total_s" && -n "$install_s" ]]; then sync_only_s=$(( total_s - install_s )); fi
    [[ -n "$sync_only_s" && "$sync_only_s" -lt 0 ]] && sync_only_s=""
    if [[ -n "$total_s" ]]; then
      sync_dur_h="$(_fmt_hm "$total_s")"
    elif [[ "${_synced:-}" == "yes" ]]; then
      sync_dur_h="synced(time-n/a)"
    else
      sync_dur_h="did-not-finish"
    fi
    sync_only_h="$(_fmt_hm "${sync_only_s:-}")"; [[ -n "$sync_only_h" ]] || sync_only_h="-"
    # Last EL block seen (decimal) — progress proxy for capped/partial runs.
    leb_hex="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.execution_sync.result.currentBlock? // empty' 2>/dev/null || true)"
    if [[ "$leb_hex" =~ ^0x[0-9a-fA-F]+$ ]]; then last_el_block=$(( 16#${leb_hex#0x} )); else last_el_block="-"; fi

    echo "$pair,$execution,$consensus,${install_code:-missing},${crash:-unknown},$sample_count,$last_doctor,${last_disk:-0},${residual:-0},${cfg_optimal:-unknown},${cfg_detail:-},${_synced:-unknown},$sync_dur_h,$sync_only_h,$last_el_block"
  done
} > "$artifact_root/summary.csv"

# Process telemetry coverage.
{
  echo "pair,process_sample_rows"
  for dir in "$artifact_root"/*__*; do
    [[ -d "$dir" ]] || continue
    pair="$(basename "$dir")"
    rows="$(jq -r '.processes[]?' "$dir/samples.jsonl" 2>/dev/null | wc -l || echo 0)"
    echo "$pair,$rows"
  done
} > "$artifact_root/process-summary.csv"

# Full artifact report (gitignored).
{
  echo "# Eth2 Client Bake-off Report"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Summary"
  echo
  column -s, -t "$artifact_root/summary.csv" 2>/dev/null || cat "$artifact_root/summary.csv"
  echo
  echo "## Candidate Findings"
  for findings in "$artifact_root"/*__*/findings.md; do
    [[ -f "$findings" ]] || continue
    echo
    echo "### $(basename "$(dirname "$findings")")"
    sed -n '1,220p' "$findings"
  done
} > "$artifact_root/report.md"

# Machine-generated results SKELETON. Writes to the gitignored artifact root, NOT
# docs/CLIENT_BAKEOFF_RESULTS.md — that doc is hand-curated (blog source-of-truth)
# and must never be overwritten by this script.
{
  echo "# Eth2 Client Bake-off Results"
  echo
  echo "_Synthesized from \`artifacts/client-bakeoff-2026-06-22/\` on $(date -u +%Y-%m-%dT%H:%M:%SZ). Raw artifacts are gitignored._"
  echo
  echo "## Method"
  echo
  echo "- Baseline-anchored coverage: every execution client vs fixed Prysm; every consensus client vs fixed Geth."
  echo "- Two stages: triage (~90m, checkpoint sync) then full sync-to-completion for viable candidates."
  echo "- Strictly sequential, resource-capped (eth1 600%/24G, cl 200%/12G) to protect co-resident agents."
  echo "- MEV: none. No validator keys."
  echo
  echo "## Results (optimal config only)"
  echo
  echo '| Pair | Install | Crash | Samples | Sync time | Last disk (bytes) | Residual after cleanup |'
  echo '| --- | --- | --- | --- | --- | --- | --- |'
  awk -F, 'NR>1 && $10!="no" {printf "| %s | %s | %s | %s | %s | %s | %s |\n",$1,$4,$5,$6,$13,$8,$9}' "$artifact_root/summary.csv"
  echo
  echo "## Superseded — non-optimal config (excluded from ranking)"
  echo
  echo "_Rows below were recorded with a missing history-prune flag. Footprints are NOT comparable to the optimal rows above._"
  echo
  echo '| Pair | Install | Crash | Samples | Sync time | Last disk (bytes) | Config detail |'
  echo '| --- | --- | --- | --- | --- | --- | --- |'
  awk -F, 'NR>1 && $10=="no" {printf "| %s | %s | %s | %s | %s | %s | %s |\n",$1,$4,$5,$6,$13,$8,$11}' "$artifact_root/summary.csv" || true
  echo
  echo "## Recommendation"
  echo
  echo "<!-- Reviewer: fill the recommended stack and rationale from the table + per-candidate findings.md -->"
  echo "- Recommended execution client:"
  echo "- Recommended consensus client:"
  echo "- Rationale:"
  echo
  echo "## Final synced disk footprint (Stage B)"
  echo
  echo "<!-- Reviewer: record per-client final synced disk size once Stage B completes -->"
  echo
  echo "## Changes driven by this bake-off"
  echo
  echo "<!-- Reviewer: list repo fixes (install scripts, config tuning) landed as a result. 'None' if clean. -->"
} > "$generated_doc"

log_info "Wrote $artifact_root/summary.csv, report.md, and $generated_doc"
