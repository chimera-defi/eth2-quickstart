# Eth2 Client Bake-off Metrics Implementation Plan (v2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build committed, reusable bake-off tooling that installs every supported EL once (vs fixed Prysm) and every CL once (vs fixed Geth), runs a cheap triage stage then a full sync-to-completion stage under strict resource caps, and synthesizes a committed results doc recommending the best stack.

**Architecture:** Six shell files under `test/bakeoff/` drive `./scripts/eth2qs.sh` lifecycle commands. A baseline-anchored 12-candidate manifest isolates blame. Runs are strictly sequential with runtime systemd resource caps on `eth1`/`cl` so co-resident agents keep ~4 cores + ~20 GiB. Artifacts land in gitignored `artifacts/client-bakeoff-2026-06-22/`; a synthesized summary is committed to `docs/CLIENT_BAKEOFF_RESULTS.md`.

**Tech Stack:** Bash, systemd (`systemctl set-property --runtime`), `./scripts/eth2qs.sh`, JSON-RPC, Beacon REST, `curl`, `jq`, `du`, `df`, `ps`, `journalctl`, `/usr/bin/time`, shellcheck.

## Global Constraints

- Repo root for all live operations: `/home/agents/workspace/eth2-quickstart`.
- Harness scripts: committed under `test/bakeoff/`, shellcheck-clean with the project excludes `SC2317,SC1091,SC1090,SC2034,SC2031,SC2181`, and `bash -n` clean.
- Every harness script sources `lib/common_functions.sh` for logging (`log_info`/`log_warn`/`log_error`) and sets `set -Eeuo pipefail` itself. Do NOT source `exports.sh` inside sampling scripts (its `IFS=$'\n\t'` breaks `ps`/`awk`/`curl` pipelines).
- `--mev=none` for every candidate. Never generate validator keys. Never set `CI_E2E=true` (forces mocks/source mode — we want real installs).
- Destructive cleanup is gated by `ETH2QS_BAKEOFF_CONFIRMED=yes`.
- Artifact root: `artifacts/client-bakeoff-2026-06-22/` (already gitignored).
- Service unit names: `eth1.service`, `cl.service`, `validator.service`.
- Resource split: node stack ≤ 8 of 12 cores and ≤ 36 GiB (eth1 600%/24G, cl 200%/12G), leaving ~4 cores + ~26 GiB for agents.
- Bake-off config overrides live in `config/bakeoff.env` and are installed as `config/user_config.env` (with backup/restore) for the duration of a run.
- Conventional Commits. Commit after each task.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `config/bakeoff.env` | Cache/peer overrides installed as `user_config.env` during a run. |
| `test/bakeoff/candidates.tsv` | 12-candidate baseline-anchored manifest (`execution<TAB>consensus`). |
| `test/bakeoff/lib.sh` | Sourced library: canonical data-dir list, disk/process/sync probes, JSONL sampler, crash check. |
| `test/bakeoff/test_data_dirs_sync.sh` | Asserts `lib.sh` data-dir list matches `purge_ethereum_data.sh` DATA_DIRS. |
| `test/bakeoff/apply_resource_caps.sh` | `apply`/`clear` runtime systemd caps on `eth1`/`cl`. |
| `test/bakeoff/run_candidate.sh` | Single-candidate runner: clean → install → caps → observe → capture → cleanup. |
| `test/bakeoff/run_bakeoff.sh` | Orchestrator over the manifest; `--stage=triage|full`; sequential; resumable. |
| `test/bakeoff/summarize.sh` | Builds `summary.csv` + `report.md` (artifacts) and synthesizes `docs/CLIENT_BAKEOFF_RESULTS.md` (committed). |

---

## Task 1: Scaffold config + manifest

**Files:**
- Create: `config/bakeoff.env`
- Create: `test/bakeoff/candidates.tsv`

- [ ] **Step 1: Create `config/bakeoff.env`** with exactly this content:

```bash
# Bake-off resource overrides.
# run_bakeoff.sh installs this as config/user_config.env for the duration of a run
# (backing up any existing user_config.env first). Keeps node resource appetite
# bounded so co-resident agents on this shared host keep working.
# Checkpoint-sync URLs are already set in exports.sh and remain on.
export GETH_CACHE=3072
export NETHERMIND_CACHE=3072
export BESU_CACHE=3072
export ERIGON_CACHE=3072
export RETH_CACHE=3072
export NIMBUS_ETH1_CACHE=2048
export ETHREX_CACHE=2048
export TEKU_CACHE=3072
export NIMBUS_CACHE=2048
export LODESTAR_CACHE=3072
export GRANDINE_CACHE=3072
export MAX_PEERS=50
```

- [ ] **Step 2: Create `test/bakeoff/candidates.tsv`** with exactly this content (tab-separated, EL sweep vs prysm then CL sweep vs geth; `geth	prysm` is the shared anchor):

```
geth	prysm
besu	prysm
erigon	prysm
nethermind	prysm
nimbus_eth1	prysm
reth	prysm
ethrex	prysm
geth	lighthouse
geth	teku
geth	nimbus
geth	lodestar
geth	grandine
```

- [ ] **Step 3: Verify the manifest is 12 rows, all clients valid**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
test "$(wc -l < test/bakeoff/candidates.tsv)" -eq 12 && echo "rows OK"
./scripts/eth2qs.sh client-options --json | jq -e . >/dev/null && echo "client-options parses"
```
Expected: `rows OK` and `client-options parses`. Cross-check every name in column 1/2 appears in `client-options --json`.

- [ ] **Step 4: Commit**

```bash
git add config/bakeoff.env test/bakeoff/candidates.tsv
git commit -m "feat(bakeoff): add resource-override config and baseline-anchored candidate manifest"
```

---

## Task 2: Shared library + data-dir sync test

**Files:**
- Create: `test/bakeoff/lib.sh`
- Create: `test/bakeoff/test_data_dirs_sync.sh`

**Interfaces:**
- Produces (sourced by later tasks): `BAKEOFF_DATA_DIRS` (array); functions `bakeoff_snapshot_disk <outfile>`, `bakeoff_probe_execution_sync`, `bakeoff_probe_beacon_sync`, `bakeoff_snapshot_processes`, `bakeoff_write_sample <out_dir> <repo_root>`, `bakeoff_services_alive` (returns 0 iff both `eth1` and `cl` are `active`).

- [ ] **Step 1: Create `test/bakeoff/lib.sh`** with exactly this content:

```bash
#!/bin/bash
# Bake-off shared library. Source me; do not execute.
# shellcheck disable=SC2034

# Canonical default-data directories. KEEP IN SYNC with the DATA_DIRS array in
# install/utils/purge_ethereum_data.sh — test_data_dirs_sync.sh enforces this.
BAKEOFF_DATA_DIRS=(
  "$HOME/.ethereum"
  "$HOME/.local/share/nethermind"
  "$HOME/.local/share/besu"
  "$HOME/.local/share/erigon"
  "$HOME/.local/share/reth"
  "$HOME/.local/share/nimbus-eth1"
  "$HOME/ethrex/data"
  "$HOME/.local/share/prysm"
  "$HOME/.lighthouse"
  "$HOME/.local/share/teku"
  "$HOME/.local/share/nimbus"
  "$HOME/.local/share/lodestar"
  "$HOME/.local/share/grandine"
)

bakeoff_snapshot_disk() {
  local outfile="$1"
  {
    printf 'path\tbytes\thuman\n'
    local path bytes human
    for path in "${BAKEOFF_DATA_DIRS[@]}"; do
      if [[ -e "$path" ]]; then
        bytes="$(du -sb "$path" 2>/dev/null | awk '{print $1}')"
        human="$(du -sh "$path" 2>/dev/null | awk '{print $1}')"
        printf '%s\t%s\t%s\n' "$path" "${bytes:-0}" "${human:-0}"
      fi
    done
    df -B1 / | awk 'NR==2{print "filesystem:/\tused_bytes="$3"\tavailable_bytes="$4}'
  } > "$outfile"
}

bakeoff_probe_execution_sync() {
  curl -sS --max-time 5 -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    http://127.0.0.1:8545 2>/dev/null \
    || printf '{"error":"execution_rpc_unavailable"}'
}

bakeoff_probe_beacon_sync() {
  local url body
  for url in \
    http://127.0.0.1:3500/eth/v1/node/syncing \
    http://127.0.0.1:5051/eth/v1/node/syncing \
    http://127.0.0.1:5052/eth/v1/node/syncing \
    http://127.0.0.1:9596/eth/v1/node/syncing; do
    body="$(curl -sS --max-time 5 "$url" 2>/dev/null || true)"
    if [[ -n "$body" ]]; then
      printf '%s' "$body"
      return 0
    fi
  done
  printf '{"error":"beacon_rest_unavailable"}'
}

bakeoff_snapshot_processes() {
  ps -eo pid=,comm=,%cpu=,%mem=,rss=,vsz=,etime=,args= \
    | awk '/geth|erigon|reth|Nethermind|besu|ethrex|nimbus|prysm|beacon-chain|lighthouse|teku|lodestar|grandine/ {print}' \
    | jq -R -s 'split("\n")[:-1]'
}

bakeoff_services_alive() {
  systemctl is-active --quiet eth1.service && systemctl is-active --quiet cl.service
}

bakeoff_write_sample() {
  local out_dir="$1" repo_root="$2" tmp_dir
  tmp_dir="$out_dir/tmp"
  mkdir -p "$tmp_dir"
  bakeoff_snapshot_disk "$tmp_dir/disk.tsv"
  bakeoff_probe_execution_sync > "$tmp_dir/execution-sync.json" || true
  bakeoff_probe_beacon_sync   > "$tmp_dir/beacon-sync.json"   || true
  bakeoff_snapshot_processes  > "$tmp_dir/processes.json"     || true
  ( cd "$repo_root" && ./scripts/eth2qs.sh doctor --json ) > "$tmp_dir/doctor.json" 2>&1 || true
  ( cd "$repo_root" && ./scripts/eth2qs.sh stats  --json ) > "$tmp_dir/stats.json"  2>&1 || true

  local alive="down"
  if bakeoff_services_alive; then alive="up"; fi

  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg alive "$alive" \
    --rawfile disk "$tmp_dir/disk.tsv" \
    --rawfile execution "$tmp_dir/execution-sync.json" \
    --rawfile beacon "$tmp_dir/beacon-sync.json" \
    --rawfile processes "$tmp_dir/processes.json" \
    --rawfile doctor "$tmp_dir/doctor.json" \
    --rawfile stats "$tmp_dir/stats.json" \
    '{
      timestamp_utc: $ts,
      services_alive: $alive,
      disk_tsv: $disk,
      execution_sync: (($execution | fromjson?) // {raw: $execution}),
      beacon_sync: (($beacon | fromjson?) // {raw: $beacon}),
      processes: (($processes | fromjson?) // []),
      doctor: (($doctor | fromjson?) // {raw: $doctor}),
      stats: (($stats | fromjson?) // {raw: $stats})
    }' >> "$out_dir/samples.jsonl"
}
```

- [ ] **Step 2: Create `test/bakeoff/test_data_dirs_sync.sh`** with exactly this content:

```bash
#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/test/bakeoff/lib.sh"

# Extract the $HOME/... entries from purge_ethereum_data.sh DATA_DIRS block.
purge_list="$(awk '/^DATA_DIRS=\(/{f=1;next} /^\)/{f=0} f' \
  "$REPO_ROOT/install/utils/purge_ethereum_data.sh" \
  | grep -oE '\$HOME[^"]*' | sort -u)"
lib_list="$(printf '%s\n' "${BAKEOFF_DATA_DIRS[@]}" \
  | sed "s#$HOME#\$HOME#" | grep -E '^\$HOME' | sort -u)"

if [[ "$purge_list" == "$lib_list" ]]; then
  echo "PASS: BAKEOFF_DATA_DIRS matches purge_ethereum_data.sh DATA_DIRS"
else
  echo "FAIL: data-dir drift detected" >&2
  diff <(echo "$purge_list") <(echo "$lib_list") || true
  exit 1
fi
```

- [ ] **Step 3: Run the sync test (must pass)**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
chmod +x test/bakeoff/test_data_dirs_sync.sh
bash test/bakeoff/test_data_dirs_sync.sh
```
Expected: `PASS: BAKEOFF_DATA_DIRS matches purge_ethereum_data.sh DATA_DIRS`. If FAIL, reconcile `BAKEOFF_DATA_DIRS` with the purge script.

- [ ] **Step 4: Shellcheck both files**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 test/bakeoff/lib.sh test/bakeoff/test_data_dirs_sync.sh && echo "shellcheck OK"
```
Expected: `shellcheck OK`.

- [ ] **Step 5: Commit**

```bash
git add test/bakeoff/lib.sh test/bakeoff/test_data_dirs_sync.sh
git commit -m "feat(bakeoff): add shared probe/sample library with data-dir drift test"
```

---

## Task 3: Runtime resource caps

**Files:**
- Create: `test/bakeoff/apply_resource_caps.sh`

**Interfaces:**
- Produces: CLI `apply_resource_caps.sh <apply|clear>`. `apply` caps `eth1`/`cl`; `clear` reverts. Exit 0 on success; non-fatal if a unit is absent.

- [ ] **Step 1: Create `test/bakeoff/apply_resource_caps.sh`** with exactly this content:

```bash
#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"

action="${1:?usage: apply_resource_caps.sh <apply|clear>}"

cap_unit() {
  local unit="$1"; shift
  if ! systemctl cat "$unit" >/dev/null 2>&1; then
    log_warn "Unit $unit not present; skipping caps"
    return 0
  fi
  sudo systemctl set-property --runtime "$unit" "$@"
}

case "$action" in
  apply)
    log_info "Applying runtime resource caps (node stack <= 8 cores / 36G)"
    cap_unit eth1.service CPUQuota=600% MemoryMax=24G MemoryHigh=22G IOWeight=50 Nice=10
    cap_unit cl.service   CPUQuota=200% MemoryMax=12G MemoryHigh=11G IOWeight=50 Nice=10
    ;;
  clear)
    log_info "Clearing runtime resource caps"
    for unit in eth1.service cl.service; do
      if systemctl cat "$unit" >/dev/null 2>&1; then
        sudo systemctl revert "$unit" >/dev/null 2>&1 || true
      fi
    done
    ;;
  *)
    echo "Unknown action: $action (use apply|clear)" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Shellcheck + syntax**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
chmod +x test/bakeoff/apply_resource_caps.sh
bash -n test/bakeoff/apply_resource_caps.sh
shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 test/bakeoff/apply_resource_caps.sh && echo "shellcheck OK"
```
Expected: no syntax errors; `shellcheck OK`.

- [ ] **Step 3: Smoke the no-unit path (units absent is non-fatal)**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
test/bakeoff/apply_resource_caps.sh clear && echo "clear exits 0 with no units"
```
Expected: warns about missing units (if absent) and exits 0.

- [ ] **Step 4: Commit**

```bash
git add test/bakeoff/apply_resource_caps.sh
git commit -m "feat(bakeoff): add runtime systemd resource caps for eth1/cl"
```

---

## Task 4: Single-candidate runner

**Files:**
- Create: `test/bakeoff/run_candidate.sh`

**Interfaces:**
- Consumes: `lib.sh`, `apply_resource_caps.sh`, `config/bakeoff.env`.
- Produces: CLI `run_candidate.sh <execution> <consensus>`. Reads window from `ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS`, sample interval from `ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS`, install timeout from `ETH2QS_BAKEOFF_INSTALL_TIMEOUT`. Requires `ETH2QS_BAKEOFF_CONFIRMED=yes`. Writes `artifacts/client-bakeoff-2026-06-22/<el>__<cl>/` and a `.done` marker. Exits with the install return code.

- [ ] **Step 1: Create `test/bakeoff/run_candidate.sh`** with exactly this content:

```bash
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
artifact_root="$REPO_ROOT/artifacts/client-bakeoff-2026-06-22"
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

# Pre-install clean + baseline.
./scripts/eth2qs.sh clean-data --dry-run > "$out/cleanup-before-dry-run.log" 2>&1 || true
./scripts/eth2qs.sh clean-data --confirm > "$out/cleanup-before-confirm.log" 2>&1
bakeoff_snapshot_disk "$out/disk-before.tsv"
./scripts/eth2qs.sh plan   --json > "$out/plan-before.json"   2>&1 || true
./scripts/eth2qs.sh doctor --json > "$out/doctor-before.json" 2>&1 || true
./scripts/eth2qs.sh stats  --json > "$out/stats-before.json"  2>&1 || true

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
  while [[ "$(date +%s)" -lt "$end_at" ]]; do
    bakeoff_write_sample "$out" "$REPO_ROOT"
    if ! bakeoff_services_alive; then
      crashed="yes"
      log_warn "$pair: a service is no longer active during the window"
    fi
    sleep "$interval"
  done
  bakeoff_write_sample "$out" "$REPO_ROOT"
fi
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
```

- [ ] **Step 2: Shellcheck + syntax**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
chmod +x test/bakeoff/run_candidate.sh
bash -n test/bakeoff/run_candidate.sh
shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 test/bakeoff/run_candidate.sh && echo "shellcheck OK"
```
Expected: no syntax errors; `shellcheck OK`.

- [ ] **Step 3: Verify the confirm gate refuses without the env var**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
test/bakeoff/run_candidate.sh geth prysm; echo "rc=$?"
```
Expected: logs the refusal and `rc=2` (no destructive action taken because `ETH2QS_BAKEOFF_CONFIRMED` is unset).

- [ ] **Step 4: Commit**

```bash
git add test/bakeoff/run_candidate.sh
git commit -m "feat(bakeoff): add hardened single-candidate runner with caps and resume guard"
```

---

## Task 5: Orchestrator

**Files:**
- Create: `test/bakeoff/run_bakeoff.sh`

**Interfaces:**
- Consumes: `candidates.tsv`, `run_candidate.sh`, `config/bakeoff.env`.
- Produces: CLI `run_bakeoff.sh --stage=<triage|full> [--only=a__b,c__d] [--force]`. Installs `config/bakeoff.env` as `config/user_config.env` (backup/restore), sets stage windows, runs candidates sequentially and tolerantly, then restores user config. For `--stage=full` with no `--only`, default selection is candidates whose triage `install_exit_code=0`.

- [ ] **Step 1: Create `test/bakeoff/run_bakeoff.sh`** with exactly this content:

```bash
#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"

stage=""
only=""
force="no"
for arg in "$@"; do
  case "$arg" in
    --stage=*) stage="${arg#*=}" ;;
    --only=*)  only="${arg#*=}" ;;
    --force)   force="yes" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done
[[ "$stage" == "triage" || "$stage" == "full" ]] || { echo "Usage: run_bakeoff.sh --stage=triage|full [--only=a__b,...] [--force]" >&2; exit 1; }

artifact_root="$REPO_ROOT/artifacts/client-bakeoff-2026-06-22"
manifest="$REPO_ROOT/test/bakeoff/candidates.tsv"
user_cfg="$REPO_ROOT/config/user_config.env"
bake_cfg="$REPO_ROOT/config/bakeoff.env"
backup="$REPO_ROOT/config/user_config.env.bakeoff-backup"
mkdir -p "$artifact_root/preflight"

if [[ "$stage" == "triage" ]]; then
  export ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-5400}"
  export ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-120}"
else
  # Full sync-to-completion: long ceiling, coarse sampling.
  export ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-432000}"
  export ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-600}"
fi
export ETH2QS_BAKEOFF_INSTALL_TIMEOUT="${ETH2QS_BAKEOFF_INSTALL_TIMEOUT:-90m}"
[[ "$force" == "yes" ]] && export ETH2QS_BAKEOFF_FORCE=yes

# Install bake-off config overrides (restore on exit).
restore_cfg() {
  if [[ -f "$backup" ]]; then mv "$backup" "$user_cfg"; else rm -f "$user_cfg"; fi
  log_info "Restored original user_config.env"
}
trap restore_cfg EXIT
[[ -f "$user_cfg" ]] && cp "$user_cfg" "$backup"
cp "$bake_cfg" "$user_cfg"
log_info "Installed bake-off config overrides as user_config.env"

# Build candidate list.
mapfile -t all_pairs < <(awk -F'\t' 'NF>=2{print $1"__"$2}' "$manifest")
selected=()
if [[ -n "$only" ]]; then
  IFS=',' read -r -a selected <<< "$only"
elif [[ "$stage" == "full" ]]; then
  for pair in "${all_pairs[@]}"; do
    env_file="$artifact_root/$pair/env.txt"
    if [[ -f "$env_file" ]] && grep -q '^install_exit_code=0$' "$env_file"; then
      selected+=("$pair")
    fi
  done
  log_info "Full stage selecting triage-passing candidates: ${selected[*]:-none}"
else
  selected=("${all_pairs[@]}")
fi

# Run sequentially, tolerant of individual failures.
summary_log="$artifact_root/orchestrator-${stage}.log"
: > "$summary_log"
for pair in "${selected[@]}"; do
  execution="${pair%%__*}"
  consensus="${pair##*__}"
  log_info "=== [$stage] candidate: $execution + $consensus ==="
  set +e
  "$REPO_ROOT/test/bakeoff/run_candidate.sh" "$execution" "$consensus"
  rc=$?
  set -e
  echo "$pair rc=$rc" | tee -a "$summary_log"
done

log_info "Stage $stage complete. Per-candidate results in $summary_log"
"$REPO_ROOT/test/bakeoff/summarize.sh" || log_warn "summarize.sh reported an issue"
```

- [ ] **Step 2: Shellcheck + syntax**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
chmod +x test/bakeoff/run_bakeoff.sh
bash -n test/bakeoff/run_bakeoff.sh
shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 test/bakeoff/run_bakeoff.sh && echo "shellcheck OK"
```
Expected: no syntax errors; `shellcheck OK`. (`summarize.sh` is created in Task 6; shellcheck does not execute it.)

- [ ] **Step 3: Verify arg parsing rejects a bad stage**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
test/bakeoff/run_bakeoff.sh --stage=bogus; echo "rc=$?"
```
Expected: usage error and `rc=1`; no config files touched.

- [ ] **Step 4: Commit**

```bash
git add test/bakeoff/run_bakeoff.sh
git commit -m "feat(bakeoff): add resumable sequential orchestrator with config override management"
```

---

## Task 6: Summarizer + committed results doc

**Files:**
- Create: `test/bakeoff/summarize.sh`

**Interfaces:**
- Consumes: per-candidate artifact dirs.
- Produces: `artifacts/client-bakeoff-2026-06-22/summary.csv`, `process-summary.csv`, `report.md` (gitignored) and the committed `docs/CLIENT_BAKEOFF_RESULTS.md`.

- [ ] **Step 1: Create `test/bakeoff/summarize.sh`** with exactly this content:

```bash
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
    install_code="$(grep -E '^install_exit_code=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)"
    crash="$(grep -E '^service_crash_observed=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)"
    sample_count="$(wc -l < "$dir/samples.jsonl" 2>/dev/null || echo 0)"
    last_doctor="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.doctor.summary.status // "unknown"' 2>/dev/null || echo unknown)"
    last_disk="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.disk_tsv' 2>/dev/null | awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {s+=$2} END{print s+0}')"
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
```

- [ ] **Step 2: Shellcheck + syntax**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
chmod +x test/bakeoff/summarize.sh
bash -n test/bakeoff/summarize.sh
shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 test/bakeoff/summarize.sh && echo "shellcheck OK"
```
Expected: no syntax errors; `shellcheck OK`.

- [ ] **Step 3: Smoke with a synthetic candidate dir**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
mkdir -p artifacts/client-bakeoff-2026-06-22/geth__prysm
printf 'install_exit_code=0\nservice_crash_observed=no\n' > artifacts/client-bakeoff-2026-06-22/geth__prysm/env.txt
printf 'path\tbytes\thuman\n' > artifacts/client-bakeoff-2026-06-22/geth__prysm/disk-after-cleanup.tsv
echo '{"doctor":{"summary":{"status":"ok"}},"disk_tsv":"path\tbytes\thuman\n","processes":[]}' > artifacts/client-bakeoff-2026-06-22/geth__prysm/samples.jsonl
printf '# x Findings\n' > artifacts/client-bakeoff-2026-06-22/geth__prysm/findings.md
test/bakeoff/summarize.sh
head -3 artifacts/client-bakeoff-2026-06-22/summary.csv
test -f docs/CLIENT_BAKEOFF_RESULTS.md && echo "results doc written"
# clean the synthetic fixture so it does not pollute a real run
rm -rf artifacts/client-bakeoff-2026-06-22/geth__prysm
```
Expected: `summary.csv` has a header + one `geth__prysm` row; `results doc written`.

- [ ] **Step 4: Commit**

```bash
git add test/bakeoff/summarize.sh docs/CLIENT_BAKEOFF_RESULTS.md
git commit -m "feat(bakeoff): add summarizer and committed results doc synthesized from artifacts"
```

---

## Task 7: Harness self-test gate (pre-live)

**Files:**
- Read: all of `test/bakeoff/`

- [ ] **Step 1: Full shellcheck + syntax sweep of the harness**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
find test/bakeoff -name '*.sh' -exec bash -n {} \;
find test/bakeoff -name '*.sh' -exec shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 {} \; && echo "harness shellcheck clean"
bash test/bakeoff/test_data_dirs_sync.sh
```
Expected: no syntax errors; `harness shellcheck clean`; data-dir sync PASS.

- [ ] **Step 2: Confirm gates fire without confirmation**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
test/bakeoff/run_candidate.sh geth prysm; echo "rc=$?"   # expect rc=2
```
Expected: refusal + `rc=2`. **STOP. Hand off to the orchestrator for review before any live run.**

---

## Task 8: Live Stage A — triage (orchestrator-gated)

**Files:**
- Output: `artifacts/client-bakeoff-2026-06-22/<el>__<cl>/` for all 12 candidates

- [ ] **Step 1: Preflight baseline**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
{
  echo "started_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo_commit=$(git rev-parse HEAD)"
  whoami; uname -a; df -h /; free -h; nproc
  ./scripts/eth2qs.sh client-options --json
} | tee artifacts/client-bakeoff-2026-06-22/preflight/baseline.txt
```
Expected: baseline captured.

- [ ] **Step 2: Run the triage stage (only after operator confirms a non-production host)**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes test/bakeoff/run_bakeoff.sh --stage=triage
```
Expected: all 12 candidate dirs populated; `summary.csv`, `report.md`, and `docs/CLIENT_BAKEOFF_RESULTS.md` written. Individual candidate failures are tolerated and recorded.

- [ ] **Step 3: Write the host-contention verdict**

Append to `docs/CLIENT_BAKEOFF_RESULTS.md` a "Host contention (triage)" section: peak RSS/CPU per client from `process-summary.csv` + `samples.jsonl`, whether caps held, and recommended safe settings for Stage B. **STOP. Hand to orchestrator to review triage before Stage B.**

---

## Task 9: Live Stage B — full sync (orchestrator-gated)

**Files:**
- Output: extended `samples.jsonl` + final disk for promoted candidates

- [ ] **Step 1: Run full stage for triage-passing candidates**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_FORCE=yes ETH2QS_BAKEOFF_CONFIRMED=yes test/bakeoff/run_bakeoff.sh --stage=full
```
Expected: each promoted candidate runs to synced or the wall-clock ceiling; final synced disk footprint recorded in its last `samples.jsonl` line.

- [ ] **Step 2: Regenerate summaries**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
test/bakeoff/summarize.sh
```
Expected: refreshed `summary.csv` and `docs/CLIENT_BAKEOFF_RESULTS.md`.

---

## Task 10: Finalize committed results

**Files:**
- Modify: `docs/CLIENT_BAKEOFF_RESULTS.md`

- [ ] **Step 1: Fill recommendation + final disk + changes**

Edit `docs/CLIENT_BAKEOFF_RESULTS.md`: complete the Recommendation, Final synced disk footprint, and Changes sections from the artifacts and any repo fixes landed.

- [ ] **Step 2: Verify completeness**

Run:
```bash
cd /home/agents/workspace/eth2-quickstart
grep -q "Recommended execution client:" docs/CLIENT_BAKEOFF_RESULTS.md
! grep -q "TBD-by-reviewer\|<!-- Reviewer" docs/CLIENT_BAKEOFF_RESULTS.md && echo "no placeholders left"
```
Expected: `no placeholders left`.

- [ ] **Step 3: Commit**

```bash
git add docs/CLIENT_BAKEOFF_RESULTS.md
git commit -m "docs(bakeoff): record client bake-off results and recommendation"
```

## Safety Notes

- Not a production validator host; destructive cleanup gated by `ETH2QS_BAKEOFF_CONFIRMED=yes`.
- `clean-data --confirm` purges default chain data but preserves secrets and validator material.
- `--mev=none` throughout; no validator keys generated.
- Resource caps protect co-resident agents; never run two candidates concurrently.
- Stage B may take days; the runner is resumable via the `.done` marker.
