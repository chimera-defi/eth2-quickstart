# Client Bake-off — Blog Framing Notes (working document)

**Status:** working notes for the eventual blog post. This is the *narrative + framing* companion to
the raw data in [`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md) (the committed results twin) and
[`CLIENT_BAKEOFF_ISSUES_LOG.md`](CLIENT_BAKEOFF_ISSUES_LOG.md) (per-run incident log). Numbers here are
copied from the of-record snapshot; if they ever disagree, the results doc + run artifacts win.

**What the bake-off measures:** for every supported execution (EL) and consensus (CL) client, the FINAL
synced **disk footprint** and **sync duration**, on a shared semi-prod host (NOT a production validator),
MEV=none, NO validator keys. One candidate at a time, 72h cap per candidate. Footprint = the last/near-cap
`du` sample (never the peak). For the EL scorecard the CL is held constant at **prysm** — justified because
an EL's footprint and sync time are EL-only properties, decoupled from the CL across the Engine API (the
prysm datadir is ~0.65–1.68 GB, negligible against an EL's hundreds of GB).

---

## 0. CAMPAIGN COMPLETE — all tests finished (2026-07-14)

**All bake-off tests are now complete.** The EL scorecard (7/7), the CL matrix (both anchors), the ethrex
restart cliff, and the final nimbus_eth1 anchor are **final and of-record**. The publishable writeup lives at
[`CLIENT_BAKEOFF_BLOG.md`](CLIENT_BAKEOFF_BLOG.md); raw data in
[`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md). This §0 block was originally a mid-campaign safety
checkpoint (2026-07-11) and is retained for provenance.

**REMAINING items (operator's list, reconciled to ground truth):**
- **ethrex restart cliff — ✅ DONE (this session).** Bisected via controlled `stop eth1` → wait → `start`
  with a live prysm driving forkchoice: **12 min / 68 blk, 20 min / 108 blk, and 23 min / 124 blk all
  RESUMED cleanly** (imported the missed blocks, datadir intact, head climbed back to tip); **26 min /
  132 blk STUCK** (canonical head froze, `eth_syncing.currentBlock=0x0`, journal `Failed to fetch headers
  for sync head — peer(s) queried but did not serve headers`, no datadir collapse in-window). **Cliff edge =
  ~128 blk ≈ 24–25 min** — the ~128-block servable window. Recorded in the results doc §3a; headline #3 / §3
  below updated accordingly.
- **nimbus_eth1 anchor full-sync gamble — ✅ DONE (client-limitation).** Ran 2026-07-11→13 (run_id
  `client-bakeoff-nimbuseth1-2026-07-11`), hit the **72h governance cap** at 2026-07-13T23:12Z. Full-sync-only
  (no snap): ran **72h continuously with 0 restarts** (NRestarts=0, 20–25 peers) and reached **~40 GB datadir
  @ ~21.6%** (head 5,509,858 / target 25,505,378, eta ~1w3d still remaining) → never neared tip, recorded as a
  **client-limitation** (outside the pruned-comparable ranking), nimbus CL sweep auto-skipped as expected.
  **Bonus result:** `prune = true` is **empirically confirmed pruning online** (journal `Pruning history …
  pruned=N` logged continuously during import), settling the previously-contested lever. EL row + capsule
  filled in §4/results; blog finalized.
- **besu Stage B — ✅ DONE (with limitation), NOT a remaining test.** besu snap-synced to a fully validated
  head (~19h18m, un-pruned **~1.08 TiB**); the pruned re-run for a comparable disk number deadlocked twice
  and was **operator-abandoned** (2026-07-05, "accept limitation note"). Recorded as a client-limitation
  (excluded from the pruned-comparable disk ranking). See §4.

**Net: all tests complete.** The publishable blog is written at [`CLIENT_BAKEOFF_BLOG.md`](CLIENT_BAKEOFF_BLOG.md).
**Do not re-launch any client — the campaign is done.**

---

## 1. Headline findings (lead with these)

1. **Disk winner: Nethermind ~251 GiB** — ~4.6× smaller than geth's ~1.13 TiB, the smallest of any client
   that finished a *pruned-comparable* sync. This is the number to lead the disk story with.
2. **Speed winner: ethrex ~2h16m** — the fastest cold sync in the entire field, by a wide margin
   (next is geth at ~8.5h). A ~0%-adoption minimalist Rust client (Lambda Class) beat everyone on speed.
3. **The twist — ethrex's restart-resync cliff:** ethrex is fastest to sync but **throws away its entire
   synced state and re-syncs from scratch (~2h) after a long enough downtime.** The re-snap itself is
   directly verified (2h16m cold sync + a 2h11m re-snap both observed); the exact gap threshold that trips
   it is now **bisected to ~128 blocks ≈ 24–25 min** (2026-07-11: 23 min / 124 blk resumed cleanly,
   26 min / 132 blk stuck) — the true trigger is **header-fetch failure** once the gap exceeds the
   ~128-block servable window, not state expiry. This operability tax is a strong candidate explanation for
   why a client with the *best* cold-sync numbers has *near-zero* real-world adoption. (See §3 — this is the
   most novel finding of the campaign.)
4. **Restart resilience is a real, differentiating axis** — not just "does it sync" but "what happens after
   a restart." The clients split into three distinct behaviors (§3). This axis is underreported and is
   arguably more decision-relevant for operators than raw cold-sync numbers.

---

## 2. The data (of-record, as of 2026-07-06)

### EL scorecard (each paired with prysm)

| EL | Status | Sync time | Footprint | Sync mode | Mainnet share | One-line verdict |
|----|--------|-----------|-----------|-----------|--------------|------------------|
| **nethermind** | ✅ synced | ~14.5h | **~251 GiB** | snap + AncientBarrier prune | 36.0% | **Disk winner.** Pruned-comparable. |
| **ethrex** | ✅ synced | **~2h16m** | ~286 GiB at sync → **~467 GiB** (2026-07-06, still growing even at tip) | snap (v19.0.0) | 0.0% | **Speed winner.** Un-pruned + serves ~no history → limitation note, not ranked on disk. Restart cliff (§3). |
| **geth** | ✅ synced | ~8h28m | ~1.13 TiB | snap + `--history.chain postmerge` | 44.9% | Baseline. Rock-solid, resumes cleanly. |
| **besu** | ✅ synced (un-pruned) | ~19h18m | ~1.08 TiB (un-pruned) | snap / Bonsai | 17.4% | Synced, but pruned re-run deadlocked twice → limitation note (§4). |
| **reth** | ⏳ 72h cap | did not finish | ~0.98 TiB @ ~21% | full-sync-only (no snap) | 1.5% | Client limitation: no snap → too slow for 3-day window. |
| **nimbus_eth1** | ⏳ 72h cap | did not finish (0 restarts) | ~40 GB @ ~21.6% | full-sync-only (no snap) | ~0% | Client limitation: no snap → too slow for 3-day window. `prune=true` confirmed pruning online. |
| **erigon** | ❌ no-sync | deadlocked | no result | erigon3 OtterSync | 0.0% | Hard deadlock (§4). No footprint. |

### Rankings

- **Disk (pruned-comparable only — the honest ranking):** nethermind ~251 GiB → geth ~1.13 TiB. Only these
  two produced a pruned-comparable final footprint.
- **Disk (raw, all synced ELs, context only):** nethermind 251 GiB < ethrex ~467 GiB (growing) < besu 1.08 TiB
  (un-pruned) < geth 1.13 TiB. ethrex's footprint was ~286 GiB at sync completion but it prunes nothing — the
  datadir keeps growing **even at the chain tip with `eth_syncing=false`** (re-measured 403 → 416 → ~467 GiB
  across 2026-07-06, ~10 GiB/hr) *and* it serves almost no history (block lookups below head return `null`).
  So it is neither compact nor a full-history archive; it is kept OUT of the official ranking because its
  footprint is un-prunable and not steady-state (not apples-to-apples with a pruned node).
- **Sync speed (all synced ELs):** ethrex ~2h16m < geth ~8h28m < nethermind ~14.5h < besu ~19h18m. The two
  full-sync-only clients (reth, nimbus_eth1) never finish inside the 72h window.

---

## 3. Restart-resilience taxonomy (the novel framing)

Cold-sync numbers only tell you how a node behaves *once*, on day one. Operators restart nodes constantly —
upgrades, config changes, crashes, host maintenance. So "how does the client behave after a restart with a
gap?" is a first-class question the bake-off surfaced. Three distinct behaviors emerged:

1. **Graceful resume** — the client comes back up, imports the blocks it missed during the gap, and keeps
   its existing state on disk. No re-download, minutes to catch up.
   - **geth**, **nethermind**, **reth** — all three placed here on **design-level expectation, not directly
     measured** in this campaign (none had its restart-with-gap behavior bisected; to be empirically
     re-verified in the CL-sweep prep). This is what a production operator expects and what makes a client
     operationally boring (good).
2. **Re-snap cliff** — after a gap beyond a threshold (**~128 blocks ≈ 24–25 min for ethrex — bisected
   2026-07-11: 23 min / 124 blk resumed, 26 min / 132 blk stuck**), the client first **stalls with a
   disconnected head** (peers won't serve the gap headers) and, at larger gaps, **discards its fully synced
   state and re-syncs from scratch.**
   - **ethrex** (verified, §3a below). Fast the first time, brutal on every subsequent restart.
3. **Mid-sync deadlock** — if the CL stops driving the engine during an *in-progress* snap sync, the EL's
   pivot block ages out of the network's servable-state window and the sync wedges irrecoverably; the
   process stays alive (answers RPC) but makes zero progress.
   - **besu** (verified, §4). A fragility that only bites during an unfinished sync, but poisons the datadir
     when it does.

The common mechanism behind #2 and #3 is the same **~128-block / ~25-minute servable-state window**: full
nodes only serve recent world-state, so once your target/pivot ages past that window, you can no longer heal
missing trie nodes from peers. Graceful-resume clients sidestep this by importing gap *blocks* (always
available) rather than re-fetching *state*.

### 3a. ethrex restart-resync cliff (verified, the campaign's marquee finding)

**What happened:** after a routine ~1.5–2h restart gap, a fully-synced ethrex (286 GiB, at mainnet head)
**abandoned its state and began a fresh full snap sync from the current head.** Evidence chain (all
verified, not inferred):

- Restart was a plain `systemctl start eth1`; the unit's ExecStart is a persistent-datadir `--syncmode snap`
  with **no wipe/clean/reset flag** — ruling out a harness or unit artifact.
- Datadir collapsed **286 GiB → ~9 GiB → climbing** (state discarded, not resumed).
- Journal: `SNAP SYNC STARTED` → `PHASE 1/8: BLOCK HEADERS` starting from `Headers: 198,125 / 25,470,353`
  (near-genesis, not resuming from the prior ~25.47M head). `eth_blockNumber` returned `0x0` throughout.
- Re-sync ran the same full pipeline as the original ~2h16m cold sync.

**Root cause:** after the gap, ethrex's old head aged out of the servable-state window. When prysm
(optimistically at current head) drove `forkchoiceUpdated` forward, ethrex was too far behind to close the
gap by block import, so it re-pivoted to a fresh snap sync rather than resuming — throwing away the 286 GiB.

**Why it matters for the blog:** a client that re-syncs from scratch after any downtime beyond ~25 min is
operationally painful. Every upgrade, crash, or maintenance window longer than ~25 min costs a full ~2h
re-sync. This is a strong candidate explanation for ethrex's ~0% operational adoption *despite* its
best-in-field cold-sync numbers — "great benchmark, painful to actually run."

**Fairness caveats (state these; do not overclaim):**
- Observed on **v19.0.0** — ethrex is a young client and this may improve in future releases.
- The exact downtime threshold is now **bisected (2026-07-11, task #35 done):** gaps of 12 min / 68 blk,
  20 min / 108 blk and 23 min / 124 blk all resumed cleanly, while 26 min / 132 blk stuck (head froze,
  `Failed to fetch headers for sync head`). So the cliff edge is **~128 blocks ≈ 24–25 min** — the
  ~128-block servable window. The stuck disconnected-head is the *onset*; the full datadir-collapse re-snap
  is what the ~1.5–2h gap escalated to. The mechanism is **header-fetch failure beyond the servable window**,
  not state expiry per se.
- This does NOT change the recorded **sync-time** result (2h16m, captured at synced time) — the cliff is a
  **separate resilience/operability finding**, presented alongside, not folded into, the cold-sync number.
- **Reproduced independently on 2026-07-06:** a second restart triggered another full re-snap of **2h11m**
  (`SNAP SYNC STARTED` 01:58:29Z → complete 04:09:37Z; eth1 start 01:57:05Z) — a second measured data point for
  the cliff. The re-snapped datadir then rebuilt *past* the original 286 GiB to 403 → 416 → ~467 GiB (un-pruned,
  still growing **even at the chain tip with `eth_syncing=false`**, ~10 GiB/hr on 2026-07-06), confirming
  ethrex's footprint is not a fixed, reproducible number.

---

## 4. Stability findings (the "in production this bites you" stories)

### besu snap-sync is fragile to a prolonged CL outage (verified)
besu's pruned re-run deadlocked twice and was abandoned. The chain of causation is a good production
cautionary tale:
1. A stale **prysm v7.1.5** (PeerDAS/data-column-sidecar bug) stalled the CL for ~28h — besu logged
   `Execution engine not called in 120 seconds` continuously.
2. With the CL not driving `forkchoiceUpdated`, besu's snap-sync **pivot block aged out** of the servable
   window → the world-state heal became un-completable (peers can no longer serve the missing trie nodes).
3. besu threw `IllegalStateException: The pivot block number has not increased`, cancelled the two-stage
   fast-sync download, and the downloader **thread died without restarting.** The process stayed alive and
   still answered `eth_blockNumber`, but the sync engine was dead and the datadir frozen (zero DB writes).
4. A restart resumed on the same persisted stale pivot, healed a bit, then re-deadlocked identically.

**Takeaways:** (a) an in-progress besu snap sync is fragile to a prolonged CL outage — a stale CL binary can
poison the EL's pivot irrecoverably; (b) besu answering RPC ≠ besu syncing (judge by disk growth + DB
writes, not RPC liveness); (c) this is the strongest motivation for a harness **stall-watchdog** (campaign
task #31) that detects "0 DB writes while unsynced" and restarts with a pivot bump or fails cleanly.

Note the shared root with §3: besu's deadlock and ethrex's cliff are two faces of the same ~25-min
servable-state-window constraint — one hits *mid-sync* (besu), the other hits *post-sync on restart* (ethrex).

### erigon optimistic-sync deadlock (verified, no result)
erigon3's OtterSync plus a checkpoint-synced prysm produced a gap-close optimistic deadlock: erigon waits
for the CL to finalize while the CL waits for erigon to execute — zero progress, no footprint recorded. The
one hard no-sync of the EL sweep.

### Full-sync-only clients can't finish in 3 days (by design, not failure)
**reth** and **nimbus_eth1** have no snap-sync path — they full-sync from genesis. reth hit the 72h cap at
~21% (~0.98 TiB partial); nimbus_eth1 exited at ~10%. These are **client-design limitations**, reported
separately and NOT ranked against snap-sync clients — it would be unfair to rank a from-genesis full sync
against a snap sync on either time or disk.

---

## 5. Distribution nuance (avoid the tempting overclaim)

An early hypothesis was "mainnet distribution predicts syncability" — i.e. the low/zero-share clients are
exactly the ones that struggle. The data **partially** supports this but **ethrex breaks it**: a ~0%-share
minimalist client synced *fastest* in the field (its un-pruned, still-growing footprint keeps it out of the
disk ranking, so speed — not size — is its claim to fame). So the honest framing:

- Several minority clients did struggle — erigon (deadlock), reth & nimbus_eth1 (full-sync-only, too slow).
- But the real predictor is **snap-sync availability + client robustness**, not market share per se. ethrex
  has both (snap + clock-based stale-pivot self-healing during the initial sync) and excelled on cold sync.
- ethrex's *adoption* gap is better explained by the restart cliff (§3) than by any cold-sync deficiency.

Do not write "distribution predicts syncability" flatly — write the nuanced version.

## 6. Pairing is a non-factor for EL disk/speed
An EL's footprint and sync time are EL-only properties, decoupled from the CL over the Engine API. There is
no "magic pair." The only cross-client coupling observed is the optimistic-sync deadlock risk (erigon), which
is about sync *liveness*, not disk/speed. This is why holding CL=prysm constant for the EL scorecard is valid.

## 7. Methodology integrity (a story in itself)
Every recorded row is now stamped `config_optimal=yes|no` by a harness **config-optimality gate** (WS4): the
gate inspects the actually-generated/running config and refuses to trust a footprint taken from a
mis-configured client. This exists because earlier in the campaign we corrupted our own results by recording
footprints before verifying the config was in its most disk-efficient mode. Worth telling as "how we kept
ourselves honest" — including that the gate itself needed 6 bug-fixes across 3 review rounds before it was
trustworthy. The bake-off's credibility rests on this gate.

---

## 8. Per-client capsules (for the write-up)

- **geth** — the boring, correct baseline. ~8.5h snap sync, ~1.13 TiB with post-merge history prune,
  resumes cleanly across restarts. 44.9% share. If you don't have a reason to run something else, run this.
- **nethermind** — the disk champion at ~251 GiB (4.6× smaller than geth), ~14.5h sync, clean restart
  behavior. 36% share. The pick when disk is the constraint.
- **ethrex** — the sprinter with a glass jaw. Fastest cold sync (~2h16m), but an un-pruned datadir that keeps
  growing **even at the chain tip with `eth_syncing=false`** (~286 GiB at sync → ~467 GiB on 2026-07-06,
  ~10 GiB/hr) while serving *almost no history*, plus the restart-resync cliff (§3), makes it operationally
  costly. Fascinating, young (v19.0.0), one to watch.
- **besu** — enterprise Java client; does sync (~19h un-pruned) but its snap sync is fragile to CL outages
  (§4) and the pruned-comparable number never landed. Careful operational handling required.
- **reth** — high-performance Rust, but full-sync-only means it can't finish a mainnet sync in 3 days.
  A design limitation for this benchmark, not a defect.
- **nimbus_eth1** — lightweight Nim, also full-sync-only (no snap); exited mid-sync. Same limitation class.
- **erigon** — the one hard deadlock; OtterSync + checkpoint-synced CL wedged with zero progress.

## 9. CL matrix — ✅ COMPLETE (both anchors, ranking reproduced)
The CL matrix (**lighthouse, teku, nimbus-CL, lodestar, grandine**) is done and of-record — full scorecard
in [`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md). All five CLs **checkpoint-synced to a fully
validating head in ~22–23 min** (`config_optimal=yes`, `anchor_synced=yes`, zero crashes), so sync *time* is
effectively tied and **CL datadir footprint is the differentiator.** It was run against two anchors to prove
EL/CL decoupling:
- **ethrex anchor** (run_id `client-bakeoff-clsweep-2026-07-06`) — reused the already-synced ethrex datadir
  at tip (zero anchor-sync cost); all five CL footprints are <1% of the ~502 GB EL datadir.
- **geth anchor** cross-anchor confirmation (run_id `client-bakeoff-anchor-rotation-2026-07-07`, 2026-07-08).
  **geth-anchor CL disk ranking (smaller = better): lodestar (~177 MiB) < lighthouse (~518 MiB) <
  grandine (~725 MiB) < teku (~936 MiB) < nimbus (~1.2 GiB).**

**Cross-anchor verdict — the ranking reproduces:** the heavyweight tier (nimbus largest, teku second) and
the lightweight tier (lodestar / lighthouse / grandine smallest) hold on both anchors; only the
lodestar↔lighthouse order flips within the smallest tier. Absolute sizes scale with post-sync observation
time, not the EL anchor. Two different EL anchors → the same CL ranking = **EL/CL decoupling confirmed
empirically.** (The nimbus_eth1 anchor now running is a *third* EL anchor, but as a full-sync-only client it
won't reach tip in 72h → it yields a partial EL footprint, not a new CL sweep.)

---

## 10. Blog structure suggestion (for later)
1. Hook: the fastest client to sync is one almost nobody runs — here's why (ethrex cliff teaser).
2. What we measured + how we kept it honest (methodology + the config-optimality gate).
3. The disk story: nethermind wins, by a lot.
4. The speed story: ethrex wins, by a lot.
5. The restart-resilience axis (the novel part): the three behaviors, with ethrex's cliff and besu's
   deadlock as the two vivid cases.
6. Distribution nuance: why market share doesn't cleanly predict syncability.
7. Recommendations: geth (default), nethermind (disk-constrained), + operational caveats for the rest.
8. CL matrix results (once available) + final EL+CL recommendation.
