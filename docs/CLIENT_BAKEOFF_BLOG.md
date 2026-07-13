# The Fastest Ethereum Client Is One Almost Nobody Runs

*A full-field execution- and consensus-client bake-off — what we measured, and the operability findings that the raw sync numbers hide.*

We ran every execution client (EL) and consensus client (CL) that [eth2-quickstart](https://github.com/chimera-defi/eth2-quickstart) supports through the same mainnet sync, on the same host, one at a time, and recorded two numbers for each: **final synced disk footprint** and **sync duration**. Simple premise. The interesting part is what fell out of it — an operability axis (what a client does *after a restart*) that turns out to be more decision-relevant than either headline number, and which explains a genuine paradox: the client that synced *fastest* in the whole field is one with essentially **zero** real-world adoption.

## TL;DR

- **Disk winner — Nethermind, ~251 GiB.** ~4.5× smaller than geth, and the smallest of any client that finished a *pruned, apples-to-apples* sync.
- **Speed winner — ethrex, ~2h16m.** Fastest cold sync in the field by a wide margin (next is geth at ~8.5h). A ~0%-adoption minimalist Rust client beat everyone.
- **The twist — ethrex's restart-resync cliff.** ethrex is fastest to sync but **throws away its synced state and re-syncs from scratch (~2h) after a downtime gap past a hard edge we bisected to ~128 blocks (≈24–25 min).** That operability tax is the best explanation we found for why the fastest-syncing client is one almost nobody runs.
- **Restart resilience is a real, under-reported axis.** Clients split into three distinct behaviors after a restart-with-gap. This matters more to a running operator than cold-sync numbers.
- **The CL layer is effectively solved.** All five consensus clients checkpoint-synced to a validating head in ~22–23 minutes with zero failures; footprint is the only differentiator. Operational risk lives in the **EL** layer.

---

## What we measured, and how we kept it honest

The bake-off measures, for each client, the **final synced disk footprint** and the **sync duration**, on a shared semi-production host (not a live validator), with MEV disabled and no validator keys. One candidate at a time, a 72-hour cap per candidate, and the footprint taken from the last near-cap `du` sample — never the peak mid-sync.

For the EL scorecard we hold the CL constant at **prysm**. That is defensible because an EL's footprint and sync time are EL-only properties, decoupled from the CL across the Engine API — the prysm datadir is ~0.65–1.68 GB, negligible against an EL's hundreds of gigabytes. We confirmed the decoupling empirically later (see the CL matrix), so this isn't just an assumption.

**The honesty mechanism.** Early in the campaign we corrupted our own results by recording footprints *before* verifying each client was running in its most disk-efficient mode. A benchmark that measures your misconfiguration instead of the client is worse than no benchmark. So we built a **config-optimality gate** into the harness: it inspects the actually-generated, actually-running config and refuses to trust a footprint from a mis-configured client, stamping every row `config_optimal=yes|no`. The gate itself needed six bug-fixes across three review rounds before we trusted it — which is the point. Every number below is stamped optimal.

A knock-on benefit of that gate: it forced us to *empirically settle* config questions we'd otherwise have guessed at. The clearest example is nimbus_eth1's history-pruning flag (below), where the binary's `--help` and the online docs flatly contradicted each other — and only a live run resolved it.

---

## The disk story: Nethermind wins, by a lot

Only two clients produced a **pruned, apples-to-apples** footprint — geth and nethermind — so the honest head-to-head disk ranking is exactly those two:

| EL | Footprint (pruned-comparable) | Sync time | Mode | Mainnet share |
|----|------|------|------|------|
| **Nethermind** | **~251 GiB** | ~14.5h | snap + ancient-barrier prune | 36.0% |
| geth | ~1.13 TiB | ~8h28m | snap + `--history.chain postmerge` | 44.9% |

Nethermind's Bonsai flat-DB plus snap sync lands it at roughly a quarter of geth's size. It's also a minority client, so choosing it modestly improves mainnet client diversity — a nice-to-have on top of the disk win. The cost is sync time: ~14.5h vs geth's ~8.5h. If disk is your binding constraint, this is the pick.

Everything else is *not* pruned-comparable, for a specific reason each, and we refuse to rank those on disk against a pruned node — that would be measuring different things. They're recorded transparently as client limitations:

| EL | Result | Why it's outside the disk ranking |
|----|--------|-----------------------------------|
| besu | ✅ synced, ~1.08 TiB (un-pruned), ~19h18m | Synced cleanly, but the pruned re-run for a comparable number deadlocked twice (below). Un-pruned → history-inflated. |
| ethrex | ✅ synced, ~286 GiB → ~467 GiB *growing*, ~2h16m | Un-pruned **and** serves almost no history; datadir grows even at tip. Neither compact nor a full archive. Speed is its claim, not size. |
| reth | ⏳ 72h cap at ~21%, ~0.98 TiB partial | Full-sync-only (no snap) — can't reach tip in a practical window. |
| nimbus_eth1 | ⏳ 72h cap at ~21.6%, ~40 GB partial | Full-sync-only (no snap). Pruning *works* (below), but it can't finish in 72h. |
| erigon | ❌ deadlocked, no result | Optimistic-sync deadlock against a checkpoint-synced CL (below). |

**"Outside the disk ranking" does not mean "failed to sync."** besu in particular synced to a fully-validating head — it's here only because we don't have a pruned-comparable number for it.

---

## The speed story: ethrex wins, by a lot — and then loses it on restart

ethrex snap-synced to a fully-validating head in **~2h16m**, the fastest in the field by nearly 4×. Fifty peers throughout, one automatic stale-pivot self-heal (~4 min, no intervention), no crash. On paper it's the star.

Two things keep it out of the winners' circle:

1. **The footprint isn't a fixed number.** ethrex prunes nothing and the datadir keeps growing *even at the chain tip with `eth_syncing=false`* — we watched it climb 286 → 403 → 416 → ~467 GiB across a single day (~10 GiB/hr) — while simultaneously serving almost no history (`eth_getBlockByNumber` returns `null` below head). So it is neither compact nor a full-history archive, and there's no steady-state size to rank.
2. **The restart cliff** — which is the marquee finding of the whole campaign, so it gets its own section.

---

## The novel axis: restart resilience

Cold-sync numbers tell you how a node behaves *once*, on day one. But operators restart nodes constantly — upgrades, config changes, crashes, host maintenance. "What happens after a restart with a gap?" is a first-class operational question, and it cleanly separates the field into three behaviors:

**1. Graceful resume.** The client comes back, imports the blocks it missed during the gap, and keeps its on-disk state. Minutes to catch up, no re-download. This is what makes a client operationally *boring*, in the good way — geth, nethermind, and reth are expected here by design (we call this out as design-level expectation; we bisected only ethrex's behavior directly).

**2. Re-snap cliff.** Past a downtime threshold the client **discards its fully-synced state and re-syncs from scratch.** Only ethrex lands here — and we pinned the edge precisely.

**3. Mid-sync deadlock.** If the CL stops driving the engine during an *in-progress* snap sync, the EL's pivot ages out of the network's servable-state window and the sync wedges irrecoverably — the process stays alive and answers RPC but makes zero progress. besu is the cautionary tale here.

Behaviors 2 and 3 share one root cause: a full node only serves recent world-state (roughly a **~128-block window**). Once your head or pivot ages past it, peers can no longer serve the state you need to heal, so you can't resume by state — you're forced to re-pivot. Graceful-resume clients dodge this by importing gap *blocks* (always available) instead of re-fetching *state*.

### ethrex's cliff, bisected

After a routine ~1.5–2h restart gap, a fully-synced ethrex (286 GiB, at mainnet head) abandoned its state and began a fresh full snap sync from the current head — datadir collapsing 286 GiB → ~9 GiB → climbing, journal showing `SNAP SYNC STARTED` from near-genesis, `eth_blockNumber` at `0x0` throughout. It re-ran the entire ~2h pipeline. We reproduced it independently: a second restart triggered another full re-snap, timed at **2h11m** — a clean second data point.

The obvious follow-up: *how big a gap actually trips it?* We bisected it with controlled stop → wait → start cycles, a live prysm driving forkchoice:

| Downtime gap | Blocks missed | Outcome |
|---|---|---|
| 12 min | 68 | ✅ resumed cleanly |
| 20 min | 108 | ✅ resumed cleanly |
| 23 min | 124 | ✅ resumed cleanly |
| 26 min | 132 | ❌ **stuck** — head froze, `Failed to fetch headers for sync head` |

**The cliff edge is ~128 blocks ≈ 24–25 minutes.** And the bisection corrected our understanding of the mechanism: the true trigger is **header-fetch failure** once the gap exceeds the ~128-block servable window — not "state expiry" per se. Just past the edge, ethrex first *stalls with a disconnected head* (peers won't serve the gap headers); at larger gaps (~1.5–2h) that escalates to the full datadir-collapse re-snap. The stuck head is the onset; the re-snap is where it ends up.

**Why it matters:** a client that re-syncs from scratch after any downtime beyond ~25 minutes is genuinely painful to operate — every upgrade or maintenance window longer than that costs a ~2h re-sync. That's a strong candidate explanation for ethrex's ~0% adoption *despite* best-in-field cold-sync numbers: great benchmark, painful to actually run.

**Fairness caveats (we state these plainly):** observed on ethrex **v19.0.0**, a young client — this may well improve. The cliff does not change the recorded sync-*time* result; it's a separate resilience finding presented alongside, not folded into, the cold-sync number.

### besu's mid-sync deadlock

besu's pruned re-run deadlocked twice and was abandoned — and the causal chain is a tidy production cautionary tale:

1. A stale **prysm v7.1.5** (a PeerDAS/data-column-sidecar bug) stalled the CL for ~28h; besu logged `Execution engine not called in 120 seconds` continuously.
2. With no `forkchoiceUpdated` driving it, besu's snap-sync **pivot aged out** of the servable window — the world-state heal became un-completable.
3. besu threw `IllegalStateException: The pivot block number has not increased`, cancelled its fast-sync download, and the downloader **thread died without restarting.** The process stayed alive and still answered `eth_blockNumber` — but the sync engine was dead and the datadir frozen.
4. Restarting resumed on the same stale pivot and re-deadlocked identically.

Takeaways: an in-progress besu snap sync is fragile to a prolonged CL outage — a stale CL binary can poison the EL's pivot irrecoverably; and **besu answering RPC ≠ besu syncing** (judge by disk growth and DB writes, not RPC liveness). Note the shared root with ethrex's cliff: same ~128-block servable-state window, one hitting mid-sync, the other post-sync-on-restart.

---

## The full-sync-only clients — and a contested flag, settled

**reth** and **nimbus_eth1** have no snap-sync path; they full-sync from genesis. Both hit the 72h cap far from tip (reth ~21%, ~0.98 TiB; nimbus_eth1 ~21.6%, ~40 GB). This is a **client-design limitation for our snap-to-tip bar, not a failure** — it would be unfair to rank a from-genesis full sync against a snap sync on either time or disk. reth in particular is widely and successfully run elsewhere.

nimbus_eth1 did settle one open question for us. Its config carries `prune = true`, and whether that flag actually does anything was genuinely contested: the binary's `--help` claims it prunes expired bodies and receipts, while the online docs say pre-merge history needs a separate era1 export — i.e. that the flag is effectively inert. We'd flagged it "unverified." The 72-hour run answered it directly: the journal logged **continuous online pruning** (`Pruning history … pruned=N`) throughout block import. So the flag is **not** inert — nimbus_eth1 prunes history online as it syncs. (Whether it reaches full pre-merge completeness versus an era1 import stays untestable here, since the node never reached tip — but the "does it do anything?" question is now a clean *yes*.) As a bonus data point, that run stayed up 72 hours with zero restarts: stable, just slow by design.

**erigon** was the one hard deadlock: erigon3's OtterSync plus a checkpoint-synced prysm wedged in a mutual wait — erigon waiting for the CL to finalize, the CL waiting for erigon to execute — zero progress, no footprint. The single no-sync of the EL sweep.

---

## Distribution is a *nuanced* predictor, not a flat one

A tempting story going in was "mainnet share predicts syncability" — the low/zero-share clients are exactly the ones that struggle. The data only half-supports it, and **ethrex breaks it outright**: a ~0%-share minimalist client synced *fastest* in the entire field. Several minority clients did struggle (erigon's deadlock; reth and nimbus_eth1 too slow by design), but the real predictor is **snap-sync availability plus client robustness**, not market share per se. ethrex has snap sync and clock-based stale-pivot self-healing during the initial sync — and it excelled at cold sync. Its *adoption* gap is far better explained by the restart cliff than by any sync deficiency. Don't write the flat version.

---

## The consensus layer is solved

We ran the five CLs — **lighthouse, lodestar, grandine, teku, nimbus** — against a constant anchor EL, and then repeated it against a *second* anchor EL to test the EL/CL decoupling claim directly. Every CL checkpoint-synced to a fully-validating head in **~22–23 minutes**, `config_optimal=yes`, zero crashes. Sync *time* is effectively tied, so **footprint is the differentiator**:

| CL | Footprint (geth anchor) |
|----|------|
| lodestar | ~177 MiB |
| lighthouse | ~518 MiB |
| grandine | ~725 MiB |
| teku | ~936 MiB |
| nimbus | ~1.2 GiB |

Crucially, the ranking **reproduced across both anchor ELs** — the heavyweight tier (nimbus, teku) and the lightweight tier (lodestar, lighthouse, grandine) held on both, with only a lodestar↔lighthouse flip within the smallest tier. Two different EL anchors, the same CL ranking: **EL/CL decoupling, confirmed empirically** — which retroactively validates holding CL=prysm constant for the whole EL scorecard.

The punchline: on the CL side, all five are operationally effective — none failed, and the choice comes down to footprint and preference (lighthouse is the lean, safe default). **Operational risk in an Ethereum node lives in the EL layer, not the CL layer.**

---

## Recommendations

- **Default: geth.** Largest ecosystem, most documentation, the cleanest snap sync (~8.5h), and it resumes gracefully across restarts. You pay for it in disk (~1.13 TiB). If you don't have a specific reason to run something else, run this.
- **Disk-constrained: nethermind.** ~251 GiB — 4.5× leaner than geth — with clean restart behavior and a client-diversity bonus. Costs you sync time (~14.5h).
- **Consensus client: lighthouse** as the lean default; any of the five is operationally fine — pick on footprint and familiarity.
- **Watch, don't yet deploy: ethrex.** Fascinating and fastest, but the un-pruned/growing footprint and the ~25-minute restart cliff make it operationally costly today. Young (v19.0.0) — worth revisiting.
- **Enterprise with care: besu.** It syncs, but its snap sync is fragile to CL outages; handle upgrades and CL health deliberately.
- **Know the design limits:** reth and nimbus_eth1 are full-sync-only — excellent clients, but plan for a long initial sync rather than snap-to-tip. Avoid erigon3 + a checkpoint-synced CL until the optimistic-sync deadlock is resolved.

The most useful thing this bake-off surfaced isn't a single winner — it's that **the number that matters to a running operator is often not the one on the benchmark chart.** Cold-sync time and disk footprint are easy to measure and easy to publish. Restart resilience is neither, and it's the axis that most cleanly explains which clients people actually keep running.

---

*Raw per-run data, every measured footprint and sync time, and the full incident log live alongside this post in [`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md) and [`CLIENT_BAKEOFF_ISSUES_LOG.md`](CLIENT_BAKEOFF_ISSUES_LOG.md). Every headline number is stamped `config_optimal=yes` by the harness gate described above.*
