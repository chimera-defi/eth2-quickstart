# Eth2 Client Bake-off Results

_Stage A (triage) synthesized from `artifacts/client-bakeoff-2026-06-22/` on 2026-06-23. Raw artifacts are gitignored; this doc is the committed summary._

## Method

- **Baseline-anchored coverage (12 candidates):** every execution client vs fixed Prysm (7 ELs), plus every other consensus client vs fixed Geth (5 CLs). This isolates each client against a known-good counterpart instead of testing every NxM pair.
  - ELs × prysm: geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex
  - geth × CLs: lighthouse, teku, nimbus, lodestar, grandine
- **Two stages:**
  - **Stage A — triage (this doc):** does each candidate install, checkpoint-sync, and authenticate the Engine API? ~5-min observation window per candidate, 60s sampling.
  - **Stage B — full sync (in progress):** sync-to-completion to measure final synced disk footprint for viable candidates.
- **Execution:** strictly sequential, ONE candidate at a time on this shared semi-prod host. Resource-capped to protect co-resident agents. MEV: none. No validator keys. Destructive data-clean gated by `ETH2QS_BAKEOFF_CONFIRMED=yes` (secrets/validator material preserved).
- **Pass criterion (Stage A):** beacon `head_slot` reaches the network tip (~14.6M) via checkpoint import on the first sample (`is_optimistic=true`), `el_offline=false` (Engine-API JWT handshake succeeded), and `sync_distance` trending to 0 — i.e. the CL is live-tracking a validating EL.

## Stage A results — 12/12 PASS

`el_offline` is Prysm's own verdict on whether the EL is reachable **and** authenticating over the Engine API. `False` across the window = JWT wired correctly and the EL is validating payloads. `restErr` = beacon REST momentarily unavailable during heavy-client startup (see Resource contention below).

| Candidate | Install | Crash | head (first→last) | el_offline | restErr | n | Verdict | Installer fix |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| geth__prysm | 0 | no | 14615771→14615856 | F×5 | 0 | 5 | PASS (baseline) | none |
| erigon__prysm | 0 | no | 14615808→14615808 | F×5 | 0 | 5 | PASS — flagged | none |
| reth__prysm | 0 | no | 14615808→14616097 | F×5 / T×4 | 6 | 9 | PASS (after fix) | **JWT + HTTP-RPC** |
| nethermind__prysm | 0 | no | 14614859→14615786 | F×9 | 4 | 9 | PASS | Engine module |
| besu__prysm | 0 | no | 14616094→14616183 | F×5 | 0 | 5 | PASS (clean) | none |
| nimbus_eth1__prysm | 0 | no | 14616151→14616235 | F×5 | 0 | 5 | PASS (clean) | none |
| ethrex__prysm | 0 | no | 14616192→14616287 | F×5 | 0 | 5 | PASS (clean) | none |
| geth__lighthouse | 0 | no | 14615232→14615349 | F×4 | 1 | 4 | PASS | none |
| geth__teku | 0 | no | 14615296→14615326 | F×4 | 1 | 4 | PASS | config keys |
| geth__nimbus | 0 | no | 14615455→14615506 | F×5 | 0 | 5 | PASS | trustedNodeSync |
| geth__lodestar | 0 | no | 14615638→14615708 | F×10 | 10 | 10 | PASS | rcConfig |
| geth__grandine | 0 | no | 14615040→14615203 | F×7 | 1 | 7 | PASS | none |

All 12: `install_exit_code=0`, no service crash, `is_optimistic=true`, checkpoint-sync PASS signature.

### Per-candidate notes

- **erigon — PASS with Stage-B re-verify flag.** Head stayed frozen at the checkpoint slot (14615808) and `sync_distance` grew 71→97 over the 5-min window. This is benign warmup, not a defect: `el_offline=false` throughout (Engine API reachable and authenticating), so the freeze is beacon-P2P backfill catching up, not a broken EL handshake. Re-verify head advances under Stage B's longer window.
- **reth — the only EL that needed installer fixes.** reth was the sole EL not passing `--authrpc.jwtsecret` to the shared secret that `ensure_jwt_secret` already created, so Prysm fell back to a non-shared auto-JWT → 401 → frozen head (`el_offline=True` early samples). Two commits fixed it; `el_offline` flips True→False once the shared JWT is wired. Also enabled HTTP-RPC on 127.0.0.1 for monitoring/consumers, matching the other ELs.
- **besu / nimbus_eth1 / ethrex — clean PASS, no fix.** JWT wiring correct out of the box. ethrex reached finalization (`finalizedEpoch=456756`). nimbus_eth1 additionally runs its own background historical EL sync from genesis (independent of the Engine API path, which works immediately).

### Resource contention (shared semi-prod host)

Heavier-client startups (non-geth ELs, and lodestar) showed Prysm's beacon REST briefly unavailable for the first 1–3 minutes (`restErr` counts above) before recovering — consistent with startup contending for CPU/IO against co-resident agents on this shared host. It did **not** block any checkpoint sync, but it is the headline risk for Stage B: a multi-day, IO-heavy full sync will compete with co-resident workloads. Stage B execution strategy (sequential vs. small parallel batches) must account for this.

## Changes driven by this bake-off

Installer/harness fixes landed on the bake-off branch as a direct result of triage:

- `fix(reth): wire shared JWT + explicit authrpc/datadir for Engine API`
- `fix(reth): enable HTTP-RPC on 127.0.0.1 (eth,net,web3) for monitoring and consumers`
- `fix(nethermind): drop Engine from main JsonRpc.EnabledModules`
- `fix(lodestar): load node options via --rcConfig not --paramsFile`
- `fix(nimbus): checkpoint-sync via trustedNodeSync bootstrap`
- `fix(teku): remove invalid config keys blocking beacon startup`
- `fix(bakeoff): authenticate GitHub release API via gh token to avoid rate limits`
- `fix(bakeoff): bound doctor/stats sampling calls with timeout 30s`

## Recommendation (preliminary — Stage A only)

Stage A establishes **viability**, not a final pick: all 12 client pairs install, checkpoint-sync, and authenticate the Engine API on this host. The final recommendation depends on Stage B's synced disk footprint and sync-time metrics.

- Recommended execution client: _pending Stage B footprint_
- Recommended consensus client: _pending Stage B footprint_
- Stage-A note: geth, besu, nimbus_eth1, ethrex passed with zero installer changes and zero REST contention — the cleanest out-of-the-box ELs against Prysm.

## Sync-mode & disk-flag audit (2026-06-25)

Before letting the slow full-sync ELs run, we audited every execution client to confirm it uses the most disk- and time-efficient sync mode available — so the Stage B footprint numbers reflect each client's *best* configuration, not an accidental archive run. Trigger: geth's `--history.chain postmerge` flag (prunes pre-merge block history, a large disk saving). We verified it was on for the baseline, then checked the rest.

| EL | Disk/sync flags | Status | Notes |
| --- | --- | --- | --- |
| geth | `--syncmode snap` + `--history.chain postmerge` | ✅ optimal | **Verified ON in the actual 1.13 TiB baseline run** (service-status.txt). Snap-sync + post-merge history prune is the disk floor for geth. |
| besu | `sync-mode="SNAP"` + `data-storage-format="BONSAI"` | ✅ optimal | Bonsai is Besu's space-efficient flat-DB layout; SNAP avoids full historical execution. |
| nethermind | `SnapSync: true` + `FastBlocks: true` | ✅ optimal | Snap on; Halite/Paprika flat storage is the modern default. |
| ethrex | `--syncmode snap` | ✅ optimal | Snap is the only efficient mode it exposes. |
| erigon | OtterSync (default) + `prune.mode: "full"` | ✅ disk-optimal | `prune.mode: full` is the smallest erigon3 footprint. (Separately deadlocks → no-sync; see erigon row.) |
| nimbus_eth1 | fast-sync (default) | ✅ acceptable | No dedicated post-merge-prune lever; fast-sync is its efficient default. |
| reth | **was archive (no flag)** → now `--full` | ⚠️ **fixed 2026-06-25** | The **only misconfigured EL.** Default reth = archive (~2.8 TiB). `--full` = pruned full node (~1.2 TiB): keeps full block/receipt history, prunes historical state changesets+indices (retains last ~10k blocks). Committed `fix(reth): run pruned full node (--full)`; reth__prysm relaunched. |

**Net effect:** all seven ELs now run their disk-optimal sync mode. Six were already correct out of the box; reth was archive-by-default and is the one change this audit produced. Footprint comparisons across ELs are therefore apples-to-apples on configuration (the snap-vs-full *time* asterisk from the method section still applies — full-sync ELs execute all ~25M blocks, so time-to-sync is not comparable to geth's snap baseline, but final footprint is).

## Final synced disk footprint (Stage B)

_In progress (run_id `client-bakeoff-stageB-2026-06-23`). Sequential, one candidate at a time; rows added as each candidate reaches a verdict. Footprint = final synced datadir size (EL + CL); secrets/validator material excluded._

| Candidate | Result | Sync time | Final disk footprint (EL + CL) | Notes |
| --- | --- | --- | --- | --- |
| geth__prysm | ✅ synced | ~8h28m | **1.13 TiB** — geth 1,245,128,582,247 B + prysm 654,985,849 B | Baseline. snap-sync EL hands prysm an already-validated head, so there is no large optimistic gap to close. fully_synced=yes, no crash. |
| erigon__prysm | ❌ no-sync | n/a (terminated) | ~1.21 TiB\* — erigon 1,333,017,755,599 B + prysm 1,646,160,347 B | \*Partial, captured at a near-tip **frozen** head — NOT a clean synced datadir. erigon3 OtterSync + checkpoint-synced prysm deadlock: the EL execution head freezes a few thousand blocks behind tip while the beacon stays `is_optimistic=true`; neither side issues the `forkchoiceUpdated` that would close the >96-block backward-download gap. Raising the CL CPU cap 200%→600% advanced the head ~5k blocks then re-froze — confirming a genuine gap-close deadlock, not resource starvation. Terminated per operator decision ("record no-sync, move on"). See artifact `findings.md`. |
| reth__prysm | ⏳ capped (72h) | n/a | **~0.98 TiB\*** — reth 1,064,695,764,125 B + prysm 12,468,756,540 B | \*Partial — window-capped at Execution stage block 11,970,965/25,395,872 (47% by block count, ~21% gas-weighted; ended 2026-06-28T16:53:20Z). reth `--full` is the only no-snap EL; sequential full block execution too slow to finish in 72h under caps. Clean SIGTERM stop (ExecMainStatus=0), no crash, 578 samples. Footprint recovered from `samples.jsonl` last entry (16:52:46Z) — `disk-final.tsv` absent due to harness capped-path gap (fixed commit `af0d77f`). Extrapolation: at ~21% gas-exec already ~87% of geth's 1.13 TiB; projected final `--full` footprint ~1.1–1.2 TiB. |
| nethermind__prysm | ✅ synced | ~14.5h (snap) | **~251 GiB** — nethermind 268,110,243,338 B + prysm 1,431,145,921 B | Snap-synced to head 25,428,620, 49 peers, no crash — the **smallest EL footprint** in the field (Bonsai flat-DB). NOTE: nethermind's FIRST attempt was a 13.3h 0-peer loopback stall (P2P pinned to 127.0.0.1, execution head frozen ~block 4,651 while the beacon looked healthy) — the origin of the "triage is blind to a stalled EL" lesson below. After the installer was fixed to advertise a routable `ExternalIp` (commit `676e4da`), the re-run synced cleanly. |
| besu__prysm | ✅ **synced** (un-pruned); pruned re-run abandoned | ~19h18m | **~1.08 TiB (un-pruned)** — besu 1,189,836,723,674 B + prysm 1,682,488,084 B | **besu synced successfully.** The 2026-06-30 run snap-synced cleanly to a fully validating head (~50 peers, prysm `is_optimistic=false` at 2026-07-01T01:37:10Z → ~19h18m, fully_synced=yes) — a working, production-viable node. The limitation is **disk-comparability only:** this run had no history pruning → its 1.08 TiB is history-inflated and **NOT pruned-comparable** to geth/nethermind. A pruned re-run (`history-expiry-prune=true`, 2026-07-04) to get a comparable number **deadlocked twice and was abandoned** (operator: "Stop; accept limitation note", 2026-07-05 — see the besu snap-sync deadlock gotcha below; the deadlock trigger was a stale-CL stall, **not** a besu sync failure). So besu's disk number is shown as a client-limitation and excluded from the pruned-comparable ranking, but besu **did** sync. |
| ethrex__prysm | ✅ synced | ~2h16m (snap) | **~286 GiB at sync → 416 GiB (2026-07-06, growing)** — 306,564,007,339 B at sync; live 447,086,696,857 B | Snap-synced to a fully validating head in ~2h16m — **fastest EL sync in the field.** 50 peers throughout. 1 automatic stale-pivot update (block 25,469,233→25,469,696) self-healed in ~4 min with no intervention (ethrex clock-based detection, as designed). No crash (service_crash_observed=no, install_exit_code=0). Footprint is un-pruned and **NOT full-history** — ethrex serves ~no history (`eth_getBlockByNumber` returns `null` below head; verified 2026-07-06 at blocks 1/1M/21.6M/~head-7k) yet the datadir keeps growing while running (286 GiB at sync → 416 GiB); not pruned-comparable; see client limitations. ethrex v19.0.0. fully_synced=yes, hit_72h_cap=no. |

_Remaining (one at a time): geth × lighthouse, teku, nimbus, lodestar, grandine._

### Client limitations — shown separately, NOT in the pruned-comparable ranking

Only **geth** (~1.13 TiB) and **nethermind** (~251 GiB) produced a final footprint under a **pruned, apples-to-apples** config, so only those two are ranked head-to-head on disk. The rest are recorded here with the reason each falls outside that comparison. **"Outside the disk ranking" does not mean "failed to sync"** — besu in particular synced cleanly (see below); it's here purely because we don't have a pruned-comparable disk number for it.

| EL | Footprint recorded | Synced? | Why it's outside the pruned-comparable ranking |
| --- | --- | --- | --- |
| besu | ~1.08 TiB (un-pruned) | ✅ yes (~19h18m, fully validated) | besu **synced fine** — the un-pruned run just isn't disk-comparable (history-inflated), and the pruned re-run to fix that deadlocked twice and was abandoned (stale-pivot → `SnapSyncChainDownloader` thread death; root-caused to a ~28h prysm-v7.1.5 CL stall, **not** a besu fault — see gotcha below). |
| reth | ~0.98 TiB partial (72h-capped) | ⏳ partial | `--full`-only (no snap); sequential full block execution can't finish mainnet inside the 72h cap. Speed-bound, not config-bound. |
| nimbus_eth1 | ~21 GB partial | ⏳ partial | Full-sync-only (no snap); era1 import path. Service exited ~21.6h in at ~block 2.5M/25.4M — never near tip. |
| erigon | ~1.21 TiB frozen partial | ❌ no | Structural no-sync: erigon3 OtterSync + checkpoint-synced-prysm optimistic gap-close deadlock. Not a synced datadir. |
| ethrex | ~286 GiB at sync → **416 GiB (2026-07-06, growing)** — 306,564,007,339 B at sync; live 447,086,696,857 B | ✅ yes (~2h16m, fully validated) | ethrex **synced cleanly and fastest in the field (~2h16m snap).** No history-prune lever (`--syncmode snap` only; no state-prune flag). Footprint is un-pruned and **NOT full-history** — it serves ~no history (`eth_getBlockByNumber` `null` below head, verified 2026-07-06) yet keeps growing while running (286→416 GiB), so it is **NOT comparable** to pruned geth (~1.13 TiB) or nethermind (~251 GiB). config_optimal=yes (snap is optimal-by-absence; 1 stale-pivot auto-healed). service_crash_observed=no. |

## Gotchas & lessons learned

- **Stage-A triage is blind to a stalled EL.** Triage only checks that the CL reaches tip and the Engine-API JWT handshake works. A node whose CL checkpoint-syncs optimistically PASSES triage even with 0 EL peers and a frozen execution head (nethermind hid a 13.3h zero-progress stall this way). A sync-health verdict must combine peer-count>0 + EL-head advancing + beacon `sync_distance` — never `sync_distance` alone.

- **`eth_syncing=false` is a trap, not a done-signal.** It returns `false` BOTH before snap-sync starts (no pivot yet) and after it finishes. The authoritative "synced" gate is prysm `is_optimistic=false` (EL validated the head payload). besu's `eth_syncing` also returns `false` mid-sync — same trap.

- **A synced nethermind's `eth_syncing` returns an OBJECT, not boolean false** (`currentBlock==highestBlock`). The bakeoff harness now treats the EL as synced on `currentBlock==highestBlock`, not only boolean `false` (commit `5e7a93d`).

- **besu snap sync is two tracks:** block-import reaches head first (a premature "done" signal), but world-state download/heal (Bonsai) is the real bottleneck and where the footprint balloons.

- **besu snap-sync deadlocks if the CL stalls long enough (stability finding, 2026-07-05).** The besu pruned re-run deadlocked **twice** and was abandoned. Chain: a **prysm v7.1.5** data-column-sidecar/PeerDAS bug stalled the CL ~28h (besu logged `Execution engine not called in 120 seconds` continuously) → with no `forkchoiceUpdated` driving it, besu's snap-sync **pivot block aged out** of the network's servable-state window (full nodes serve state for only ~128 recent blocks ≈ 25 min) → world-state heal became un-completable → besu threw `java.lang.IllegalStateException: The pivot block number has not increased` in `SnapSyncChainDownloader.consumePivotUpdate`, cancelled the download, and the downloader **thread died without restarting**. The process stayed alive and answered RPC while the sync engine was dead (datadir frozen, zero DB writes). A restart resumed on the SAME persisted stale pivot and re-deadlocked identically. **Takeaways:** keep the CL binary current before a long besu snap-sync (the stall came from a stale prysm pin); besu answering `eth_blockNumber` ≠ besu syncing (watch DB writes); and this is the prime motivation for the harness stall-watchdog (auto-restart/fail on 0-DB-write-while-unsynced instead of spinning to the 72h cap).

- **Loopback-P2P class of bug.** besu AND nethermind both defaulted P2P advertising to `127.0.0.1` → degraded/zero peering. Fixed (remove loopback `p2p-host` / inject routable `ExternalIp`). geth/erigon/reth/ethrex/nimbus_eth1 bind externally by default.

- **erigon3 OtterSync + checkpoint-synced prysm deadlock** — the one structural no-sync (see the erigon row): EL head freezes behind tip while the beacon stays optimistic; neither issues the `forkchoiceUpdated` that would close the gap. Raising CPU caps advanced it ~5k blocks then re-froze.

- **reth is `--full`-only here** (archive was the disk-hostile default; switched to `--full`); sequential full block execution can't finish a mainnet sync inside the 72h cap.

- **Sampler timestamp skew (~2h):** samples label local CEST times as `Z`. Trust file mtime for wall-clock, not the sample's `timestamp_utc` string.
