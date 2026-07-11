# Eth2 Client Bake-off Metrics — Design Spec

**Date:** 2026-06-22
**Status:** Approved (pending spec review)
**Supersedes:** `docs/superpowers/plans/2026-06-22-eth2-client-bakeoff-metrics.md` (Codex first draft)

## Goal

Produce a real-host bake-off that exercises every supported execution client and
every supported consensus client, then recommends the best stack using evidence:
install success, sync progress, **final synced disk footprint**, CPU, memory, health,
and required-fix findings. The bake-off must run on a **shared agent host** without
starving the co-resident agents.

## Background / Why this revision

Codex produced a technically sound first draft. Its CLI calls (`phase2 --execution=
--consensus= --mev=none`, `clean-data --dry-run/--confirm`, `doctor/stats/debug/
monitor/plan --json`, `client-options --json`), flag parsing, and hardcoded data-dir
paths all match the real repo (verified against `scripts/eth2qs.sh`, `run_2.sh`,
`install/utils/purge_ethereum_data.sh`). This revision keeps that foundation and
fixes five weaknesses:

1. **Blame attribution.** The 7 arbitrary pairs cannot tell whether the EL or the CL
   caused a failure.
2. **Sync realism.** A single 6h window never reaches synced; the user wants the
   *final synced disk footprint*, which takes hours-to-days per client.
3. **Host coexistence.** The draft has no resource governance; default caches are
   aggressive (`GETH_CACHE=8192`, most ELs 8 GB, `MAX_PEERS=100`) and would fight the
   other agents on this host.
4. **Throwaway tooling.** The runner is written into gitignored `artifacts/`.
5. **No durable record.** Nothing tracked in the repo survives the gitignored run.

## Host facts (verified 2026-06-22)

- systemd 255 as PID 1; passwordless sudo available.
- 12 cores, 62 GiB RAM (~39 GiB free at check time), 2.8 TB disk (2.5 TB free).
- Checkpoint sync already supported repo-wide (per-client `*_CHECKPOINT_URL` in
  `exports.sh`, referenced by every consensus installer) → CL syncs in minutes.
- Service unit names: `eth1.service`, `cl.service` (and `validator.service`).
- `create_systemd_service()` does **not** set resource limits inline → caps applied
  post-install via `systemctl set-property --runtime`.
- `artifacts/` is gitignored; `docs/superpowers/` is untracked scratch.

## Architecture

### Coverage — baseline-anchored matrix (12 unique candidates)

Hold a known-good partner fixed so a failure isolates the variable client.

- **EL sweep** (CL fixed = `prysm`): geth, besu, erigon, nethermind, nimbus_eth1,
  reth, ethrex — 7 runs.
- **CL sweep** (EL fixed = `geth`): prysm, lighthouse, teku, nimbus, lodestar,
  grandine — 6 runs.
- `geth__prysm` is the shared anchor (run once) → **12 unique candidates**.

Attribution rule: in the EL sweep prysm is proven, so a failure implicates the EL;
in the CL sweep geth is proven, so a failure implicates the CL. `--mev=none`
throughout.

### Two-stage execution

- **Stage A — Triage** (cheap, all 12). Per candidate: clean → install (timeout
  90m) → ~60–90m observation with checkpoint sync on. Captures install/service
  health, early EL snap-sync progress, and **resource appetite** (peak CPU/RSS/IO).
  Produces a triage report with a **host-contention verdict** and per-client cap
  recommendations. Builder pauses here for orchestrator review.
- **Stage B — Full sync-to-completion** (viable candidates only). Runs until the EL
  reaches synced or a hard wall-clock ceiling, measuring **time-to-synced** and
  **final synced disk footprint** per client. Multi-day; must be resumable.

### Resource governance (first-class)

- **Strictly sequential** — never two candidates installing/syncing at once.
- **Runtime systemd caps** on `eth1`/`cl` after install, before the window:
  node stack limited to ~8 of 12 cores and ~36 GiB total, leaving ~4 cores + ~20 GiB
  for agents. Mechanism: `sudo systemctl set-property --runtime eth1.service
  CPUQuota=… MemoryMax=… IOWeight=… Nice=…` (and same for `cl.service`). `--runtime`
  so caps evaporate on reboot.
- **Bake-off config override** `config/bakeoff.env` (layered via the existing
  `user_config.env` mechanism): caches down (8192→~3072), `MAX_PEERS` down (100→~50),
  checkpoint sync on. "Faster within reason" without starving agents.
- Orchestrator watches host load (Monitor) during runs and flags contention.

### Harness — committed, reusable tooling

Lives under `test/bakeoff/` (committed, shellcheck-clean, sources `exports.sh` +
`lib/common_functions.sh` per repo conventions). Artifacts go to gitignored
`artifacts/client-bakeoff-2026-06-22/`.

| File | Purpose |
|------|---------|
| `test/bakeoff/candidates.tsv` | 12-candidate baseline-anchored manifest (stage, execution, consensus). |
| `test/bakeoff/lib.sh` | Shared probes, disk snapshot (sourcing canonical `DATA_DIRS` from `purge_ethereum_data.sh`, not duplicated), JSONL sampling, crash detection. |
| `test/bakeoff/apply_resource_caps.sh` | Apply/clear runtime systemd caps on `eth1`/`cl`. |
| `test/bakeoff/run_candidate.sh` | Hardened single-candidate runner: clean → install → caps → checkpoint sync → sampled observation → logs/health → cleanup. Resume guard skips completed candidates. |
| `test/bakeoff/run_bakeoff.sh` | Orchestrator over the manifest; `--stage=triage|full`; sequential; resumable; tolerant of one failure. |
| `test/bakeoff/summarize.sh` | Builds `summary.csv`, resource summary, and the gitignored `report.md`; also synthesizes the committed results doc. |
| `config/bakeoff.env` | Cache/peer/checkpoint overrides for the run. |

### Artifacts layout (gitignored)

```
artifacts/client-bakeoff-2026-06-22/
  preflight/                 baseline host + repo state, operator confirmation
  <el>__<cl>/                per-candidate: env.txt, install.log, install-time.txt,
                             doctor/stats/monitor/debug-*.json, samples.jsonl,
                             service-status.txt, journal-*.log, repair-preview.txt,
                             disk-before/after-cleanup.tsv, findings.md
  summary.csv, process-summary.csv, report.md
```

### Durable committed record

Synthesized from the final artifacts (not the gitignored copy): a tracked
**`docs/CLIENT_BAKEOFF_RESULTS.md`** containing the recommendation, a results table
(install/sync/CPU/mem/**final synced disk**), per-candidate verdicts, and a
**Changes** section listing any repo fixes the bake-off drove (client install fixes,
config tuning landed). This is the record that survives in the repo.

## Workflow — orchestrator vs Builder

- **Orchestrator (this session, Claude):** writes spec + plan; spawns the persistent
  Builder; 3-pass reviews the harness *before* any live run; reviews triage report +
  contention verdict; approves Stage B promotion; Monitors host load; reviews the
  final `docs/CLIENT_BAKEOFF_RESULTS.md`.
- **Builder (spawned persistent session):** implements the 6 harness files
  (shellcheck-clean) → runs Stage A triage → writes triage report + contention
  verdict → **pauses** for review → runs Stage B full sync (resumable, multi-day) →
  synthesizes `docs/CLIENT_BAKEOFF_RESULTS.md` from artifacts.

## Success criteria

- Harness is committed, shellcheck-clean, and passes `bash -n`.
- Stage A produces all 12 candidate dirs + triage report + contention verdict.
- A candidate is **recommended** if: install exits 0; `eth1`+`cl` stay active through
  the window; EL sync progresses (or reaches synced); disk growth is explainable;
  CPU/mem stay within caps; no manual fixes beyond documented `repair` actions.
- **viable-with-fixes** if it mostly works but needs a bounded, log-backed repo change.
- **not-viable** if install fails before services exist, services crashloop, sync
  never progresses with a persistent blocker, or cleanup can't restore a clean host.
- Stage B records time-to-synced and final synced disk footprint for promoted
  candidates.
- `docs/CLIENT_BAKEOFF_RESULTS.md` is committed and synthesized from real artifacts.

## Safety

- Not a production validator host; human-gated destructive cleanup
  (`ETH2QS_BAKEOFF_CONFIRMED=yes`); no validator keys generated; `--mev=none`
  throughout; resource caps protect co-resident agents; `clean-data` preserves
  secrets and validator material.

## Non-goals

- Full 42-pair Cartesian matrix.
- MEV benchmarking.
- Archive-node or multi-region comparisons.
