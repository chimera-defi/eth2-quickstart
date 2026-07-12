# The 128-block window: forensic findings from an Ethereum client bake-off

*The technical companion to the [operator's guide](CLIENT_BAKEOFF_OPERATOR_GUIDE.md). This is the long version — methodology, the two marquee failure modes, and the single mechanism that explains both. All numbers are of record in [`CLIENT_BAKEOFF_RESULTS.md`](../CLIENT_BAKEOFF_RESULTS.md); raw run artifacts (sample logs, journals) are gitignored, and the committed results doc is the summary of record.*

If you take one idea from this write-up, take this: **Ethereum full nodes serve recent world-state for only about 128 blocks — roughly 25 minutes.** That number is invisible on day one and decisive on day two. It sets a hard edge on how long an in-progress or restarted node can be "behind" before it can no longer heal itself from peers and is forced into a full re-sync. Two of the most interesting failures in this bake-off — ethrex's restart cliff and besu's mid-sync deadlock — are the same wall hit from two different angles.

## What we measured, and how we kept ourselves honest

The design is **baseline-anchored** rather than combinatorial. Testing every EL×CL pair is N×M runs of a multi-day sync; instead we fix a known-good counterpart and vary one side:

- **EL scorecard:** each of 7 execution clients (geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex) against a fixed **prysm**.
- **CL scorecard:** each of 5 consensus clients (lighthouse, teku, nimbus, lodestar, grandine) against a fixed execution anchor — **ethrex** first, then **geth** as a cross-check.

Two stages per candidate: **Stage A** triage (does it install, checkpoint-sync, and authenticate the Engine API in a ~5-minute window?) and **Stage B** full sync-to-completion (final synced disk footprint). Execution was strictly sequential — one candidate at a time on one shared semi-prod host, resource-capped to protect co-resident workloads — with MEV off, no validator keys, and a 72-hour cap per candidate. Footprint is always the last near-cap `du` sample, never the peak.

The credibility of any bake-off rests on one uncomfortable question: *were the clients actually configured optimally when you measured them?* Early in the campaign we corrupted our own numbers by recording footprints before verifying each client was in its most disk-efficient mode. The fix was a **config-optimality gate**: every recorded row is stamped `config_optimal=yes|no` by a harness check that inspects the actually-generated, actually-running config and refuses to trust a footprint from a misconfigured client. That gate needed six bug-fixes across three review rounds before it was trustworthy — which is itself the point. Without it, the reth number would have been an archive node (~2.8 TiB) masquerading as a full node, and the geth baseline could have silently dropped its post-merge history prune.

A representative catch: reth ships **archive-by-default**. Left alone it would have posted ~2.8 TiB and dominated the "geth is huge" narrative with a number that no sane operator would ever run. The gate flagged it; we switched it to `--full` (pruned full node) and re-ran. Six of seven ELs were already optimal out of the box; reth was the one the audit corrected.

## The execution scorecard

| EL | Status | Sync time | Footprint | Sync mode | Share | Note |
|----|--------|-----------|-----------|-----------|-------|------|
| nethermind | ✅ synced | ~14.5h | **~251 GiB** | snap + Bonsai flat-DB | 36.0% | Smallest pruned-comparable footprint in the field. |
| ethrex | ✅ synced | **~2h16m** | ~286 GiB → ~467 GiB (growing) | snap (v19.0.0) | 0.0% | Fastest cold sync; un-pruned + serves ~no history. |
| geth | ✅ synced | ~8h28m | ~1.13 TiB | snap + `--history.chain postmerge` | 44.9% | Baseline; resumes cleanly. |
| besu | ✅ synced (un-pruned) | ~19h18m | ~1.08 TiB | snap / Bonsai | 17.4% | Synced fine; pruned re-run deadlocked (see below). |
| reth | ⏳ 72h cap | did not finish | ~0.98 TiB @ ~21% | full-sync-only | 1.5% | No snap path → too slow for a 3-day window. |
| nimbus_eth1 | ⏳ partial | pending (~07-14) | ~21 GiB @ ~10% | full-sync-only | ~0% | No snap; terminal partial pending. |
| erigon | ❌ no-sync | deadlocked | — | OtterSync | 0.0% | Structural gap-close deadlock; no footprint. |

**The honest disk ranking** is only two clients wide, because only two produced a *pruned, apples-to-apples* footprint: **nethermind (~251 GiB) < geth (~1.13 TiB)**. Everything else is recorded separately with the reason it falls outside that comparison — and "outside the ranking" never means "failed to sync." besu synced cleanly; it's excluded only because its run was history-inflated and the pruned re-run never landed.

**The speed ranking** among clients that finished: **ethrex ~2h16m < geth ~8h28m < nethermind ~14.5h < besu ~19h18m.** A ~0%-adoption minimalist Rust client (ethrex, from Lambda Class) beat the entire field on cold sync by roughly 4×. Which raises the obvious question the rest of this post answers: *if it's the fastest, why does nobody run it?*

## The novel axis: restart-resilience

Cold-sync numbers describe a node once, on day one. Operators restart nodes constantly. So "how does the client behave after a restart with a gap?" is a first-class question — and it cleanly separates the field into three behaviors.

**1. Graceful resume.** The client comes back up, imports the blocks it missed during the gap, and keeps its on-disk state. We measured this directly on **geth**: restarted after a stop that left it ~15,400 blocks / ~52 hours behind, geth kept its full multi-hundred-GB datadir and caught up purely by sequential block-import — journal lines `Imported new chain segment … triediffs=… triedirty=…` on every segment, *not* a re-snap. The datadir never collapsed, `eth_syncing` returned an import object (never `0x0`), state healing ran to completion (`healingTrienodes=0x0`), and it converged back to the validating tip. This is the resume profile you want from an EL you upgrade regularly. nethermind and reth are expected here by design, though we did not bisect their restart behavior in this campaign.

**2. Re-snap cliff.** Past a downtime threshold, the client discards its synced state and re-syncs from scratch. This is ethrex, and it's the campaign's marquee finding.

**3. Mid-sync deadlock.** If the CL stops driving the engine during an *in-progress* snap sync, the EL's pivot ages out of the servable window and the sync wedges permanently — the process stays alive and answers RPC, but makes zero progress. This is besu.

The two failure modes share a mechanism, which we'll come to. First, the forensics.

## Marquee case 1: ethrex's restart-resync cliff

**What happened.** After a routine ~1.5–2h restart gap, a fully-synced ethrex (286 GiB, at mainnet head) abandoned its state and began a fresh full snap sync from near-genesis. The evidence chain is all directly observed, not inferred:

- The restart was a plain `systemctl start eth1`; the unit's ExecStart is a persistent-datadir `--syncmode snap` with **no wipe/clean/reset flag** — ruling out a harness or unit artifact.
- The datadir collapsed **286 GiB → ~9 GiB → climbing** — state discarded, not resumed.
- The journal logged `SNAP SYNC STARTED` → `PHASE 1/8: BLOCK HEADERS` starting from `Headers: 198,125 / 25,470,353` (near-genesis, not resuming from the prior ~25.47M head). `eth_blockNumber` returned `0x0` throughout.
- The re-sync ran the same full pipeline as the original ~2h16m cold sync, and we captured its cost independently: **~2h11m** for the re-snap (`SNAP SYNC STARTED` 01:58:29Z → complete 04:09:37Z). Two measured data points — one cold, one post-downtime — for the same client.

**Where the threshold is.** We bisected it with controlled `systemctl stop eth1` → wait → `start` cycles, a live prysm driving forkchoice throughout:

| Gap | Blocks behind | Outcome |
|-----|---------------|---------|
| 12 min | 68 | Resumed cleanly |
| 20 min | 108 | Resumed cleanly |
| 23 min | 124 | Resumed cleanly |
| **26 min** | **132** | **Stuck** — head froze |

The cliff edge is **~128 blocks ≈ 24–25 minutes** — exactly the ~128-block servable-state window. Inside it, peers still serve the gap headers and ethrex bridges the gap by import. Beyond it, the head freezes: `eth_blockNumber` flat at the pre-stop block, `eth_syncing.currentBlock=0x0`, and the journal shows `FCU head state not reachable from DB state … Starting sync toward head` followed by `Failed to fetch headers for sync head — peer(s) queried but did not serve headers`.

**The mechanism.** After the gap, ethrex's old head has aged out of the servable window. When prysm — optimistically at the current head — drives `forkchoiceUpdated` forward, ethrex is too far behind to close the gap by block import, so it re-pivots to a fresh snap sync rather than resuming. The stuck disconnected-head state is the *onset*; the full 286 GiB → 9 GiB datadir collapse is what the larger ~1.5–2h gap escalated to. The true trigger is **header-fetch failure beyond the servable window**, not state expiry per se.

**Why it matters.** A client that re-syncs from scratch after any downtime beyond ~25 minutes is operationally painful — every upgrade, crash, or maintenance window longer than that costs a full ~2h re-sync, and (separately) the datadir grows unbounded at ~10 GiB/hr even at the tip with `eth_syncing=false`. This is a strong candidate explanation for ethrex's near-zero operational adoption *despite* the field's fastest cold sync: great benchmark, painful to actually run.

**Fairness caveats, stated plainly.** This is v19.0.0 — ethrex is young and this may improve. The cliff does **not** change the recorded 2h16m sync-time result (captured at synced time); it's a separate resilience finding presented alongside, not folded into, the cold-sync number.

## Marquee case 2: besu's snap-sync deadlock

besu synced fine on its first run (~19h18m to a fully validated head). The trouble came on a *pruned re-run* intended to get a disk-comparable number — it deadlocked twice and was abandoned. The causal chain is a production cautionary tale:

1. A stale **prysm v7.1.5** (a PeerDAS / data-column-sidecar bug) stalled the consensus client for ~28 hours. besu logged `Execution engine not called in 120 seconds` continuously — the CL had stopped driving it.
2. With no `forkchoiceUpdated` arriving, besu's snap-sync **pivot block aged out** of the servable-state window. The world-state heal became un-completable — peers could no longer serve the missing trie nodes.
3. besu threw `java.lang.IllegalStateException: The pivot block number has not increased` in `SnapSyncChainDownloader.consumePivotUpdate`, cancelled the download, and **the downloader thread died without restarting.** The process stayed alive and still answered `eth_blockNumber` — but the sync engine was dead and the datadir frozen (zero DB writes).
4. A restart resumed on the *same persisted stale pivot*, healed briefly, then re-deadlocked identically.

**Takeaways:** (a) an in-progress besu snap sync is fragile to a prolonged CL outage — a stale CL binary can poison the EL's pivot irrecoverably; (b) besu answering RPC is not besu syncing — judge by disk growth and DB writes, not RPC liveness; (c) this is the strongest motivation for the harness **stall-watchdog** we subsequently implemented: opt-in via `ETH2QS_BAKEOFF_STALL_RESTART=yes`, it detects "no forward progress for N polls" and performs a bounded number of restarts of just the stalled unit, then fails the row cleanly instead of spinning to the 72h cap.

## The unifying mechanism

ethrex's cliff and besu's deadlock are two faces of the same ~128-block / ~25-minute servable-state window:

- **besu** hits it **mid-sync**: the pivot it's healing toward ages out while the sync is still in flight.
- **ethrex** hits it **post-sync, on restart**: the head it's resuming from ages out during the downtime gap.

In both cases the node can no longer fetch the state it needs from peers, because full nodes simply don't serve state that old. Graceful-resume clients (geth) sidestep the whole problem by importing gap *blocks* — which are always available from any peer — and applying trie diffs locally, rather than re-fetching *state*. That's the entire difference between "resumes in minutes" and "re-syncs from scratch." It is not a quality gap in the abstract; it's a specific architectural choice about how to close a gap after falling behind.

## The consensus matrix, and a decoupling proof

All five consensus clients checkpoint-synced to a validating head in ~22–23 minutes, `config_optimal=yes`, zero crashes. Sync *time* is effectively tied — checkpoint sync dominates — so the differentiator is datadir footprint. We ran the full sweep against two different execution anchors to prove the ranking is a property of the CL, not of the anchor:

| CL | ethrex-anchor footprint | geth-anchor footprint | History-prune lever |
|----|-------------------------|-----------------------|---------------------|
| lighthouse | ~739 MB | ~518 MiB | `checkpoint-sync-url` (blob-prune default) |
| lodestar | ~827 MB | **~177 MiB** (smallest) | `chain.pruneHistory=true` |
| grandine | ~946 MB | ~725 MiB (sparse DB) | `--prune-storage` (critical) |
| teku | ~2.1 GB | ~936 MiB | `data-storage-mode=minimal` |
| nimbus | ~5.0 GB (largest) | ~1.2 GiB (largest) | `history=prune` |

**The ranking reproduces across anchors.** The heavyweight tier holds — nimbus always the largest, teku always second. The lightweight tier holds — lodestar, lighthouse, grandine always the three smallest (only the lodestar↔lighthouse order flips within that smallest tier, where the gap is small and window-sensitive). The *absolute* sizes differ because the geth-anchor runs were measured minutes after checkpoint-sync while the ethrex-anchor runs ran longer and filled more of the blob-retention window — absolute footprint scales with observation time, ranking does not. Two anchors, same order: **EL/CL decoupling confirmed empirically, not merely asserted.** Every CL datadir was under 1% of its EL anchor's footprint, which is why holding the EL constant for the CL scorecard (and vice-versa) is valid.

Two CL operational notes worth carrying: **teku** JVM-OOM-starved the shared host on its first run and briefly poisoned the anchor — its heap (`TEKU_CACHE`) must be sized generously on a shared box; and **grandine** stores every state without `--prune-storage`, making that its single most important flag.

## The distribution nuance (don't overclaim)

A tempting story is "mainnet distribution predicts syncability" — the low-share clients are exactly the ones that struggle. The data only *half* supports it. Yes, erigon (deadlock) and reth/nimbus_eth1 (full-sync-only, can't finish in 72h) are minority clients that struggled. But **ethrex — ~0% share — synced fastest in the whole field.** The real predictor is **snap-sync availability plus client robustness**, not market share. ethrex has both (snap + clock-based stale-pivot self-healing during the initial sync) and excelled on cold sync; its *adoption* gap is better explained by the restart cliff than by any sync deficiency. Write the nuanced version, not the flat correlation.

## Gotchas worth internalizing

- **`eth_syncing=false` is a trap, not a done-signal.** It returns `false` both *before* snap-sync starts (no pivot yet) and *after* it finishes. The authoritative "synced" gate is prysm `is_optimistic=false` (the EL validated the head payload). A synced *nethermind* additionally returns an *object* (`currentBlock==highestBlock`), not boolean false — the harness now treats that as synced too.
- **Stage-A triage is blind to a stalled EL.** A node whose CL checkpoint-syncs optimistically PASSES triage even with 0 EL peers and a frozen execution head — nethermind hid a 13.3h zero-progress stall this way (P2P pinned to loopback). A real sync-health verdict must combine peer-count > 0 *and* EL-head advancing *and* beacon `sync_distance` trending down — never `sync_distance` alone.
- **The loopback-P2P class of bug.** besu *and* nethermind both defaulted P2P advertising to `127.0.0.1` → degraded or zero peering. Fixed by removing the loopback `p2p-host` and injecting a routable external IP. (geth, erigon, reth, ethrex, nimbus_eth1 bind externally by default.)
- **besu snap sync is two tracks:** block-import reaches head first (a premature "done" signal), but world-state download/heal is the real bottleneck and where the footprint balloons.
- **erigon3 OtterSync + checkpoint-synced prysm deadlock** — the one hard no-sync: the EL head freezes behind tip while the beacon stays optimistic, and neither side issues the `forkchoiceUpdated` that would close the gap. Raising CPU caps advanced it ~5k blocks, then it re-froze — a genuine gap-close deadlock, not resource starvation.

## The through-line

This bake-off started as a disk-and-speed spreadsheet and turned into an argument about a single protocol constant. The ~128-block servable-state window is why the fastest-syncing client is also the one that re-syncs from scratch every restart, and why a stale consensus client can permanently wedge an otherwise-healthy execution client mid-sync. For the operator, the practical distillation is short: **run geth or nethermind, keep any CL you like current, and value the client that resumes over the client that sprints.**

---

*Data of record: [`CLIENT_BAKEOFF_RESULTS.md`](../CLIENT_BAKEOFF_RESULTS.md). Framing notes: [`CLIENT_BAKEOFF_BLOG_NOTES.md`](../CLIENT_BAKEOFF_BLOG_NOTES.md). The `nimbus_eth1` execution-client full-sync row is a partial pending its terminal measurement (~2026-07-14); as a full-sync-only client it won't reach tip inside the cap, so it lands as a client-limitation footnote rather than a ranking entry. Preliminary from that in-progress run: `prune=true` is pruning online (observed `pruned=14600` in-journal), which — if it holds at terminal — would resolve the previously-contested question of whether nimbus_eth1's prune lever is inert. That will be confirmed or retracted when the run terminates.*
