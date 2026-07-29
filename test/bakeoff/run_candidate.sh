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
# Advisor alert channel: single JSONL file per run_id, shared across every
# candidate row (and with run_queue.sh, when driven from there) so an
# operator/supervising-AI can `tail -f` one file for the whole run.
export ETH2QS_BAKEOFF_ALERT_LOG="${ETH2QS_BAKEOFF_ALERT_LOG:-$artifact_root/advisor-alerts.jsonl}"
out="$artifact_root/$pair"
window="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-5400}"
interval="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-120}"
install_timeout="${ETH2QS_BAKEOFF_INSTALL_TIMEOUT:-90m}"
stall_restart="${ETH2QS_BAKEOFF_STALL_RESTART:-no}"
stall_samples="${ETH2QS_BAKEOFF_STALL_SAMPLES:-10}"
stall_max_restarts="${ETH2QS_BAKEOFF_STALL_MAX_RESTARTS:-3}"
# Crash-loop watchdog: always-on (not opt-in). Default 20 is far above what a
# healthy candidate ever sees (~0 restarts across a run) but far below a real
# crash loop (hundreds within minutes) — see incident note at the watchdog site.
crash_loop_max_restarts="${ETH2QS_BAKEOFF_MAX_RESTARTS:-20}"
caps="$REPO_ROOT/test/bakeoff/apply_resource_caps.sh"

# Anchor mode: when set, preserves this EL across the entire CL sweep.
anchor_el="${ETH2QS_BAKEOFF_ANCHOR_EL:-}"

if [[ "${ETH2QS_BAKEOFF_CONFIRMED:-}" != "yes" ]]; then
  log_error "Refusing destructive bake-off. Set ETH2QS_BAKEOFF_CONFIRMED=yes after operator confirms this is not a production validator host."
  exit 2
fi

# The bake-off runs eth2qs.sh phase2 WITHOUT a prior run_1, so run_2.sh's post-install
# security validation (run_1-dependent: expects active UFW, security_monitor, etc.) is
# inappropriate here and exit-1s — aborting client installs whenever UFW is inactive.
# CI_E2E=true is the codebase's existing switch for a run_1-less phase2 (run_2.sh:469);
# it also skips UFW setup (needs run_1/kernel modules). It does NOT change the installed
# client binary/config/datadir or its sync footprint. An explicit caller value still wins.
export CI_E2E="${CI_E2E:-true}"

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
      def h2n:
        if . == null then 0
        else (ltrimstr("0x")
              | if . == "" then 0
                else reduce (explode[]) as $c (0;
                       . * 16 + (
                         if   $c >= 48 and $c <= 57  then $c - 48
                         elif $c >= 97 and $c <= 102 then $c - 87
                         elif $c >= 65 and $c <= 70  then $c - 55
                         else 0 end))
                end)
        end;
      (.result == false)
      or ( ((.result|type) == "object")
           and (.result.highestBlock != "0x0")
           and ((.result.currentBlock | h2n) >= (.result.highestBlock | h2n)) )
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
  rm -f "$out/.anchor-poisoned" "$out/.crash-looped" "$out/.done"
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
# Anchor mode reuses the already-synced EL on disk (only the CL is new), so the full
# EL+CL floor does not apply; a 1.6 TiB floor would falsely abort every anchor CL sweep
# once the anchor EL occupies the disk. Use a CL-sized floor in anchor mode. An explicit
# ETH2QS_BAKEOFF_MIN_DISK_BYTES override still wins in both modes.
if [[ -n "$anchor_el" ]]; then
  min_disk="${ETH2QS_BAKEOFF_MIN_DISK_BYTES:-429496729600}"    # 400 GiB floor: anchor CL-only
else
  min_disk="${ETH2QS_BAKEOFF_MIN_DISK_BYTES:-1717986918400}"   # 1.6 TiB floor: full EL+CL sync
fi
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
if [[ "$install_rc" -ne 0 ]]; then
  bakeoff_advisor_alert error "$pair" install_failed "phase2 install exited $install_rc (see $out/install.log)" || true
fi

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
  no_progress_streak=0
  stall_restarts=0
  prev_progress=""
  # Crash-loop watchdog baseline: unit(s) under test only (anchor mode tests
  # cl.service alone; the anchor eth1.service is pre-existing and out of scope).
  if [[ -n "$anchor_el" ]]; then
    crash_loop_units=(cl.service)
  else
    crash_loop_units=(eth1.service cl.service)
  fi
  crash_loop_baseline_eth1="$(systemctl show eth1.service -p NRestarts --value 2>/dev/null || true)"
  [[ "$crash_loop_baseline_eth1" =~ ^[0-9]+$ ]] || crash_loop_baseline_eth1=0
  crash_loop_baseline_cl="$(systemctl show cl.service -p NRestarts --value 2>/dev/null || true)"
  [[ "$crash_loop_baseline_cl" =~ ^[0-9]+$ ]] || crash_loop_baseline_cl=0
  while [[ "$(date +%s)" -lt "$end_at" ]]; do
    bakeoff_write_sample "$out" "$REPO_ROOT" || log_warn "$pair: sample write failed"
    if ! bakeoff_services_alive; then
      crashed="yes"
      log_warn "$pair: a service is no longer active during the window"
    fi
    # Crash-loop watchdog (always-on): detect a unit under test flapping under
    # systemd's Restart= (e.g. a config error causing an immediate exit that
    # respawns every few seconds). "$crashed"/bakeoff_services_alive above
    # only catches this if a sample happens to land while the unit is down
    # between restarts — unreliable, since a flapping unit is "active" again
    # within seconds. NRestarts is cumulative and monotonic, so it catches the
    # pattern regardless of sample timing. Incident: lodestar's cl.service
    # crash-looped on `Unknown argument: chain` (exit 1, ~5s per cycle) and was
    # respawned 20,892 times over ~2 days; the harness kept sampling to the
    # full 72h window on generic "service is no longer active" warnings alone
    # and would have produced nothing without a human noticing. This watchdog
    # fails the row fast instead.
    # NOTE: the break decision below is driven by an in-loop flag, not by
    # checking for "$out/.crash-looped" on disk — a marker file left over from
    # a prior interrupted run (killed mid-window, before .done was written)
    # would otherwise cause a false-positive break on the very first sample of
    # a rerun, with no matching crash_loop_detected= line in the fresh env.txt.
    crash_loop_hit=no
    for _cl_unit in "${crash_loop_units[@]}"; do
      _cl_cur="$(systemctl show "$_cl_unit" -p NRestarts --value 2>/dev/null || true)"
      [[ "$_cl_cur" =~ ^[0-9]+$ ]] || _cl_cur=0
      if [[ "$_cl_unit" == "eth1.service" ]]; then
        _cl_base="$crash_loop_baseline_eth1"
      else
        _cl_base="$crash_loop_baseline_cl"
      fi
      _cl_delta=$(( _cl_cur - _cl_base ))
      if [[ "$_cl_delta" -gt "$crash_loop_max_restarts" ]]; then
        touch "$out/.crash-looped"
        {
          echo "crash_loop_detected=yes"
          echo "crash_loop_unit=$_cl_unit"
          echo "crash_loop_restarts=$_cl_delta"
        } >> "$out/env.txt"
        log_error "$pair: crash-loop-watchdog: $_cl_unit restarted $_cl_delta times (> $crash_loop_max_restarts threshold) at $(date -u +%Y-%m-%dT%H:%M:%SZ): row invalid"
        bakeoff_advisor_alert error "$pair" crash_loop "$_cl_unit restarted $_cl_delta times (> $crash_loop_max_restarts threshold)" || true
        crash_loop_hit=yes
        break
      fi
    done
    if [[ "$crash_loop_hit" == "yes" ]]; then
      break
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
          def h2n:
            if . == null then 0
            else (ltrimstr("0x")
                  | if . == "" then 0
                    else reduce (explode[]) as $c (0;
                           . * 16 + (
                             if   $c >= 48 and $c <= 57  then $c - 48
                             elif $c >= 97 and $c <= 102 then $c - 87
                             elif $c >= 65 and $c <= 70  then $c - 55
                             else 0 end))
                    end)
            end;
          (.result == false)
          or ( ((.result|type) == "object")
               and (.result.highestBlock != "0x0")
               and ((.result.currentBlock | h2n) >= (.result.highestBlock | h2n)) )
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
        bakeoff_advisor_alert error "$pair" anchor_poisoned "anchor EL $anchor_el lost $anchor_miss_streak consecutive samples" || true
      fi
    fi
    # Stall-watchdog: opt-in auto-restart of a stuck EL/CL (bounded).
    # Entirely inert unless ETH2QS_BAKEOFF_STALL_RESTART=yes.
    if [[ "$stall_restart" == "yes" ]]; then
      if [[ -n "$anchor_el" ]]; then
        stall_unit="cl.service"
        cur_progress="$(jq -r '.data.head_slot // empty' "$out/tmp/beacon-sync.json" 2>/dev/null || true)"
        # Fallback: decreasing sync_distance also counts as forward progress.
        if [[ -z "$cur_progress" ]]; then
          cur_progress="$(jq -r 'if .data.sync_distance then (100000000 - (.data.sync_distance | tonumber)) else empty end' "$out/tmp/beacon-sync.json" 2>/dev/null || true)"
        fi
      else
        stall_unit="eth1.service"
        cur_progress="$(jq -r '
          def h2n:
            if . == null then empty
            else (ltrimstr("0x")
                  | if . == "" then empty
                    else reduce (explode[]) as $c (0;
                           . * 16 + (
                             if   $c >= 48 and $c <= 57  then $c - 48
                             elif $c >= 97 and $c <= 102 then $c - 87
                             elif $c >= 65 and $c <= 70  then $c - 55
                             else 0 end))
                    end)
            end;
          if .result == false then empty
          elif ((.result|type) == "object") then (.result.currentBlock | h2n | tostring)
          else empty
          end
        ' "$out/tmp/execution-sync.json" 2>/dev/null || true)"
      fi
      # Determine if already synced this sample (reset streak; never stall when synced).
      if bakeoff_is_synced; then
        no_progress_streak=0
      elif [[ -z "$prev_progress" ]] && [[ -n "$cur_progress" ]]; then
        # First valid reading: treat as baseline, not a stall.
        no_progress_streak=0
      elif [[ -n "$prev_progress" ]] && [[ -n "$cur_progress" ]] && [[ "$cur_progress" -gt "$prev_progress" ]] 2>/dev/null; then
        # Progress detected.
        no_progress_streak=0
      else
        no_progress_streak=$((no_progress_streak + 1))
      fi
      # Only update prev_progress when we have a valid reading.
      if [[ -n "$cur_progress" ]]; then
        prev_progress="$cur_progress"
      fi
      if [[ "$no_progress_streak" -ge "$stall_samples" ]]; then
        if [[ "$stall_restarts" -lt "$stall_max_restarts" ]]; then
          stall_restarts=$((stall_restarts + 1))
          no_progress_streak=0
          log_warn "$pair: stall-watchdog: restarting $stall_unit (restart $stall_restarts/$stall_max_restarts) at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
          if sudo systemctl restart "$stall_unit"; then
            log_warn "$pair: stall-watchdog: $stall_unit restarted successfully"
          else
            log_warn "$pair: stall-watchdog: $stall_unit restart failed (will retry next stall)"
          fi
        else
          touch "$out/.stalled"
          log_error "$pair: stall-watchdog: $stall_unit made no progress after $stall_restarts restarts at $(date -u +%Y-%m-%dT%H:%M:%SZ): row invalid"
          echo "stall_restarts=$stall_restarts" >> "$out/env.txt"
          echo "stall_failed=yes" >> "$out/env.txt"
          bakeoff_advisor_alert error "$pair" stall "$stall_unit made no progress after $stall_restarts restarts" || true
          break
        fi
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
# Window-capped-without-sync: only fires when the observation window actually
# ran and expired on its own (install succeeded) without ever reaching
# fully_synced=yes, and neither of the two OTHER give-up paths (crash-loop,
# stall) already fired their own error alert for this same row.
if [[ "$install_rc" -eq 0 ]] \
  && ! grep -q '^fully_synced=yes$' "$out/env.txt" \
  && [[ ! -f "$out/.crash-looped" ]] \
  && [[ ! -f "$out/.stalled" ]]; then
  bakeoff_advisor_alert warn "$pair" window_capped_unsynced "observation window (${window}s) expired without reaching synced" || true
fi
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

# A crash-looped row is an invalid measurement, but install itself succeeded, so
# install_rc is 0. Exiting 0 here would let run_queue.sh / run_bakeoff.sh record
# the row as a clean run despite the .crash-looped marker and the error alert.
# Cleanup and artifact capture above are preserved; only the terminal status
# changes. 4 is distinct from 3 (anchor not synced) and from install failures.
if [[ "${crash_loop_hit:-no}" == "yes" ]]; then
  exit 4
fi
exit "$install_rc"
