# The Fastest Ethereum Client Is One Almost Nobody Runs

*A full-field execution- and consensus-client bake-off — what we measured, and the operability findings that the raw sync numbers hide.*

> **Companion post:** [How We Ran a 23-Day Ethereum Client Bake-Off With Claude](HOW_WE_TESTED_WITH_CLAUDE.md) — the agent orchestration, the harness, and the methodology behind these numbers.

We ran every execution client (EL) and consensus client (CL) that [eth2-quickstart](https://github.com/chimera-defi/eth2-quickstart) supports through the same mainnet sync, on the same host, one at a time, and recorded two numbers for each: **final synced disk footprint** and **sync duration**. Simple premise. The interesting part is what fell out of it — an operability axis (what a client does *after a restart*) that turns out to be more decision-relevant than either headline number, and which explains a genuine paradox: the client that synced *fastest* in the whole field is one with essentially **zero** real-world adoption.

## TL;DR

- **Disk: there is no winner — the field converges.** Every EL that carries full post-merge history lands at ~1.0–1.2 TiB (geth 1.13, nethermind ~1.06, besu 1.08 TiB) — disk size is set by history-retention config, not client efficiency. Nethermind's early ~251 GiB reading was a pre-backfill snap-sync-tip snapshot, not its steady state. ethrex plateaus lower still (~470–476 GiB), but only because it retains no history at all — not a disk win.
- **Speed winner — ethrex, ~2h16m.** Fastest cold sync in the field by a wide margin (next is geth at ~8.5h). A ~0%-adoption minimalist Rust client beat everyone.
- **The twist — ethrex's restart-resync cliff.** ethrex is fastest to sync, but a gap just beyond the ~128-block (≈24–25 min) edge stalled instead of resuming, and measured 1.5–2h gaps **discarded its synced state and triggered a full re-snap (~2h).** That operability tax is the best explanation we found for why the fastest-syncing client is one almost nobody runs.
- **Restart resilience is a real, under-reported axis.** Clients split into three distinct behaviors after a restart-with-gap. This matters more to a running operator than cold-sync numbers.
- **The CL layer is effectively solved.** All five consensus clients checkpoint-synced to a validating head in ~22–23 minutes with zero failures; footprint is the only differentiator. Operational risk lives in the **EL** layer.

---

## The scorecard at a glance

**Execution clients (EL)** — each run against a fixed prysm, one at a time, 72h cap:

| EL | Result | Sync time | Footprint | Sync mode | Mainnet share |
|----|--------|-----------|-----------|-----------|---------------|
| **nethermind** | ✅ synced | ~14.5h | **~1.06 TiB** steady-state (~251 GiB at snap-sync, pre-backfill) | snap + Halite | 36.0% |
| **geth** | ✅ synced | ~8h28m | ~1.13 TiB (pruned) | snap + `--history.chain postmerge` | 44.9% |
| **ethrex** | ✅ synced | **~2h16m** — fastest | **~470–476 GiB** steady-state plateau (no-history; ~286–300 GiB at snap-sync) | snap (v19.0.0 at sync; v22.0.0 steady-state) | ~0% |
| **besu** | ✅ synced (un-pruned) | ~19h18m | ~1.08 TiB (un-pruned) | snap / Bonsai | 17.4% |
| **reth** | ⏳ 72h cap (~21%) | did not finish | ~0.98 TiB (partial) | full-sync-only | 1.5% |
| **nimbus_eth1** | ⏳ 72h cap (~21.6%) | did not finish | ~40 GB (partial) | full-sync-only | ~0% |
| **erigon** | ❌ no-sync | deadlocked | — | OtterSync | ~0% |

Disk: geth (~1.13 TiB), nethermind (~1.06 TiB steady-state), and besu (~1.08 TiB) all converge in the same band once full post-merge history is retained — there's no meaningful ranking to draw there. Speed, among those that finished: **ethrex (~2h16m) < geth (~8h28m) < nethermind (~14.5h) < besu (~19h18m)** — that's the axis that actually separates the field, along with restart-resume behavior. The other three fall out for a specific, documented reason each (below), not a blanket failure.

**Consensus clients (CL)** — each run against a fixed EL anchor; **all five synced** to a validating head in minutes, so footprint is the only differentiator:

| CL | Footprint (geth anchor) | Footprint (nethermind anchor) | History-prune lever |
|----|-------------------------|--------------------------------|---------------------|
| **lodestar** | **~177 MiB** — smallest | **~178 MiB** — smallest | `pruneHistory=true` |
| **lighthouse** | ~518 MiB | ~470 MiB | `checkpoint-sync-url` |
| **grandine** | ~725 MiB (actual) | ~730 MiB (actual) | `--prune-storage` (critical) |
| **teku** | ~936 MiB | ~848 MiB | `data-storage-mode=minimal` |
| **nimbus** | ~1.2 GiB — largest | ~1.3 GiB — largest | `history=prune` |

The three tiers — lightweight {lodestar, lighthouse}, mid {teku, grandine}, heavy {nimbus} — reproduced across three different EL anchors (ethrex, geth, and nethermind), with lodestar and lighthouse swapping which one is smallest by anchor (lighthouse smallest on ethrex; lodestar smallest on geth and nethermind) — empirical support for EL/CL decoupling without claiming an identical total order. The rest of this post is the *why* behind these numbers.

---

## What we measured, and how we kept it honest

The bake-off measures, for each client, the **final synced disk footprint** and the **sync duration**, on a shared semi-production host (not a live validator), with MEV disabled and no validator keys. One candidate at a time, a 72-hour cap per candidate, and the footprint taken from the last near-cap `du` sample — never the peak mid-sync.

For the EL scorecard we hold the CL constant at **prysm**. That is defensible because an EL's footprint and sync time are EL-only properties, decoupled from the CL across the Engine API — the prysm datadir ran ~0.65–1.68 GB in the bounded runs (up to ~12.5 GB during reth's full 72h cap), still negligible against an EL's hundreds of gigabytes. We confirmed the decoupling empirically later (see the CL matrix), so this isn't just an assumption.

**The honesty mechanism.** Early in the campaign we corrupted our own results by recording footprints *before* verifying each client was running in its most disk-efficient mode. A benchmark that measures your misconfiguration instead of the client is worse than no benchmark. So we built a **config-optimality gate** into the harness: it inspects the actually-generated, actually-running config and refuses to trust a footprint from a mis-configured client, stamping every row `config_optimal=yes|no`. The gate itself needed six bug-fixes across three review rounds before we trusted it — which is the point. Every number below is stamped optimal.

A knock-on benefit of that gate: it forced us to *empirically settle* config questions we'd otherwise have guessed at. The clearest example is nimbus_eth1's history-pruning flag (below), where the binary's `--help` and the online docs flatly contradicted each other — and only a live run resolved it.

---

## The disk story: there is no winner — the field converges

Nethermind's synced-tip snapshot read ~251 GiB, well below geth's ~1.13 TiB — but that number was taken before nethermind's FastBlocks finished backfilling post-merge block bodies and receipts. Its steady-state datadir (re-measured 2026-08-01) is **~1.06 TiB (~1,088 GiB)**: state ~226–230 GiB (its compact Halite/Paprika flat storage) plus ~843 GiB of post-merge bodies and receipts plus ~19 GiB of headers and code, the same history geth keeps under `--history.chain postmerge`. Under matched history-retention configs, nethermind and geth are on par:

| EL | Footprint (full post-merge history) | Sync time | Mode | Mainnet share |
|----|------|------|------|------|
| **Nethermind** | **~1.06 TiB** steady-state (~251 GiB at snap-sync, pre-backfill) | ~14.5h | snap + Halite/Paprika | 36.0% |
| geth | ~1.13 TiB | ~8h28m | snap + `--history.chain postmerge` | 44.9% |
| besu | ~1.08 TiB (un-pruned) | ~19h18m | snap / Bonsai | 17.4% |

besu lands in the same band too — the same order of magnitude, not an outlier. So three ELs with full post-merge history — geth (1.13), nethermind (~1.06), besu (1.08) — converge on roughly the same footprint. Disk size here is set by a client-agnostic knob (how much post-merge history you retain), not by client efficiency, so it isn't a good axis for picking a winner. Nethermind is still a strong pick — compact flat-storage state, restart-resume now measured (2026-08-01), and a minority-client diversity bonus — just not because of a disk-size win.

Everything else hasn't reached a finished, comparable footprint, for a specific reason each. They're recorded transparently as client limitations:

| EL | Result | Why it's outside a clean comparison |
|----|--------|-----------------------------------|
| ethrex | ✅ synced, **~470–476 GiB plateau** (no-history), ~2h16m | Un-pruned **and** serves almost no history; datadir plateaus (drifting 470.2 → 475.5 GiB over ~42h), doesn't grow unbounded (confirmed 2026-07-28→31). Neither compact nor a full archive — smaller only because it retains nothing, not a disk win. Speed is its claim, not size. |
| reth | ⏳ 72h cap at ~21%, ~0.98 TiB partial | Full-sync-only (no snap) — can't reach tip in a practical window; projects to ~1.1–1.2 TiB finished, the same convergence band. |
| nimbus_eth1 | ⏳ 72h cap at ~21.6%, ~40 GB partial | Full-sync-only (no snap). Pruning *works* (below), but it can't finish in 72h. |
| erigon | ❌ deadlocked, no result | Optimistic-sync deadlock against a checkpoint-synced CL (below). |

**besu's open issue is operational, not its disk size:** it *did* sync cleanly to a fully-validating head; a follow-up re-run testing a further prune lever deadlocked twice and was abandoned (below) — its snap sync is fragile to a prolonged CL outage, which is the real asterisk next to its name.

**What ethrex's no-history design costs, concretely.** This repo ships an nginx/Caddy feature for exposing a node's RPC publicly, so the gap matters beyond a benchmark footnote. Probed live against the running node (2026-07-29), the servable window's back edge is *exactly* the snap-sync pivot block — `eth_getBlockByNumber` returns `null` one block before it and resolves cleanly at and after it, and it never backfills. Current-state calls (balances, current quotes, allowances) work fine, but any block, log, or receipt before the pivot fails outright — effectively all of Ethereum history — ruling out indexer/subgraph backfill, portfolio history, and tax/accounting exports. A geth endpoint with `--history.chain postmerge` serves that same history; an ethrex endpoint does not, so it isn't a drop-in replacement for a public DeFi-facing RPC. (Full probe detail, including the exact pivot block and the tighter ~128-block state window, is in `CLIENT_BAKEOFF_RESULTS.md`'s gotchas.)

---

## The speed story: ethrex wins, by a lot — and then loses it on restart

ethrex snap-synced to a fully-validating head in **~2h16m**, the fastest in the field by nearly 4×. Fifty peers throughout, one automatic stale-pivot self-heal (~4 min, no intervention), no crash. On paper it's the star.

Two things keep it out of the winners' circle:

1. **The footprint is settled now, and it's not comparable.** ethrex prunes nothing, and we watched the datadir climb even at the chain tip with `eth_syncing=false` (286 → 403 → 416 → ~467 GiB across a single day, ~10 GiB/hr, 2026-07-06) — but a follow-up run confirmed that climb was settling, not unbounded: it plateaus at **~470–476 GiB** (drifting 470.2 → 475.5 GiB over ~42 hours at +0.13 GiB/hr, 2026-07-28→31). That still isn't a disk win, because it simultaneously serves almost no history (`eth_getBlockByNumber` returns `null` below its snap pivot). So it is neither compact nor a full-history archive — its settled size just isn't rankable against the full-history clients above. On a state-only basis it isn't even smallest: nethermind's state alone is ~226–230 GiB, roughly half ethrex's entire total (not a perfectly controlled comparison — different state encodings, and ethrex's total also includes headers/recent blocks).
2. **The restart cliff** — which is the marquee finding of the whole campaign, so it gets its own section.

---

## The novel axis: restart resilience

Cold-sync numbers tell you how a node behaves *once*, on day one. But operators restart nodes constantly — upgrades, config changes, crashes, host maintenance. "What happens after a restart with a gap?" is a first-class operational question, and it cleanly separates the field into three behaviors:

**1. Graceful resume.** The client comes back, imports the blocks it missed during the gap, and keeps its on-disk state. Minutes to catch up, no re-download. This is what makes a client operationally *boring*, in the good way. We **measured** this directly for **geth**: restarted after a ~52-hour gap, it kept its full datadir and caught up purely by sequential block-import (trie-diff application) — never re-snapping — and converged back to the validating tip. That's the exact positive contrast to ethrex's cliff. **nethermind's** resume is now measured too — **reth** remains expected-by-design but unmeasured.

**nethermind's resume, measured (2026-08-01).** An opportunistic catch-up, not a controlled bisection: a CL restart at 13:24:55Z left nethermind **10,607 blocks (~35h of chain) behind** the external tip. It closed the entire gap by ordinary block import in **35m09s (~307 blocks/min)**; the beacon dropped `is_optimistic` at 14:00:04Z. The datadir grew 1.165 → 1.178 TB (+1.1%, exactly the imported bodies/receipts) — no state wipe, no re-snap. That's ~80× past ethrex's ~128-block re-snap cliff, and it matches geth's resume behavior. A separate establish run the day before (2026-07-31) snap-synced nethermind fresh in **1h52m51s** (~280 GiB at snap, pivot 25,649,064, zero restarts) — far faster than the ~14.5h Stage-B figure because the pivot was minutes-old and near-tip, and network conditions differ; a second data point under different conditions, not a replacement for the Stage-B number. Artifacts: exp-lab run `exp-a-nethermind-restart-resume-2026-07-31`.

**2. Re-snap cliff.** Past a downtime threshold ethrex first **stalls with a disconnected head**; in the longer measured gaps it discarded its fully-synced state and re-synced from scratch. Only ethrex lands here — and we pinned the onset precisely.

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

**Why it matters:** a client that can stop resuming after ~25 minutes and, on longer measured gaps, fall into a ~2h re-snap is genuinely painful to operate. That's a strong candidate explanation for ethrex's ~0% adoption *despite* best-in-field cold-sync numbers: great benchmark, painful to actually run.

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

We ran the five CLs — **lighthouse, lodestar, grandine, teku, nimbus** — against a constant anchor EL, then repeated it against two further anchor ELs to test the EL/CL decoupling claim directly. Every CL checkpoint-synced to a fully-validating head in minutes — **~22–23 min on the ethrex anchor, ~6–9 min on the geth anchor** (whose footprints are tabulated below), and **~7–10 min on the nethermind anchor** — `config_optimal=yes`, zero crashes. Sync *time* is effectively tied within each anchor, so **footprint is the differentiator**:

| CL | Footprint (geth anchor) | Footprint (nethermind anchor) |
|----|------|------|
| lodestar | ~177 MiB | ~178 MiB |
| lighthouse | ~518 MiB | ~470 MiB |
| grandine | ~725 MiB (actual) | ~730 MiB (actual) |
| teku | ~936 MiB | ~848 MiB |
| nimbus | ~1.2 GiB | ~1.3 GiB |

Crucially, the broad tiers **reproduced across all three anchor ELs** — the mid tier (teku, grandine) and the lightweight tier (lodestar, lighthouse), with nimbus alone at the heavy end — held on all three, with a lodestar↔lighthouse flip within the lightweight tier (lighthouse smallest on ethrex; lodestar smallest on geth and nethermind); grandine stays below teku on every anchor, so there is no genuine grandine↔teku swap — the apparent crossing was teku's own ~667→~848 MiB re-read variance on the nethermind anchor. Three different EL anchors, the same CL tiers: **EL/CL decoupling, supported empirically** — which retroactively validates holding CL=prysm constant for the whole EL scorecard.

The punchline: on the CL side, all five are operationally effective — none failed, and the choice comes down to footprint and preference (lighthouse is the lean, safe default). **Operational risk in an Ethereum node lives in the EL layer, not the CL layer.**

---

## Recommendations

- **Default: geth.** Largest ecosystem, most documentation, the cleanest snap sync (~8.5h), and it resumes gracefully across restarts. Its disk footprint (~1.13 TiB) is on par with the other ELs that carry full post-merge history — not a downside unique to geth. If you don't have a specific reason to run something else, run this.
- **Diversity pick: nethermind.** Compact flat-storage state, a minority-client diversity bonus, and restart-resume that is now measured, not just assumed (2026-08-01: closed a 10,607-block/~35h gap in 35m09s, no re-snap — see "Restart resilience" above). On disk it's on par with geth (~1.06 vs ~1.13 TiB) once full post-merge history is counted — not the space-saver its snap-sync-tip snapshot (~251 GiB) suggested. Costs a bit more sync time (~14.5h vs geth's ~8.5h).
- **Consensus client: lighthouse** as the lean default; any of the five is operationally fine — pick on footprint and familiarity.
- **Watch, don't yet deploy: ethrex.** Fascinating and fastest, but the ~25-minute restart cliff makes it operationally costly today. Its footprint is now settled too — a ~470–476 GiB plateau — but that's not a disk win: it's a no-history node, and running its RPC in place of a full-history endpoint will silently fail on anything historical. Fast-moving client — v19.0.0 at first sync, v22.0.0 by the steady-state measurement — worth revisiting.
- **Enterprise with care: besu.** It syncs, but its snap sync is fragile to CL outages; handle upgrades and CL health deliberately.
- **Know the design limits:** reth and nimbus_eth1 are full-sync-only — excellent clients, but plan for a long initial sync rather than snap-to-tip. Avoid erigon3 + a checkpoint-synced CL until the optimistic-sync deadlock is resolved.

The most useful thing this bake-off surfaced isn't a single winner — it's that **the number that matters to a running operator is often not the one on the benchmark chart.** Cold-sync time and disk footprint are easy to measure and easy to publish. Restart resilience is neither, and it's the axis that most cleanly explains which clients people actually keep running.

---

*Raw per-run data, every measured footprint and sync time, and the full incident log live alongside this post in [`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md) and [`CLIENT_BAKEOFF_ISSUES_LOG.md`](CLIENT_BAKEOFF_ISSUES_LOG.md). Every headline number is stamped `config_optimal=yes` by the harness gate described above.*
