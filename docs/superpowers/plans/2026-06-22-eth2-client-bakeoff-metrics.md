# Eth2 Client Bakeoff Metrics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a builder-ready real-host bakeoff that tests every supported execution client once and every supported consensus/beacon client at least once, then recommends the best stack using disk, sync, CPU, memory, health, and fix-required evidence.

**Architecture:** Use the repo's eth2-quickstart skill contract and canonical `./scripts/eth2qs.sh` lifecycle commands. Run a minimal coverage matrix instead of the full 42-pair Cartesian matrix: 7 candidate runs cover all 7 execution clients and all 6 consensus clients. Each candidate starts from cleaned default node data, installs through `phase2`, observes sync/resource metrics for a bounded window, captures health/debug/log artifacts, records required fixes, then cleans data before the next candidate.

**Tech Stack:** Bash, systemd, `./scripts/eth2qs.sh`, `doctor --json`, `stats --json`, `debug --json`, `monitor export --json`, `repair`, JSON-RPC, Beacon REST API, `curl`, `jq`, `du`, `df`, `ps`, `journalctl`, `/usr/bin/time`.

---

## Direct Answer: Are All Clients Tested?

The previous draft did **not** test all eth1/eth2 clients. It tested:

- `geth` + `prysm`
- `nimbus_eth1` + `nimbus`
- optional `reth` + `lighthouse`

This revised handoff tests **every supported execution client once** and **every supported consensus/beacon client at least once**, without testing every possible pair.

Supported clients from `./scripts/eth2qs.sh client-options --json`:

- Execution / eth1 clients: `besu`, `erigon`, `ethrex`, `geth`, `nethermind`, `nimbus_eth1`, `reth`
- Consensus / eth2 / beacon clients: `grandine`, `lighthouse`, `lodestar`, `nimbus`, `prysm`, `teku`

## Candidate Pairing Plan

Run these 7 candidates in order:

| Order | Execution Client | Consensus Client | Why This Pair Exists |
| --- | --- | --- | --- |
| 1 | `geth` | `prysm` | Baseline/default-tested stack; establishes a known-good reference. |
| 2 | `nimbus_eth1` | `nimbus` | Lightweight Nimbus-on-Nimbus candidate. |
| 3 | `reth` | `lighthouse` | Modern Rust EL with common high-performance Rust CL. |
| 4 | `besu` | `teku` | ConsenSys/Java enterprise stack. |
| 5 | `nethermind` | `lodestar` | .NET EL with TypeScript CL. |
| 6 | `erigon` | `grandine` | Performance-oriented EL with Grandine CL. |
| 7 | `ethrex` | `prysm` | Covers Ethrex; repeats Prysm because there are 7 ELs and 6 CLs. |

Do **not** run MEV for this bakeoff. Use `--mev=none` for every candidate.

## What We Measure

Each candidate must answer these questions:

- **Works:** Does `phase2` install exit cleanly? Do `eth1` and `cl` services stay active?
- **Sync speed:** How quickly does the execution client advance according to `eth_syncing`? How quickly does the beacon node advance according to `/eth/v1/node/syncing`?
- **Disk footprint:** How many bytes are used by the relevant data directories before install, after install, at every sample, and after cleanup?
- **CPU:** What sustained and peak `%CPU` do the client processes consume during the observation window?
- **Memory:** What sustained and peak RSS/VSZ do the client processes consume during the observation window?
- **Health:** What do `doctor --json`, `stats --json`, `monitor export --json`, and `debug --json` report?
- **Logs:** What errors or warnings appear in `journalctl -u eth1` and `journalctl -u cl`?
- **Fixes required:** Did the stack need repo changes, manual service edits, repair actions, different ports, extra dependencies, or unsupported workarounds?
- **Cleanup quality:** Did `clean-data --confirm` remove default data and leave the host ready for the next candidate?

## Time Budget

Full mainnet sync may take many hours or days. This bakeoff is a first-pass decision tool, not a full archive-quality sync benchmark.

Recommended default:

- Install timeout: `90m` per candidate.
- Observation window: `6h` per candidate.
- Sample interval: `5m`.
- Cleanup window: `15m` per candidate.
- Total expected wall time: about 2 days for all 7 candidates.

For a faster triage pass:

- Observation window: `90m`.
- Sample interval: `2m`.
- Promote only the top 2 candidates to the full 6h window.

## Credit-Light Supervision Model

Do not keep an AI agent in the loop during each sync window. The runner writes durable artifacts while the node runs unattended.

Use agents only at these points:

- Before execution: review the plan and generated runner.
- After each candidate: inspect `env.txt`, `doctor-after-install.json`, the final line of `samples.jsonl`, `repair-preview.txt`, and `findings.md`.
- On failure: inspect only the relevant `install.log`, `debug-*.json`, and last 200-700 journal lines.
- After triage: summarize `summary.csv`, classify candidates, and decide which 2-3 deserve a longer run.

Recommended low-credit first pass:

```bash
export ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS=5400
export ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS=120
export ETH2QS_BAKEOFF_INSTALL_TIMEOUT=90m
```

Then run the 6h window only for the top candidates.

Use these environment variables:

```bash
export ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS=21600
export ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS=300
export ETH2QS_BAKEOFF_INSTALL_TIMEOUT=90m
```

## Artifact Layout

Write all outputs under:

```text
artifacts/client-bakeoff-2026-06-22/
```

Directory structure:

```text
artifacts/client-bakeoff-2026-06-22/
  README.md
  preflight/
  geth__prysm/
  nimbus_eth1__nimbus/
  reth__lighthouse/
  besu__teku/
  nethermind__lodestar/
  erigon__grandine/
  ethrex__prysm/
  summary.csv
  report.md
```

Each candidate directory must contain:

```text
env.txt
plan-before.json
doctor-before.json
stats-before.json
disk-before.tsv
cleanup-before-dry-run.log
cleanup-before-confirm.log
install.log
install-time.txt
doctor-after-install.json
stats-after-install.json
monitor-after-install.json
debug-eth1-after-install.json
debug-cl-after-install.json
samples.jsonl
service-status.txt
journal-eth1.log
journal-cl.log
journal-validator.log
repair-preview.txt
cleanup-dry-run.log
cleanup-confirm.log
disk-after-cleanup.tsv
findings.md
```

## Success Criteria

A candidate is **recommended** only if:

- `phase2` exits `0`.
- `eth1` and `cl` remain active through the observation window.
- Execution sync and beacon sync are reachable and show progress, or the node reaches synced state.
- Disk growth is explainable from client data paths.
- CPU and memory stay within the server's practical limits.
- No manual fixes are required beyond documented `eth2qs.sh` repair actions.

A candidate is **viable with fixes** if:

- It mostly works, but one or more repo changes are needed.
- The required fix can be described as a bounded task with logs and commands proving the failure.

A candidate is **not viable** if:

- Install fails before services are created.
- Services repeatedly fail or cannot expose required APIs.
- Sync does not progress during the observation window and logs show a persistent blocker.
- Cleanup cannot return the host to a clean state.

## Task 1: Preflight The Server

**Files:**
- Read: `/home/agents/workspace/eth2-quickstart/skills/eth2-quickstart/SKILL.md`
- Read: `/home/agents/workspace/eth2-quickstart/skills/eth2-quickstart/references/operator.md`
- Read: `/home/agents/workspace/eth2-quickstart/skills/eth2-quickstart/references/safety.md`
- Read: `/home/agents/workspace/eth2-quickstart/skills/eth2-quickstart/references/outputs.md`
- Read: `/home/agents/workspace/eth2-quickstart/skills/eth2-quickstart/references/sizing.md`
- Output: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/preflight/`

- [ ] **Step 1: Create artifact root**

```bash
cd /home/agents/workspace/eth2-quickstart
mkdir -p artifacts/client-bakeoff-2026-06-22/preflight
cat > artifacts/client-bakeoff-2026-06-22/README.md <<'EOF'
# Eth2 Client Bakeoff Artifacts

This directory contains real-host client bakeoff artifacts. Each candidate was installed through `./scripts/eth2qs.sh phase2`, observed for sync/resource metrics, and cleaned with `./scripts/eth2qs.sh clean-data` before the next candidate.
EOF
```

Expected: artifact root exists and documents the run purpose.

- [ ] **Step 2: Record host and repo baseline**

```bash
cd /home/agents/workspace/eth2-quickstart
{
  echo "started_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "repo_commit=$(git rev-parse HEAD)"
  echo "repo_status_begin"
  git status --short
  echo "repo_status_end"
  echo "whoami=$(whoami)"
  uname -a
  df -h /
  df -B1 /
  free -h
  nproc
  ./scripts/eth2qs.sh client-options --json
} | tee artifacts/client-bakeoff-2026-06-22/preflight/baseline.txt
```

Expected: baseline includes all supported clients and enough host sizing data to judge viability.

- [ ] **Step 3: Run planner and read-only health checks**

```bash
cd /home/agents/workspace/eth2-quickstart
./scripts/eth2qs.sh plan --json > artifacts/client-bakeoff-2026-06-22/preflight/plan-before.json 2>&1 || true
./scripts/eth2qs.sh doctor --json > artifacts/client-bakeoff-2026-06-22/preflight/doctor-before.json 2>&1 || true
./scripts/eth2qs.sh stats --json > artifacts/client-bakeoff-2026-06-22/preflight/stats-before.json 2>&1 || true
./scripts/eth2qs.sh monitor export --json > artifacts/client-bakeoff-2026-06-22/preflight/monitor-before.json 2>&1 || true
```

Expected: all four files exist. Any pre-existing failing health checks are reviewed before installs begin.

- [ ] **Step 4: Preview cleanup scope**

```bash
cd /home/agents/workspace/eth2-quickstart
./scripts/eth2qs.sh clean-data --dry-run > artifacts/client-bakeoff-2026-06-22/preflight/clean-data-dry-run.log 2>&1 || true
```

Expected: dry-run output states default data directories only and preserves secrets, validator keystores, wallets, and `~/secrets`.

- [ ] **Step 5: Human gate**

Do not proceed until the operator confirms:

- This is not a production validator host.
- Default Ethereum data directories may be deleted between candidate runs.
- The network and disk usage from repeated sync attempts is acceptable.
- `sudo` service management is acceptable for this run.

Expected: the confirmation is recorded in `artifacts/client-bakeoff-2026-06-22/preflight/operator-confirmation.txt`.

## Task 2: Create The Bakeoff Runner

**Files:**
- Create: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/run_candidate.sh`

- [ ] **Step 1: Write the candidate runner**

```bash
cd /home/agents/workspace/eth2-quickstart
cat > artifacts/client-bakeoff-2026-06-22/run_candidate.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

execution="${1:?usage: run_candidate.sh <execution> <consensus>}"
consensus="${2:?usage: run_candidate.sh <execution> <consensus>}"
repo_root="/home/agents/workspace/eth2-quickstart"
artifact_root="$repo_root/artifacts/client-bakeoff-2026-06-22"
pair="${execution}__${consensus}"
out="$artifact_root/$pair"
window="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-21600}"
interval="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-300}"
install_timeout="${ETH2QS_BAKEOFF_INSTALL_TIMEOUT:-90m}"

cd "$repo_root"
mkdir -p "$out/tmp"

if [[ "${ETH2QS_BAKEOFF_CONFIRMED:-}" != "yes" ]]; then
  {
    echo "Refusing to run destructive bakeoff cleanup."
    echo "Set ETH2QS_BAKEOFF_CONFIRMED=yes only after the operator confirms this is not a production validator host and default Ethereum data may be deleted."
  } >&2
  exit 2
fi

snapshot_disk() {
  {
    echo -e "path\tbytes\thuman"
    for path in \
      "$HOME/.ethereum" \
      "$HOME/.local/share/nethermind" \
      "$HOME/.local/share/besu" \
      "$HOME/.local/share/erigon" \
      "$HOME/.local/share/reth" \
      "$HOME/.local/share/nimbus-eth1" \
      "$HOME/ethrex/data" \
      "$HOME/.local/share/prysm" \
      "$HOME/.lighthouse" \
      "$HOME/.local/share/teku" \
      "$HOME/.local/share/nimbus" \
      "$HOME/.local/share/lodestar" \
      "$HOME/.local/share/grandine"; do
      if [[ -e "$path" ]]; then
        bytes="$(du -sb "$path" 2>/dev/null | awk '{print $1}')"
        human="$(du -sh "$path" 2>/dev/null | awk '{print $1}')"
        echo -e "$path\t${bytes:-0}\t${human:-0}"
      fi
    done
    df -B1 / | awk 'NR==2{print "filesystem:/\tused_bytes="$3"\tavailable_bytes="$4}'
  }
}

snapshot_processes_json() {
  ps -eo pid=,comm=,%cpu=,%mem=,rss=,vsz=,etime=,args= \
    | awk '/geth|erigon|reth|Nethermind|besu|ethrex|nimbus|prysm|beacon-chain|lighthouse|teku|lodestar|grandine/ {print}' \
    | jq -R -s 'split("\n")[:-1]'
}

probe_execution_sync_json() {
  curl -sS --max-time 5 \
    -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    http://127.0.0.1:8545 \
    || printf '{"error":"execution_rpc_unavailable"}'
}

probe_beacon_sync_json() {
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

write_metric_sample() {
  local tmp_dir="$out/tmp"
  snapshot_disk > "$tmp_dir/disk.tsv"
  probe_execution_sync_json > "$tmp_dir/execution-sync.json" || true
  probe_beacon_sync_json > "$tmp_dir/beacon-sync.json" || true
  snapshot_processes_json > "$tmp_dir/processes.json" || true
  ./scripts/eth2qs.sh doctor --json > "$tmp_dir/doctor.json" 2>&1 || true
  ./scripts/eth2qs.sh stats --json > "$tmp_dir/stats.json" 2>&1 || true

  jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --rawfile disk "$tmp_dir/disk.tsv" \
    --rawfile execution "$tmp_dir/execution-sync.json" \
    --rawfile beacon "$tmp_dir/beacon-sync.json" \
    --rawfile processes "$tmp_dir/processes.json" \
    --rawfile doctor "$tmp_dir/doctor.json" \
    --rawfile stats "$tmp_dir/stats.json" \
    '{
      timestamp_utc: $ts,
      disk_tsv: $disk,
      execution_sync: (($execution | fromjson?) // {raw: $execution}),
      beacon_sync: (($beacon | fromjson?) // {raw: $beacon}),
      processes: (($processes | fromjson?) // []),
      doctor: (($doctor | fromjson?) // {raw: $doctor}),
      stats: (($stats | fromjson?) // {raw: $stats})
    }' >> "$out/samples.jsonl"
}

{
  echo "execution=$execution"
  echo "consensus=$consensus"
  echo "mev=none"
  echo "started_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "sync_window_seconds=$window"
  echo "sample_interval_seconds=$interval"
  echo "install_timeout=$install_timeout"
} > "$out/env.txt"

./scripts/eth2qs.sh clean-data --dry-run > "$out/cleanup-before-dry-run.log" 2>&1 || true
./scripts/eth2qs.sh clean-data --confirm > "$out/cleanup-before-confirm.log" 2>&1
snapshot_disk > "$out/disk-before.tsv"
./scripts/eth2qs.sh plan --json > "$out/plan-before.json" 2>&1 || true
./scripts/eth2qs.sh doctor --json > "$out/doctor-before.json" 2>&1 || true
./scripts/eth2qs.sh stats --json > "$out/stats-before.json" 2>&1 || true

set +e
timeout "$install_timeout" /usr/bin/time -v -o "$out/install-time.txt" \
  ./scripts/eth2qs.sh phase2 --execution="$execution" --consensus="$consensus" --mev=none \
  > "$out/install.log" 2>&1
install_rc=$?
set -e
echo "install_exit_code=$install_rc" >> "$out/env.txt"

./scripts/eth2qs.sh doctor --json > "$out/doctor-after-install.json" 2>&1 || true
./scripts/eth2qs.sh stats --json > "$out/stats-after-install.json" 2>&1 || true
./scripts/eth2qs.sh monitor export --json > "$out/monitor-after-install.json" 2>&1 || true
./scripts/eth2qs.sh debug --json --service eth1 > "$out/debug-eth1-after-install.json" 2>&1 || true
./scripts/eth2qs.sh debug --json --service cl > "$out/debug-cl-after-install.json" 2>&1 || true
systemctl status eth1 cl validator --no-pager -l > "$out/service-status.txt" 2>&1 || true

if [[ "$install_rc" -eq 0 ]]; then
  end_at=$(( $(date +%s) + window ))
  while [[ "$(date +%s)" -lt "$end_at" ]]; do
    write_metric_sample
    sleep "$interval"
  done
  write_metric_sample
fi

journalctl -u eth1 -n 700 --no-pager > "$out/journal-eth1.log" 2>&1 || true
journalctl -u cl -n 700 --no-pager > "$out/journal-cl.log" 2>&1 || true
journalctl -u validator -n 300 --no-pager > "$out/journal-validator.log" 2>&1 || true
./scripts/eth2qs.sh repair > "$out/repair-preview.txt" 2>&1 || true

{
  echo "# $execution + $consensus Findings"
  echo
  echo "Install exit code: $install_rc"
  echo
  echo "Initial classification:"
  if [[ "$install_rc" -eq 0 ]]; then
    echo "- install: pass"
  else
    echo "- install: fail"
  fi
  echo
  echo "Required fixes:"
  echo "- Review install.log, doctor-after-install.json, debug-*.json, repair-preview.txt, and journals."
} > "$out/findings.md"

./scripts/eth2qs.sh clean-data --dry-run > "$out/cleanup-dry-run.log" 2>&1 || true
./scripts/eth2qs.sh clean-data --confirm > "$out/cleanup-confirm.log" 2>&1 || true
snapshot_disk > "$out/disk-after-cleanup.tsv"
echo "ended_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$out/env.txt"
exit "$install_rc"
EOF
chmod +x artifacts/client-bakeoff-2026-06-22/run_candidate.sh
```

Expected: executable runner exists and routes lifecycle operations through `./scripts/eth2qs.sh`.

- [ ] **Step 2: Review the runner before executing**

```bash
cd /home/agents/workspace/eth2-quickstart
sed -n '1,260p' artifacts/client-bakeoff-2026-06-22/run_candidate.sh
```

Expected: reviewer confirms cleanup, install, metric sampling, log capture, repair preview, and final cleanup behavior.

## Task 3: Run The Minimal Coverage Bakeoff

**Files:**
- Execute: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/run_candidate.sh`
- Output: one candidate artifact directory per pair

- [ ] **Step 1: Run baseline `geth` + `prysm`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh geth prysm
```

Expected: `artifacts/client-bakeoff-2026-06-22/geth__prysm/` contains complete install, sample, log, and cleanup artifacts.

- [ ] **Step 2: Run lightweight `nimbus_eth1` + `nimbus`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh nimbus_eth1 nimbus
```

Expected: `artifacts/client-bakeoff-2026-06-22/nimbus_eth1__nimbus/` exists and records whether Nimbus-on-Nimbus is viable.

- [ ] **Step 3: Run `reth` + `lighthouse`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh reth lighthouse
```

Expected: `artifacts/client-bakeoff-2026-06-22/reth__lighthouse/` exists and covers the Rust candidate stack.

- [ ] **Step 4: Run `besu` + `teku`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh besu teku
```

Expected: `artifacts/client-bakeoff-2026-06-22/besu__teku/` exists and covers the ConsenSys/Java stack.

- [ ] **Step 5: Run `nethermind` + `lodestar`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh nethermind lodestar
```

Expected: `artifacts/client-bakeoff-2026-06-22/nethermind__lodestar/` exists and covers Nethermind and Lodestar.

- [ ] **Step 6: Run `erigon` + `grandine`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh erigon grandine
```

Expected: `artifacts/client-bakeoff-2026-06-22/erigon__grandine/` exists and covers Erigon and Grandine.

- [ ] **Step 7: Run `ethrex` + `prysm`**

```bash
cd /home/agents/workspace/eth2-quickstart
ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh ethrex prysm
```

Expected: `artifacts/client-bakeoff-2026-06-22/ethrex__prysm/` exists and covers Ethrex.

## Task 4: Summarize Metrics

**Files:**
- Read: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/*/samples.jsonl`
- Output: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/summary.csv`

- [ ] **Step 1: Generate machine-readable summary**

```bash
cd /home/agents/workspace/eth2-quickstart
{
  echo "pair,execution,consensus,install_exit_code,sample_count,last_doctor_status,last_execution_sync,last_beacon_sync,last_disk_bytes,cleanup_residual_bytes"
  for dir in artifacts/client-bakeoff-2026-06-22/*__*; do
    [[ -d "$dir" ]] || continue
    pair="$(basename "$dir")"
    execution="${pair%%__*}"
    consensus="${pair##*__}"
    install_code="$(grep -E '^install_exit_code=' "$dir/env.txt" 2>/dev/null | tail -1 | cut -d= -f2-)"
    sample_count="$(wc -l < "$dir/samples.jsonl" 2>/dev/null || echo 0)"
    last_doctor="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.doctor.summary.status // "unknown"' 2>/dev/null || echo unknown)"
    last_execution="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -c '.execution_sync' 2>/dev/null | tr ',' ';' || echo null)"
    last_beacon="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -c '.beacon_sync' 2>/dev/null | tr ',' ';' || echo null)"
    last_disk="$(tail -1 "$dir/samples.jsonl" 2>/dev/null | jq -r '.disk_tsv' 2>/dev/null | awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {sum+=$2} END{print sum+0}')"
    residual="$(awk -F'\t' 'NR>1 && $2 ~ /^[0-9]+$/ {sum+=$2} END{print sum+0}' "$dir/disk-after-cleanup.tsv" 2>/dev/null || echo 0)"
    echo "$pair,$execution,$consensus,${install_code:-missing},$sample_count,$last_doctor,$last_execution,$last_beacon,${last_disk:-0},${residual:-0}"
  done
} > artifacts/client-bakeoff-2026-06-22/summary.csv
```

Expected: `summary.csv` has one row per candidate pair.

- [ ] **Step 2: Generate CPU and memory summary**

```bash
cd /home/agents/workspace/eth2-quickstart
{
  echo "pair,process_sample_rows"
  for dir in artifacts/client-bakeoff-2026-06-22/*__*; do
    [[ -d "$dir" ]] || continue
    pair="$(basename "$dir")"
    rows="$(jq -r '.processes[]?' "$dir/samples.jsonl" 2>/dev/null | wc -l || echo 0)"
    echo "$pair,$rows"
  done
} > artifacts/client-bakeoff-2026-06-22/process-summary.csv
```

Expected: `process-summary.csv` shows whether each candidate captured process telemetry.

## Task 5: Classify Required Fixes

**Files:**
- Read: each candidate `install.log`, `doctor-after-install.json`, `debug-*.json`, `repair-preview.txt`, `journal-*.log`
- Modify: each candidate `findings.md`

- [ ] **Step 1: Classify each candidate**

For every candidate directory, update `findings.md` with:

```markdown
## Classification

- Result: recommended | viable-with-fixes | not-viable
- Install: pass | fail
- Services: pass | fail
- Execution sync: progressing | stalled | unavailable | synced
- Beacon sync: progressing | stalled | unavailable | synced
- Cleanup: pass | fail

## Evidence

- Install log:
- Doctor status:
- Execution sync evidence:
- Beacon sync evidence:
- Disk footprint:
- CPU/memory notes:
- Journal errors:

## Required Fixes

- None
```

Expected: each candidate has an evidence-backed classification.

- [ ] **Step 2: Convert recurring failures into builder tasks**

If any candidate needs fixes, create a concrete task entry in the final report:

```markdown
### Fix: geth__prysm service fails to stay active

**Symptom:** `eth1` or `cl` fails during the observation window.
**Evidence:** `artifacts/client-bakeoff-2026-06-22/geth__prysm/journal-eth1.log`, `journal-cl.log`, and `debug-*.json`.
**Likely area:** the matching script under `install/execution/` or `install/consensus/`.
**Acceptance:** rerun `ETH2QS_BAKEOFF_CONFIRMED=yes artifacts/client-bakeoff-2026-06-22/run_candidate.sh geth prysm`; install exits `0`, both services stay active, and `samples.jsonl` records sync progress.
```

Expected: every required fix is actionable for a builder and tied to artifacts.

## Task 6: Write Builder Handoff Report

**Files:**
- Read: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/summary.csv`
- Read: candidate `findings.md`
- Output: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/report.md`

- [ ] **Step 1: Write final report**

```bash
cd /home/agents/workspace/eth2-quickstart
{
  echo "# Eth2 Client Bakeoff Report"
  echo
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Coverage"
  echo
  echo "- Execution clients covered: besu, erigon, ethrex, geth, nethermind, nimbus_eth1, reth"
  echo "- Consensus clients covered: grandine, lighthouse, lodestar, nimbus, prysm, teku"
  echo "- MEV: none"
  echo
  echo "## Summary"
  echo
  column -s, -t artifacts/client-bakeoff-2026-06-22/summary.csv 2>/dev/null || cat artifacts/client-bakeoff-2026-06-22/summary.csv
  echo
  echo "## Recommendation Criteria"
  echo
  echo "- First: installs cleanly and services remain active."
  echo "- Second: execution and beacon sync progress during the observation window."
  echo "- Third: lower disk growth, sustained CPU, and RSS for comparable sync progress."
  echo "- Fourth: fewer manual fixes and cleaner repo-supported operation."
  echo
  echo "## Candidate Findings"
  echo
  for findings in artifacts/client-bakeoff-2026-06-22/*__*/findings.md; do
    echo
    echo "### $(basename "$(dirname "$findings")")"
    sed -n '1,220p' "$findings"
  done
  echo
  echo "## Builder Task List"
  echo
  echo "Populate this section with the concrete fix tasks identified in Task 5. If every candidate is classified as recommended, write: No builder fixes required."
} > artifacts/client-bakeoff-2026-06-22/report.md
```

Expected: `report.md` is complete enough for a builder to choose a client stack or pick up required fixes.

## Task 7: Final Verification

**Files:**
- Read: `/home/agents/workspace/eth2-quickstart/artifacts/client-bakeoff-2026-06-22/`

- [ ] **Step 1: Verify artifact completeness**

```bash
cd /home/agents/workspace/eth2-quickstart
for pair in geth__prysm nimbus_eth1__nimbus reth__lighthouse besu__teku nethermind__lodestar erigon__grandine ethrex__prysm; do
  test -s "artifacts/client-bakeoff-2026-06-22/$pair/env.txt"
  test -s "artifacts/client-bakeoff-2026-06-22/$pair/install.log"
  test -s "artifacts/client-bakeoff-2026-06-22/$pair/findings.md"
  test -s "artifacts/client-bakeoff-2026-06-22/$pair/cleanup-confirm.log"
done
test -s artifacts/client-bakeoff-2026-06-22/summary.csv
test -s artifacts/client-bakeoff-2026-06-22/report.md
```

Expected: command exits `0`.

- [ ] **Step 2: Verify cleanup at end**

```bash
cd /home/agents/workspace/eth2-quickstart
./scripts/eth2qs.sh clean-data --dry-run > artifacts/client-bakeoff-2026-06-22/final-clean-data-dry-run.log 2>&1 || true
./scripts/eth2qs.sh doctor --json > artifacts/client-bakeoff-2026-06-22/final-doctor.json 2>&1 || true
```

Expected: final dry-run shows no unexpected leftover default client data, or leftovers are explained in the report.

## Safety Notes

- Do not run this on a production validator host.
- Human confirmation is required before destructive cleanup.
- `./scripts/eth2qs.sh clean-data --confirm` is intended to purge default chain data while preserving secrets and validator material.
- Do not use host cleanup unless dry-run proves stale root-managed installs are interfering.
- Do not generate validator keys for this bakeoff.
- Keep `--mev=none` throughout this benchmark.
