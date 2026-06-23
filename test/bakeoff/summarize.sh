#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"

artifact_root="$REPO_ROOT/artifacts/client-bakeoff-2026-06-22"
results_doc="$REPO_ROOT/docs/CLIENT_BAKEOFF_RESULTS.md"
[[ -d "$artifact_root" ]] || { log_error "No artifact root at $artifact_root"; exit 1; }

# Machine-readable summary.
{
  echo "pair,execution,consensus,install_exit_code,crash,sample_count,last_doctor_status,last_disk_bytes,residual_bytes"
  for dir in "$artifact_root"/*__*; do
    [[ -d "$dir" ]] || continue
    pair="$(basename "$dir")"
    execution="${pair%%__*}"; consensus="${pair##*__}"
    install_code="$(grep -E '^install_exit_code=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    crash="$(grep -E '^service_crash_observed=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)" || true
    sample_count="$(wc -l < "$dir/samples.jsonl" 2>/dev/null || echo 0)"
    last_doctor="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.doctor.summary.status // "unknown"' 2>/dev/null || echo unknown)"
    last_disk="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.disk_tsv' 2>/dev/null | awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}')" || true
    residual="$(awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}' "$dir/disk-after-cleanup.tsv" 2>/dev/null || echo 0)"
    echo "$pair,$execution,$consensus,${install_code:-missing},${crash:-unknown},$sample_count,$last_doctor,${last_disk:-0},${residual:-0}"
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

# Committed, durable, human-readable results doc synthesized from artifacts.
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
  echo "## Results"
  echo
  echo '| Pair | Install | Crash | Samples | Last doctor | Last disk (bytes) | Residual after cleanup |'
  echo '| --- | --- | --- | --- | --- | --- | --- |'
  awk -F, 'NR>1{printf "| %s | %s | %s | %s | %s | %s | %s |\n",$1,$4,$5,$6,$7,$8,$9}' "$artifact_root/summary.csv"
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
} > "$results_doc"

log_info "Wrote $artifact_root/summary.csv, report.md, and $results_doc"
