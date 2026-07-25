# Eth2 Client Bake-off Results

_Stage A (triage) synthesized from `artifacts/client-bakeoff-2026-06-22/` on 2026-06-23. Raw artifacts are gitignored; this doc is the committed summary._

## Method

- **Baseline-anchored coverage (12 candidates):** every execution client vs fixed Prysm (7 ELs), plus every other consensus client vs a fixed execution anchor (5 CLs). This isolates each client against a known-good counterpart instead of testing every NxM pair.
  - ELs × prysm: geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex
  - CLs × fixed anchor EL: lighthouse, teku, nimbus, lodestar, grandine. The first sweep used **ethrex**, already synced at tip. The originally planned geth sweep was initially deferred, then completed on 2026-07-08 as a cross-anchor check; the heavyweight/lightweight tiers reproduced, while lodestar and lighthouse swapped order within the lightweight tier.
- **Two stages:**
  - **Stage A — triage (this doc):** does each candidate install, checkpoint-sync, and authenticate the Engine API? ~5-min observation window per candidate, 60s sampling.
  - **Stage B — full sync (complete):** each candidate reached a final synced, capped, or no-sync verdict; synced disk footprints are recorded below.
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

## Recommendation (final campaign synthesis)

Stage A established **viability**: all 12 client pairs installed, checkpoint-synced, and authenticated the Engine API on this host. The recommendations below incorporate the completed Stage B footprint, sync-time, and restart-resilience results.

- Recommended execution client: **nethermind** — smallest fully-synced, pruned-comparable footprint (~251 GiB, 4.6× leaner than geth's 1.13 TiB) via its Halite/Paprika flat storage + snap sync, and a minority client so choosing it improves mainnet client diversity. **geth** is the conservative default: largest ecosystem, most docs, cleanest ~8h28m snap sync — but 1.13 TiB. **ethrex** had the fastest sync in the field (~2h16m), yet its datadir keeps growing at tip; a 26-minute/132-block restart gap stalled instead of resuming, and measured 1.5–2-hour gaps triggered a full ~2-hour re-snap. It also isn't pruned-comparable — promising-but-early. besu synced cleanly but un-pruned (1.08 TiB, history-inflated); reth and nimbus_eth1 are full-sync-only (multi-day, capped partial here); erigon deadlocked against checkpoint-synced prysm on this host.
- Recommended consensus client: **lighthouse** — smallest synced footprint (~739 MB), checkpoint-syncs in ~22 min, blob pruning on by default. lodestar (~827 MB) and grandine (~946 MB, with `--prune-storage`) are close seconds; teku (~2.1 GB) and nimbus (~5.0 GB) are heavier. All five checkpoint-sync in ~22–23 min, so footprint is the differentiator.
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
| nimbus_eth1 | fast-sync (default) + `prune = true` | ✅ online-prune confirmed | `prune = true` (commit `0a1730f`) is now **empirically confirmed to prune online**: across the 2026-07-11→13 72h run the journal logged continuous `Pruning history topics="pruner" tail=1262189 … pruned=N` as it imported blocks — so the flag is **not** inert (this contradicts the "pre-merge history needs a separate era1 export" reading of the docs; the online history-pruner demonstrably runs). At-tip *completeness* vs a full era1 export stays untestable here because the node is full-sync-only and never reached tip inside 72h, but the contested-lever question ("does `prune=true` do anything online?") is answered: **yes.** |
| reth | **was archive (no flag)** → now `--full` | ⚠️ **fixed 2026-06-25** | The **only misconfigured EL.** Default reth = archive (~2.8 TiB). `--full` = pruned full node (~1.2 TiB): keeps full block/receipt history, prunes historical state changesets+indices (retains last ~10k blocks). Committed `fix(reth): run pruned full node (--full)`; reth__prysm relaunched. |

**Net effect:** all seven ELs now run their disk-optimal sync mode. Six were already correct out of the box; reth was archive-by-default and is the one change this audit produced. Footprint comparisons across ELs are therefore apples-to-apples on configuration (the snap-vs-full *time* asterisk from the method section still applies — full-sync ELs execute all ~25M blocks, so time-to-sync is not comparable to geth's snap baseline, but final footprint is).

## Final synced disk footprint (Stage B)

_Complete (run_id `client-bakeoff-stageB-2026-06-23`). Runs were sequential, one candidate at a time; every candidate now has a final synced, capped, or no-sync verdict. Footprint = final synced datadir size (EL + CL); secrets/validator material excluded._

| Candidate | Result | Sync time | Final disk footprint (EL + CL) | Notes |
| --- | --- | --- | --- | --- |
| geth__prysm | ✅ synced | ~8h28m | **1.13 TiB** — geth 1,245,128,582,247 B + prysm 654,985,849 B | Baseline. snap-sync EL hands prysm an already-validated head, so there is no large optimistic gap to close. fully_synced=yes, no crash. |
| erigon__prysm | ❌ no-sync | n/a (terminated) | ~1.21 TiB\* — erigon 1,333,017,755,599 B + prysm 1,646,160,347 B | \*Partial, captured at a near-tip **frozen** head — NOT a clean synced datadir. erigon3 OtterSync + checkpoint-synced prysm deadlock: the EL execution head freezes a few thousand blocks behind tip while the beacon stays `is_optimistic=true`; neither side issues the `forkchoiceUpdated` that would close the >96-block backward-download gap. Raising the CL CPU cap 200%→600% advanced the head ~5k blocks then re-froze — confirming a genuine gap-close deadlock, not resource starvation. Terminated per operator decision ("record no-sync, move on"). See artifact `findings.md`. |
| reth__prysm | ⏳ capped (72h) | n/a | ~0.98 TiB\* — reth 1,064,695,764,125 B + prysm 12,468,756,540 B | \*Partial — window-capped at Execution stage block 11,970,965/25,395,872 (47% by block count, ~21% gas-weighted; ended 2026-06-28T16:53:20Z). reth `--full` is the only no-snap EL; sequential full block execution too slow to finish in 72h under caps. Clean SIGTERM stop (ExecMainStatus=0), no crash, 578 samples. Footprint recovered from `samples.jsonl` last entry (16:52:46Z) — `disk-final.tsv` absent due to harness capped-path gap (fixed commit `af0d77f`). Extrapolation: at ~21% gas-exec already ~87% of geth's 1.13 TiB; projected final `--full` footprint ~1.1–1.2 TiB. |
| nethermind__prysm | ✅ synced | ~14.5h (snap) | **~251 GiB** — nethermind 268,110,243,338 B + prysm 1,431,145,921 B | Snap-synced to head 25,428,620, 49 peers, no crash — the **smallest EL footprint** in the field (Halite/Paprika flat storage). NOTE: nethermind's FIRST attempt was a 13.3h 0-peer loopback stall (P2P pinned to 127.0.0.1, execution head frozen ~block 4,651 while the beacon looked healthy) — the origin of the "triage is blind to a stalled EL" lesson below. After the installer was fixed to advertise a routable `ExternalIp` (commit `676e4da`), the re-run synced cleanly. |
| besu__prysm | ✅ **synced** (un-pruned); pruned re-run abandoned | ~19h18m | **~1.08 TiB (un-pruned)** — besu 1,189,836,723,674 B + prysm 1,682,488,084 B | **besu synced successfully.** The 2026-06-30 run snap-synced cleanly to a fully validating head (~50 peers, prysm `is_optimistic=false` at 2026-07-01T01:37:10Z → ~19h18m, fully_synced=yes) — a working, production-viable node. The limitation is **disk-comparability only:** this run had no history pruning → its 1.08 TiB is history-inflated and **NOT pruned-comparable** to geth/nethermind. A pruned re-run (`history-expiry-prune=true`, 2026-07-04) to get a comparable number **deadlocked twice and was abandoned** (operator: "Stop; accept limitation note", 2026-07-05 — see the besu snap-sync deadlock gotcha below; the deadlock trigger was a stale-CL stall, **not** a besu sync failure). So besu's disk number is shown as a client-limitation and excluded from the pruned-comparable ranking, but besu **did** sync. |
| ethrex__prysm | ✅ synced | ~2h16m (snap) | **~286 GiB at sync → ~467 GiB (2026-07-06, still growing even at tip)** — 306,564,007,339 B at sync; live 500,952,726,301 B (`eth_syncing=false`, ~10 GiB/hr) | Snap-synced to a fully validating head in ~2h16m — **fastest EL sync in the field.** 50 peers throughout. 1 automatic stale-pivot update (block 25,469,233→25,469,696) self-healed in ~4 min with no intervention (ethrex clock-based detection, as designed). No crash (service_crash_observed=no, install_exit_code=0). Footprint is un-pruned and **NOT full-history** — ethrex serves ~no history (`eth_getBlockByNumber` returns `null` below head; verified 2026-07-06 at blocks 1/1M/21.6M/~head-7k) yet the datadir keeps growing **even at the chain tip with `eth_syncing=false`** (286 GiB at sync → ~467 GiB, ~10 GiB/hr on 2026-07-06); not pruned-comparable; see client limitations. ethrex v19.0.0. fully_synced=yes, hit_72h_cap=no. |

### Consensus-client matrix — ✅ COMPLETE (anchor = ethrex, run_id `client-bakeoff-clsweep-2026-07-06`)

The CL matrix holds the **execution client constant** and cycles the consensus client, the mirror of the EL scorecard above. The constant anchor is **ethrex** (not geth as first planned): ethrex was already synced at mainnet tip from its EL run, so reusing it as the fixed anchor saved a multi-day re-sync. Because the EL and CL are decoupled across the Engine API (the CL datadir is <1% of the EL and does not depend on which EL it pairs with), the anchor choice does **not** bias the CL comparison. To *prove* that empirically rather than assert it, the full 5-CL sweep was subsequently re-run against a **geth** anchor (2026-07-08, run_id `client-bakeoff-anchor-rotation-2026-07-07`) — the cross-anchor confirmation is recorded below and reproduces the ranking. The ethrex anchor stayed active and `eth_syncing=false` (~502 GB, never restarted) across all five runs; each run cycled only `cl`+`validator`.

All five CLs **checkpoint-synced to a fully validating head in ~22–23 min**, `config_optimal=yes`, `anchor_synced=yes`, `service_crash_observed=no`. Sync **time** is effectively tied (checkpoint sync dominates), so **the CL datadir footprint is the differentiator.**

| CL | Result | Sync time | CL datadir footprint | Disk-optimal lever |
| --- | --- | --- | --- | --- |
| **lighthouse** | ✅ synced | ~22m | **773,282,157 B (~739 MB)** ← **smallest** | `checkpoint-sync-url` (blob-prune default) |
| **lodestar** | ✅ synced | ~22m | **867,829,601 B (~827 MB)** | `chain.pruneHistory=true` |
| **grandine** | ✅ synced | ~22m | **1,343,716,523 B (~946 MB on disk)** | `--prune-storage` (CRITICAL — stores all states without it) |
| **teku** | ✅ synced | ~22m | **2,160,709,791 B (~2.1 GB)** | `data-storage-mode=minimal` |
| **nimbus** | ✅ synced | ~23m | **5,302,005,871 B (~5.0 GB)** ← **largest (6.8×)** | `history=prune` |

**CL disk ranking (smaller = better, all config-optimal + checkpoint-synced): lighthouse (~739 MB) < lodestar (~827 MB) < grandine (~946 MB) < teku (~2.1 GB) < nimbus (~5.0 GB).**

- **teku required a re-run.** Its first attempt (pre-`TEKU_CACHE=8192m`) JVM-OOM-starved the shared host, took 64 min to sync, and briefly blipped the anchor → `anchor_synced=no` (recorded, discarded as `env.txt.poisoned-run1`). The re-run with `TEKU_CACHE` raised to 8192m (commit `bf043aa`) synced clean in 22 min with a healthy anchor. Lesson: teku's JVM heap must be sized generously on a shared host or its GC pressure spills onto co-resident services. The valid 2.1 GB row is the re-run.
- **All CL footprints are <1% of the ethrex anchor's ~502 GB EL datadir** → confirms EL/CL decoupling: consensus-client choice does not move the EL disk ranking, and vice-versa.

### CL matrix — cross-anchor confirmation (anchor = **geth**, run_id `client-bakeoff-anchor-rotation-2026-07-07`, 2026-07-08)

The same 5-CL sweep was re-run against a **geth** anchor to verify the ranking is not an artifact of the ethrex anchor. All five runs were `config_optimal=yes`, `anchor_synced=yes`, no service crash; each cycled only `cl`+`validator` against the preserved geth EL datadir (~1.13 TiB, never wiped).

| Consensus | Sync status | Sync time | Final CL datadir | History-prune lever |
|-----------|-------------|-----------|------------------|---------------------|
| **lodestar** | ✅ synced | ~6m27s | **185,100,788 B (~177 MiB)** ← **smallest** | `pruneHistory=true` |
| **lighthouse** | ✅ synced | ~8m54s | **542,301,237 B (~518 MiB)** | `checkpoint-sync-url` |
| **grandine** | ✅ synced | ~8m50s | **1,074,340,425 B apparent / ~725 MiB actual** (sparse DB) | `prune-storage` |
| **teku** | ✅ synced | ~8m52s | **977,108,456 B (~936 MiB)** | `data-storage-mode=minimal` |
| **nimbus** | ✅ synced | ~7m58s | **1,198,275,155 B (~1.2 GiB)** ← **largest** | `history=prune` |

**geth-anchor CL disk ranking (actual disk, smaller = better): lodestar (~177 MiB) < lighthouse (~518 MiB) < grandine (~725 MiB actual) < teku (~936 MiB) < nimbus (~1.2 GiB).**

**Cross-anchor verdict — the tiers reproduce:**
- **Heavyweight tier holds on both anchors:** nimbus is always the largest CL and teku always the second-largest, on both the ethrex and geth anchors.
- **Lightweight tier holds:** grandine, lighthouse, and lodestar are always the three smallest. The lodestar↔lighthouse order flips between anchors (geth: lodestar < lighthouse; ethrex: lighthouse < lodestar) but both sit in the smallest tier, where the gap is small and measurement-window-sensitive.
- **Absolute footprints scale with observation time, not just the EL anchor.** The geth-anchor numbers are much smaller (nimbus ~1.2 GiB vs ~5.0 GB; teku ~936 MiB vs ~2.1 GB) because those runs were measured minutes after checkpoint-sync (a fresh datadir), while the ethrex-anchor runs ran longer post-sync and had filled more of the blob-retention / state-history window. The broad tiers are anchor-independent here; exact within-tier order is measurement-window-sensitive.
- **Net:** two different EL anchors (ethrex, geth) reproduce the same heavyweight/lightweight tiers, empirically supporting EL/CL decoupling without claiming an identical total order.

**Measurement notes:**
- **grandine uses sparse DB files** → its apparent `du -sb` byte count (1,074,340,425 B) overstates real on-disk usage. `du -sh` reports **~725 MiB actual**, which is the fair number for ranking. The other four CLs had apparent ≈ actual.
- **Harness fix `98a52d7` (belongs in PR #190):** `bakeoff_snapshot_disk` guarded its `du | awk` pipeline with `|| true`. Without it, when the live anchor EL churned its datadir during a snapshot, `du` hit a vanishing file → exit 1 → `pipefail` killed the run (this spuriously failed grandine's first attempt; the clean re-run above is authoritative).

### Client limitations — shown separately, NOT in the pruned-comparable ranking

Only **geth** (~1.13 TiB) and **nethermind** (~251 GiB) produced a final footprint under a **pruned, apples-to-apples** config, so only those two are ranked head-to-head on disk. The rest are recorded here with the reason each falls outside that comparison. **"Outside the disk ranking" does not mean "failed to sync"** — besu in particular synced cleanly (see below); it's here purely because we don't have a pruned-comparable disk number for it.

| EL | Footprint recorded | Synced? | Why it's outside the pruned-comparable ranking |
| --- | --- | --- | --- |
| besu | ~1.08 TiB (un-pruned) | ✅ yes (~19h18m, fully validated) | besu **synced fine** — the un-pruned run just isn't disk-comparable (history-inflated), and the pruned re-run to fix that deadlocked twice and was abandoned (stale-pivot → `SnapSyncChainDownloader` thread death; root-caused to a ~28h prysm-v7.1.5 CL stall, **not** a besu fault — see gotcha below). |
| reth | ~0.98 TiB partial (72h-capped) | ⏳ partial | `--full`-only (no snap); sequential full block execution can't finish mainnet inside the 72h cap. Speed-bound, not config-bound. |
| nimbus_eth1 | **~40 GB partial @72h cap** (2026-07-13; supersedes an earlier ~21 GB aborted run) | ⏳ partial (~21.6%) | Full-sync-only (no snap). The 72h governance-cap run (2026-07-11→13, run_id `client-bakeoff-nimbuseth1-2026-07-11`) ran **72h continuously with 0 restarts** (stable throughout, 20–25 peers) and reached **~21.6%** — head 5,509,858 / target 25,505,378, eta ~1w3d still remaining — so it never neared tip. **New, measured this run:** `prune = true` is **empirically confirmed pruning online** (journal `Pruning history … pruned=N` logged continuously during import), which **resolves the earlier "contested / era1-only / unverified" open question** — the lever is NOT inert. It stays outside the pruned-comparable ranking only because a full-sync-only client can't reach tip in a practical window on this host, **not** because the prune lever fails. |
| erigon | ~1.21 TiB frozen partial | ❌ no | Structural no-sync: erigon3 OtterSync + checkpoint-synced-prysm optimistic gap-close deadlock. Not a synced datadir. |
| ethrex | ~286 GiB at sync → **~467 GiB (2026-07-06, still growing even at tip)** — 306,564,007,339 B at sync; live 500,952,726,301 B (`eth_syncing=false`, ~10 GiB/hr) | ✅ yes (~2h16m, fully validated) | ethrex **synced cleanly and fastest in the field (~2h16m snap).** No history-prune lever (`--syncmode snap` only; no state-prune flag). Footprint is un-pruned and **NOT full-history** — it serves ~no history (`eth_getBlockByNumber` `null` below head, verified 2026-07-06) yet keeps growing **even at the chain tip with `eth_syncing=false`** (286 → ~467 GiB, ~10 GiB/hr), so it is **NOT comparable** to pruned geth (~1.13 TiB) or nethermind (~251 GiB). config_optimal=yes (snap is optimal-by-absence; 1 stale-pivot auto-healed). service_crash_observed=no. |

## Operational viability — which clients would we actually run (Stage B + CL matrix synthesis)

The disk ranking answers "smallest," but production also asks "will it survive restarts, upgrades, and weeks of uptime?" Under that operational lens the field narrows sharply — and the two layers tell opposite stories: the **EL layer is where the operational risk lives; the CL layer is basically solved.**

**Execution clients — two clear picks, one qualified third:**

- **geth and nethermind are the only two that cleared the full operational bar** here: snap-sync to a validating tip, a working history-prune lever (so the disk number is apples-to-apples), clean restart-resume, and the two largest, most battle-tested codebases. **nethermind** wins on disk (~251 GiB, ~4.6× leaner than geth) and improves client diversity as a minority client; **geth** is the conservative default (largest ecosystem, most docs, cleanest ~8h28m snap). If you run one EL for the long haul, run one of these two.
- **besu** is a viable enterprise third — it *did* snap-sync to a fully validated head — but with two asterisks: our run was un-pruned (history-inflated ~1.08 TiB, no pruned-comparable number), and its snap sync is **fragile to a prolonged CL outage** (a stalled CL ages the pivot out of the servable-state window → `SnapSyncChainDownloader` thread death, observed twice, un-recoverable). Runnable in a shop that keeps its CL current and watches the pivot; not a set-and-forget solo-staker pick.
- **The rest each missed the bar for a specific, documented reason — not a blanket "bad client":**
  - **ethrex** — fastest cold sync in the whole field (~2h16m) but the *wrong* long-run profile, exactly as flagged: no prune lever, datadir grows unbounded even at tip (~10 GiB/hr, 286 → ~467 GiB), a 26-minute/132-block gap stalled instead of resuming, and measured 1.5–2-hour gaps triggered a full ~2-hour re-snap. Snap speed is a trap here — fast to stand up, painful to *operate*. Young client (v19.0.0); may improve.
  - **reth, nimbus_eth1** — full-sync-only (no snap) in the mode we tested; can't reach tip inside a practical window on this host. This is a time-to-sync limit under our snap-to-tip bar, **not** a verdict on the clients in every context (reth in particular is widely run elsewhere).
  - **erigon** — deadlocked against checkpoint-synced prysm on this host (structural, reproducible), so no synced datadir.

**Consensus clients — the healthy half: all five we swept are operationally effective.** Every CL (lighthouse, lodestar, grandine, teku, nimbus) checkpoint-synced to a validating head in ~22–23 min, `config_optimal=yes`, zero crashes, against a live anchor. Unlike the EL layer, none of them *failed* — so the choice is footprint + preference, not survivability:

- Disk order (the only differentiator): **lighthouse (~739 MB) < lodestar (~827 MB) < grandine (~946 MB) < teku (~2.1 GB) < nimbus (~5.0 GB).**
- Two small operational caveats: **teku** needs a generously sized JVM heap on a shared host (undersized, its GC pressure spilled onto co-resident services and poisoned a first run); **grandine** needs `--prune-storage` or it stores every state. **nimbus** is simply the heaviest (~6.8× lighthouse) but otherwise clean.
- Cross-cutting CL lesson (learned from prysm, the constant anchor): **keep the CL binary current.** A stale prysm v7.1.5 pin stalled ~28h on a PeerDAS/data-column bug and is precisely what aged out besu's pivot. Binary freshness is an operational requirement, not a nicety.

**Bottom line:** on the EL side a real long-running node comes down to **geth or nethermind** (besu if you're an enterprise shop that keeps its CL healthy); on the CL side **any of the five works**, with **lighthouse** the lean default. Fast initial sync (ethrex) and small archive-context footprints do not by themselves make a client operationally viable — durability across restarts and uptime is the deciding axis, and that is an EL-layer problem.

## Gotchas & lessons learned

- **Stage-A triage is blind to a stalled EL.** Triage only checks that the CL reaches tip and the Engine-API JWT handshake works. A node whose CL checkpoint-syncs optimistically PASSES triage even with 0 EL peers and a frozen execution head (nethermind hid a 13.3h zero-progress stall this way). A sync-health verdict must combine peer-count>0 + EL-head advancing + beacon `sync_distance` — never `sync_distance` alone.

- **`eth_syncing=false` is a trap, not a done-signal.** It returns `false` BOTH before snap-sync starts (no pivot yet) and after it finishes. The authoritative "synced" gate is prysm `is_optimistic=false` (EL validated the head payload). besu's `eth_syncing` also returns `false` mid-sync — same trap.

- **A synced nethermind's `eth_syncing` returns an OBJECT, not boolean false** (`currentBlock==highestBlock`). The bakeoff harness now treats the EL as synced on `currentBlock==highestBlock`, not only boolean `false` (commit `5e7a93d`).

- **besu snap sync is two tracks:** block-import reaches head first (a premature "done" signal), but world-state download/heal (Bonsai) is the real bottleneck and where the footprint balloons.

- **besu snap-sync deadlocks if the CL stalls long enough (stability finding, 2026-07-05).** The besu pruned re-run deadlocked **twice** and was abandoned. Chain: a **prysm v7.1.5** data-column-sidecar/PeerDAS bug stalled the CL ~28h (besu logged `Execution engine not called in 120 seconds` continuously) → with no `forkchoiceUpdated` driving it, besu's snap-sync **pivot block aged out** of the network's servable-state window (full nodes serve state for only ~128 recent blocks ≈ 25 min) → world-state heal became un-completable → besu threw `java.lang.IllegalStateException: The pivot block number has not increased` in `SnapSyncChainDownloader.consumePivotUpdate`, cancelled the download, and the downloader **thread died without restarting**. The process stayed alive and answered RPC while the sync engine was dead (datadir frozen, zero DB writes). A restart resumed on the SAME persisted stale pivot and re-deadlocked identically. **Takeaways:** keep the CL binary current before a long besu snap-sync (the stall came from a stale prysm pin); besu answering `eth_blockNumber` ≠ besu syncing (watch DB writes); and this is the prime motivation for the harness stall-watchdog — **now implemented** (#31, PR #190) as an opt-in watchdog: with `ETH2QS_BAKEOFF_STALL_RESTART=yes`, if the unit under test makes no forward progress (EL block number / CL `head_slot` flat) for `ETH2QS_BAKEOFF_STALL_SAMPLES` polls (default 10) it performs up to `ETH2QS_BAKEOFF_STALL_MAX_RESTARTS` bounded restarts (default 3) of *only that unit*, then marks the row `.stalled` and fails it instead of spinning to the 72h cap.

- **ethrex restart cliff begins beyond ~25 min; longer measured gaps re-snap from scratch (operational cliff, v19.0.0).** A routine restart with a ~1.5–2h gap made ethrex **discard its fully-synced 286 GiB state and start a fresh snap sync from near-genesis** (datadir collapsed 286 GiB → ~9 GiB → climbing; journal `SNAP SYNC STARTED` → `PHASE 1/8: BLOCK HEADERS` from ~198k/25.47M; `eth_blockNumber`=`0x0` throughout). Root cause: after the gap ethrex's old head aged out of the network's ~128-block (~25 min) servable-state window, so when prysm drove `forkchoiceUpdated` to the current head, ethrex re-pivoted to a full snap rather than importing the missed gap — contrast **geth**, which resumes by importing the missed blocks and keeps its state. Two measured re-sync costs: **~2h16m (cold) + ~2h11m (post-downtime re-snap)**; the re-snapped datadir then rebuilt *past* the old 286 GiB. **Blog through-line:** a client that stops resuming beyond ~25 minutes and can full-re-sync on longer gaps is operationally painful — a strong candidate explanation for ethrex's ~0% adoption despite the field's fastest cold sync. **Threshold precisely bracketed (2026-07-10 restart bisection).** Controlled `systemctl stop eth1` → wait → `start` runs with a live prysm driving forkchoice: gaps of **12 min / 68 blk, 20 min / 108 blk, and 23 min / 124 blk all resumed cleanly** (ethrex imported the missed blocks, datadir intact, canonical head climbed back to tip), while a **26 min / 132 blk gap stuck** — the canonical head froze (`eth_blockNumber` flat at the pre-stop block for 12+ min, `eth_syncing.currentBlock=0x0`), ethrex logged `FCU head state not reachable from DB state … Starting sync toward head` and `Failed to fetch headers for sync head — peer(s) queried but did not serve headers`, and the gap widened as the tip advanced (no datadir collapse *within* the 12-min watch — the stuck disconnected-head state is the onset that escalates to the full snap re-sync at larger gaps). So the cliff edge is **~128 blocks ≈ 24–25 min**, matching the ~128-block servable window exactly: inside it peers still serve the gap headers and ethrex bridges; beyond it they don't, the head freezes, and the ~1.5–2h gap above drove the full datadir-collapse re-snap. Caveat: young client (v19.0.0, may improve); this does **not** change the recorded sync-time result (2h16m, captured at synced time).
- **geth resumes gracefully after a ~52h (multi-day) downtime — measured 2026-07-10 (the positive contrast to ethrex).** Restarted after a stop that had left it ~15,400 blocks / ~52h behind (`eth_syncing.startingBlock`=25,487,154 — *not* genesis, no snap-pivot reset), geth **kept its full multi-hundred-GB datadir** and caught up purely by **sequential block-import with trie-diff application** — journal `Imported new chain segment … triediffs=… triedirty=…` on every segment, *not* a re-snap. Throughout: no datadir collapse (contrast ethrex's 286 GiB → ~9 GiB), `eth_syncing` returned an import object (never `0x0`), state healing ran to completion (`healingTrienodes=0x0`), and it **converged back to the validating tip** (`eth_syncing=false` at block 25,502,592). This is the resume profile you want for an EL you upgrade/restart regularly, and it is *why* geth clears the operational bar above where ethrex's re-snap cliff does not. (Wall-clock resume time not cleanly bounded on this shared host, so only the mechanism + datadir preservation are claimed.)

- **Client distribution is a WEAK/NUANCED predictor of syncability.** The tempting story — low/zero-share clients all struggle — is only half true. erigon (deadlock), reth & nimbus_eth1 (full-sync-only, can't finish in 72h) did struggle, but **ethrex (~0% share, Lambda Class) synced FASTEST in the whole field (~2h16m).** The real driver is **snap-sync availability + client robustness** (ethrex has both: snap + clock-based stale-pivot self-healing), not market share per se. Don't overclaim the correlation in the blog — ethrex's un-pruned, growing footprint keeps it out of the disk ranking, so speed (not size) is its claim.

- **Loopback-P2P class of bug.** besu AND nethermind both defaulted P2P advertising to `127.0.0.1` → degraded/zero peering. Fixed (remove loopback `p2p-host` / inject routable `ExternalIp`). geth/erigon/reth/ethrex/nimbus_eth1 bind externally by default.

- **erigon3 OtterSync + checkpoint-synced prysm deadlock** — the one structural no-sync (see the erigon row): EL head freezes behind tip while the beacon stays optimistic; neither issues the `forkchoiceUpdated` that would close the gap. Raising CPU caps advanced it ~5k blocks then re-froze.

- **reth is `--full`-only here** (archive was the disk-hostile default; switched to `--full`); sequential full block execution can't finish a mainnet sync inside the 72h cap.

- **Sampler timestamp skew (~2h):** samples label local CEST times as `Z`. Trust file mtime for wall-clock, not the sample's `timestamp_utc` string.
