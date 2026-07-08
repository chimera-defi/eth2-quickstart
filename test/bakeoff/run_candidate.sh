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

# Anchor mode: when set, preserves this EL across the entire CL sweep.
anchor_el="${ETH2QS_BAKEOFF_ANCHOR_EL:-}"

if [[ "${ETH2QS_BAKEOFF_CONFIRMED:-}" != "yes" ]]; then
  log_error "Refusing destructive bake-off. Set ETH2QS_BAKEOFF_CONFIRMED=yes after operator confirms this is not a production validator host."
  exit 2
fi

# Anchor-mode precondition: verify the anchor EL is running, listening on 8551, and synced.
if [[ -n "$anchor_el" ]]; then
  if [[ "$execution" != "$anchor_el" ]]; then
    log_error "Anchor mismatch: ETH2QS_BAKEOFF_ANCHOR_EL=$anchor_el but execution arg=$execution. Aborting."
    exit 3
  fi
  if ! systemctl is-active --quiet eth1.service; then
    log_error "Anchor EL (eth1.service=$anchor_el) is not active. Start it before running anchor mode."
    exit 3
  fi
  # Confirm Engine API port 8551 is accepting connections (401 = auth required = OK).
  _engine_http="$(curl -sS --max-time 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8551 2>/dev/null || true)"
  if [[ ! "$_engine_http" =~ ^[1-5][0-9]{2}$ ]]; then
    log_error "Anchor EL ($anchor_el) Engine API port 8551 is not responding (HTTP code '$_engine_http'; need 1xx-5xx). Wait for EL before running CL sweep."
    exit 3
  fi
  log_info "Anchor EL ($anchor_el) Engine API 8551 is responding (HTTP $_engine_http)."
  # Bounded retry (~10s): wait for anchor EL eth_syncing==false before proceeding.
  _anchor_synced=false
  for _retry in 1 2 3 4 5; do
    _el_sync="$(bakeoff_probe_execution_sync 2>/dev/null || true)"
    if echo "$_el_sync" | jq -e '
      (.result == false)
      or ( ((.result|type) == "object")
           and (.result.currentBlock == .result.highestBlock)
           and (.result.highestBlock != "0x0") )
    ' >/dev/null 2>&1; then
      _anchor_synced=true
      break
    fi
    log_info "Anchor EL ($anchor_el) not yet synced (attempt $_retry/5, retrying in 2s)…"
    sleep 2
  done
  if [[ "$_anchor_synced" != "true" ]]; then
    log_error "Anchor EL ($anchor_el) is not yet synced after retries (eth_syncing returned: $_el_sync). Wait for EL sync before running CL sweep."
    exit 3
  fi
  log_info "Anchor mode: EL=$anchor_el is active and synced. Cycling CL only."
fi

if [[ -f "$out/.done" && "${ETH2QS_BAKEOFF_FORCE:-}" != "yes" ]]; then
  log_info "Skipping $pair (already complete; set ETH2QS_BAKEOFF_FORCE=yes to rerun)"
  exit 0
fi

# FORCE re-run: clear stale poison markers so the anchor watchdog re-evaluates from scratch.
# Without this, a prior .anchor-poisoned bypasses the watchdog entirely (line 175 guard),
# then finalization falsely writes anchor_synced=no for an otherwise-clean run.
if [[ "${ETH2QS_BAKEOFF_FORCE:-}" == "yes" ]]; then
  rm -f "$out/.anchor-poisoned" "$out/.done"
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
  if [[ -n "$anchor_el" ]]; then
    echo "harness_mode=anchor"
    echo "anchor_el=$anchor_el"
  elif [[ "${ETH2QS_BAKEOFF_KEEP_EL:-}" == "yes" ]]; then
    echo "harness_mode=establish"
  else
    echo "harness_mode=full"
  fi
} > "$out/env.txt"

# Candidate isolation: ensure no prior client survives into this candidate.
if [[ -n "$anchor_el" ]]; then
  # Anchor mode: stop/disable ONLY CL+validator; preserve the anchor EL.
  sudo systemctl stop cl.service validator.service 2>/dev/null || true
  sudo systemctl disable cl.service validator.service 2>/dev/null || true
else
  sudo systemctl stop eth1.service cl.service validator.service 2>/dev/null || true
  sudo systemctl disable eth1.service cl.service validator.service 2>/dev/null || true
fi

# Pre-install clean + baseline.
if [[ -n "$anchor_el" ]]; then
  # Anchor mode: purge CL datadirs only; never touch the EL anchor.
  ./scripts/eth2qs.sh clean-data --scope=consensus --dry-run < /dev/null > "$out/cleanup-before-dry-run.log" 2>&1 || true
  ./scripts/eth2qs.sh clean-data --scope=consensus --confirm < /dev/null > "$out/cleanup-before-confirm.log" 2>&1
else
  ./scripts/eth2qs.sh clean-data --dry-run < /dev/null > "$out/cleanup-before-dry-run.log" 2>&1 || true
  ./scripts/eth2qs.sh clean-data --confirm < /dev/null > "$out/cleanup-before-confirm.log" 2>&1
fi
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
# </dev/null: installs are non-interactive; prevents SIGTTIN stop when run in a background process group (detached tmux).
if [[ -n "$anchor_el" ]]; then
  # Anchor mode: install CL only; anchor EL is already running.
  timeout "$install_timeout" /usr/bin/time -v -o "$out/install-time.txt" \
    ./scripts/eth2qs.sh phase2 --consensus="$consensus" --mev=none \
    </dev/null > "$out/install.log" 2>&1
else
  timeout "$install_timeout" /usr/bin/time -v -o "$out/install-time.txt" \
    ./scripts/eth2qs.sh phase2 --execution="$execution" --consensus="$consensus" --mev=none \
    </dev/null > "$out/install.log" 2>&1
fi
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

# Config-optimality gate: checks running config for history-prune tokens.
# Non-blocking — flags non-optimal rows without aborting the run.
bakeoff_check_config_optimal "$execution" "$consensus" "$out" || true

# Observation window (skipped if install failed).
crashed="no"
if [[ "$install_rc" -eq 0 ]]; then
  end_at=$(( $(date +%s) + window ))
  synced_streak=0
  anchor_miss_streak=0
  while [[ "$(date +%s)" -lt "$end_at" ]]; do
    bakeoff_write_sample "$out" "$REPO_ROOT" || log_warn "$pair: sample write failed"
    if ! bakeoff_services_alive; then
      crashed="yes"
      log_warn "$pair: a service is no longer active during the window"
    fi
    # Anchor-only watchdog: detect if the anchor EL dropped into a re-snap.
    # DETECTION ONLY — never restarts or kills anything.
    if [[ -n "$anchor_el" ]] && [[ ! -f "$out/.anchor-poisoned" ]]; then
      anchor_miss="no"
      if ! systemctl is-active --quiet eth1.service 2>/dev/null; then
        # Anchor EL not running at all — in anchor mode this invalidates the row.
        anchor_miss="yes"
      else
        _snap_check="$(cat "$out/tmp/execution-sync.json" 2>/dev/null || true)"
        # Non-empty payload that does NOT parse as "synced" is a miss.
        if [[ -n "$_snap_check" ]] && ! echo "$_snap_check" | jq -e '
          (.result == false)
          or ( ((.result|type) == "object")
               and (.result.currentBlock == .result.highestBlock)
               and (.result.highestBlock != "0x0") )
        ' >/dev/null 2>&1; then
          anchor_miss="yes"
        fi
      fi
      if [[ "$anchor_miss" == "yes" ]]; then
        anchor_miss_streak=$((anchor_miss_streak + 1))
      else
        anchor_miss_streak=0
      fi
      if [[ "$anchor_miss_streak" -ge 2 ]]; then
        touch "$out/.anchor-poisoned"
        log_error "anchor EL $anchor_el lost $anchor_miss_streak consecutive samples at $(date -u +%Y-%m-%dT%H:%M:%SZ): row invalid"
      fi
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
# Anchor finalize gate: record anchor_synced=yes|no only when running in anchor mode.
# Non-anchor runs write nothing here; summarize.sh reads missing as n/a (unset behavior unchanged).
if [[ -n "$anchor_el" ]]; then
  if [[ -f "$out/.anchor-poisoned" ]]; then
    echo "anchor_synced=no" >> "$out/env.txt"
  else
    echo "anchor_synced=yes" >> "$out/env.txt"
  fi
fi

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

bakeoff_snapshot_disk "$out/disk-final.tsv"   # pre-cleanup footprint (synced OR capped)

# Clear caps + post-run cleanup.
"$caps" clear >> "$out/resource-caps.log" 2>&1 || true
if [[ -n "$anchor_el" || "${ETH2QS_BAKEOFF_KEEP_EL:-}" == "yes" ]]; then
  # Anchor mode / establish mode: purge CL datadirs only; preserve the EL
  # (anchor EL serves the CL sweep; establish EL becomes the next anchor).
  ./scripts/eth2qs.sh clean-data --scope=consensus --dry-run < /dev/null > "$out/cleanup-dry-run.log" 2>&1 || true
  ./scripts/eth2qs.sh clean-data --scope=consensus --confirm < /dev/null > "$out/cleanup-confirm.log" 2>&1 || true
else
  ./scripts/eth2qs.sh clean-data --dry-run < /dev/null > "$out/cleanup-dry-run.log" 2>&1 || true
  ./scripts/eth2qs.sh clean-data --confirm < /dev/null > "$out/cleanup-confirm.log" 2>&1 || true
fi
bakeoff_snapshot_disk "$out/disk-after-cleanup.tsv"

echo "ended_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$out/env.txt"
touch "$out/.done"
exit "$install_rc"
