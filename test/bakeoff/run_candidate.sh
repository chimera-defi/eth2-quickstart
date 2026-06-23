#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"
# shellcheck source=lib.sh
source "$REPO_ROOT/test/bakeoff/lib.sh"

execution="${1:?usage: run_candidate.sh <execution> <consensus>}"
consensus="${2:?usage: run_candidate.sh <execution> <consensus>}"
pair="${execution}__${consensus}"
artifact_root="$REPO_ROOT/artifacts/${ETH2QS_BAKEOFF_RUN_ID:-client-bakeoff-2026-06-22}"
out="$artifact_root/$pair"
window="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-5400}"
interval="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-120}"
install_timeout="${ETH2QS_BAKEOFF_INSTALL_TIMEOUT:-90m}"
caps="$REPO_ROOT/test/bakeoff/apply_resource_caps.sh"

if [[ "${ETH2QS_BAKEOFF_CONFIRMED:-}" != "yes" ]]; then
  log_error "Refusing destructive bake-off. Set ETH2QS_BAKEOFF_CONFIRMED=yes after operator confirms this is not a production validator host."
  exit 2
fi

if [[ -f "$out/.done" && "${ETH2QS_BAKEOFF_FORCE:-}" != "yes" ]]; then
  log_info "Skipping $pair (already complete; set ETH2QS_BAKEOFF_FORCE=yes to rerun)"
  exit 0
fi

cd "$REPO_ROOT"
mkdir -p "$out/tmp"

{
  echo "execution=$execution"
  echo "consensus=$consensus"
  echo "mev=none"
  echo "started_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "sync_window_seconds=$window"
  echo "sample_interval_seconds=$interval"
  echo "install_timeout=$install_timeout"
} > "$out/env.txt"

# Candidate isolation: ensure no prior client survives into this candidate.
sudo systemctl stop eth1.service cl.service validator.service 2>/dev/null || true
sudo systemctl disable eth1.service cl.service validator.service 2>/dev/null || true

# Pre-install clean + baseline.
./scripts/eth2qs.sh clean-data --dry-run > "$out/cleanup-before-dry-run.log" 2>&1 || true
./scripts/eth2qs.sh clean-data --confirm > "$out/cleanup-before-confirm.log" 2>&1
bakeoff_snapshot_disk "$out/disk-before.tsv"
avail_bytes="$(df -B1 --output=avail / | tail -1 | tr -d ' ')"
min_disk="${ETH2QS_BAKEOFF_MIN_DISK_BYTES:-1717986918400}"   # 1.6 TiB floor
if [[ "${avail_bytes:-0}" -lt "$min_disk" ]]; then
  log_error "$pair: only ${avail_bytes} bytes free on / (< ${min_disk} required). Aborting before sync."
  exit 3
fi
./scripts/eth2qs.sh plan   --json > "$out/plan-before.json"   2>&1 || true
./scripts/eth2qs.sh doctor --json > "$out/doctor-before.json" 2>&1 || true
./scripts/eth2qs.sh stats  --json > "$out/stats-before.json"  2>&1 || true

# Authenticate GitHub API to avoid 60/hr unauthenticated rate limit.
if [[ -z "${GITHUB_TOKEN:-}" && -z "${GH_TOKEN:-}" ]] && command -v gh &>/dev/null; then
  _gh_tok="$(gh auth token 2>/dev/null || true)"
  if [[ -n "$_gh_tok" ]]; then
    export GITHUB_TOKEN="$_gh_tok"
  fi
  unset _gh_tok
fi

# Install (real; bounded by timeout).
set +e
timeout "$install_timeout" /usr/bin/time -v -o "$out/install-time.txt" \
  ./scripts/eth2qs.sh phase2 --execution="$execution" --consensus="$consensus" --mev=none \
  > "$out/install.log" 2>&1
install_rc=$?
set -e
echo "install_exit_code=$install_rc" >> "$out/env.txt"

# Apply resource caps once services exist.
"$caps" apply > "$out/resource-caps.log" 2>&1 || true

# Post-install health snapshot.
./scripts/eth2qs.sh doctor  --json            > "$out/doctor-after-install.json"  2>&1 || true
./scripts/eth2qs.sh stats   --json            > "$out/stats-after-install.json"   2>&1 || true
./scripts/eth2qs.sh monitor export --json     > "$out/monitor-after-install.json" 2>&1 || true
./scripts/eth2qs.sh debug   --json --service eth1 > "$out/debug-eth1-after-install.json" 2>&1 || true
./scripts/eth2qs.sh debug   --json --service cl   > "$out/debug-cl-after-install.json"   2>&1 || true
systemctl status eth1 cl validator --no-pager -l > "$out/service-status.txt" 2>&1 || true

# Observation window (skipped if install failed).
crashed="no"
if [[ "$install_rc" -eq 0 ]]; then
  end_at=$(( $(date +%s) + window ))
  synced_streak=0
  while [[ "$(date +%s)" -lt "$end_at" ]]; do
    bakeoff_write_sample "$out" "$REPO_ROOT" || log_warn "$pair: sample write failed"
    if ! bakeoff_services_alive; then
      crashed="yes"
      log_warn "$pair: a service is no longer active during the window"
    fi
    if bakeoff_is_synced; then
      synced_streak=$((synced_streak + 1))
    else
      synced_streak=0
    fi
    if [[ "$synced_streak" -ge 2 ]]; then
      bakeoff_snapshot_disk "$out/disk-synced.tsv"
      echo "synced_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$out/env.txt"
      echo "fully_synced=yes" >> "$out/env.txt"
      break
    fi
    sleep "$interval"
  done
  bakeoff_write_sample "$out" "$REPO_ROOT" || log_warn "$pair: sample write failed"
fi
grep -q '^fully_synced=' "$out/env.txt" || echo "fully_synced=no" >> "$out/env.txt"
echo "service_crash_observed=$crashed" >> "$out/env.txt"

# Logs + repair preview.
journalctl -u eth1 -n 700 --no-pager > "$out/journal-eth1.log" 2>&1 || true
journalctl -u cl   -n 700 --no-pager > "$out/journal-cl.log"   2>&1 || true
journalctl -u validator -n 300 --no-pager > "$out/journal-validator.log" 2>&1 || true
./scripts/eth2qs.sh repair > "$out/repair-preview.txt" 2>&1 || true

# Seed findings (classification filled in by reviewer/summarize).
{
  echo "# $execution + $consensus Findings"
  echo
  echo "Install exit code: $install_rc"
  echo "Service crash observed: $crashed"
  echo
  echo "## Classification"
  echo "- Result: TBD-by-reviewer"
  echo "- Install: $([[ $install_rc -eq 0 ]] && echo pass || echo fail)"
  echo "- Services: $([[ $crashed == no && $install_rc -eq 0 ]] && echo pass || echo fail)"
  echo
  echo "## Required Fixes"
  echo "- Review install.log, doctor-after-install.json, debug-*.json, repair-preview.txt, journals."
} > "$out/findings.md"

# Clear caps + post-run cleanup.
"$caps" clear >> "$out/resource-caps.log" 2>&1 || true
./scripts/eth2qs.sh clean-data --dry-run > "$out/cleanup-dry-run.log" 2>&1 || true
./scripts/eth2qs.sh clean-data --confirm > "$out/cleanup-confirm.log" 2>&1 || true
bakeoff_snapshot_disk "$out/disk-after-cleanup.tsv"

echo "ended_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$out/env.txt"
touch "$out/.done"
exit "$install_rc"
