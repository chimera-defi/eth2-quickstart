# Which Ethereum client should you actually run? We synced all of them.

*An operator's-eye summary of the eth2-quickstart client bake-off. Numbers of record live in [`CLIENT_BAKEOFF_RESULTS.md`](../CLIENT_BAKEOFF_RESULTS.md); this is the short, actionable version.*

The fastest execution client to sync from scratch is one almost nobody runs. That sounds like a knock on the herd — it isn't. Once you watch these clients *restart*, not just sync, the reason snaps into focus. That single observation is the thesis of this post: **for a node you'll actually operate for months, restart-resilience matters more than cold-sync speed.**

We stood up every supported execution (EL) and consensus (CL) client on one shared, semi-production host — one candidate at a time, no MEV, no validator keys, a 72-hour cap each — and measured two things: how long it took to sync, and how big the final pruned datadir was. Then we restarted them and watched what broke. Here's what to run.

## The only two decisions you make

An Ethereum node is one EL + one CL talking over the Engine API. Their disk and sync costs are independent — we confirmed this empirically (see below), so you can pick each on its own merits. There is no "magic pairing."

## Execution client: geth or nethermind (and know why)

Two clients cleared every bar we care about — snap-sync to a validating tip, a working history-prune lever so the disk number is honest, and clean resume after a restart:

| EL | Sync time | Pruned footprint | Mainnet share | Verdict |
|----|-----------|------------------|---------------|---------|
| **nethermind** | ~14.5h | **~251 GiB** | 36.0% | **Disk winner** — ~4.5× leaner than geth. Also a minority client, so running it helps client diversity. |
| **geth** | ~8h28m | ~1.13 TiB | 44.9% | **Conservative default** — biggest ecosystem, most docs, resumes cleanly from multi-day downtime. |

If you run one EL for the long haul, run one of these. Pick **nethermind** if disk is your constraint (it is 4.5× smaller and improves diversity); pick **geth** if you want the most boring, best-documented option on the network.

**besu** is a legitimate enterprise third — it *did* snap-sync to a fully validated head (~19h18m) — but with two asterisks: our run was un-pruned (~1.08 TiB, no comparable pruned number), and its snap sync is fragile if your CL goes down for a while (more on that below). Fine for a shop that keeps its CL current and watches the node; not a set-and-forget solo-staker pick.

**The rest fell out for specific, documented reasons — not because they're "bad":**

- **ethrex** — *fastest cold sync in the entire field* (~2h16m, next-fastest is geth at ~8.5h) but the wrong long-run profile. It has no prune lever, the datadir grows unbounded even *at the chain tip* (~10 GiB/hr, 286 → ~467 GiB in our window), and — the dealbreaker — it **throws away its synced state and re-syncs from scratch after any downtime longer than ~25 minutes.** Every upgrade or maintenance window costs a fresh ~2h sync. Fast to stand up, painful to operate. Young client (v19.0.0); may improve.
- **reth, nimbus_eth1** — full-sync-only in the mode we tested (no snap), so they can't reach the tip inside a practical window on this host. A time-to-sync limit under our bar, not a blanket verdict — reth in particular is widely run elsewhere.
- **erigon** — deadlocked against a checkpoint-synced consensus client on this host (a reproducible, structural stall), so it never produced a synced datadir.

## Consensus client: any of the five, lighthouse as the lean default

The CL layer is the healthy half of the network. Every consensus client we swept checkpoint-synced to a validating head in ~22–23 minutes with zero crashes. None of them *failed* — so your choice is footprint and preference, not survival. Smaller is better:

**lighthouse (~739 MB) < lodestar (~827 MB) < grandine (~946 MB) < teku (~2.1 GB) < nimbus (~5.0 GB)**

Two operational caveats worth knowing:

- **teku** needs a generously sized JVM heap on a shared host (`TEKU_CACHE`). Undersized, its garbage collection spilled onto co-resident services and poisoned one of our runs.
- **grandine** needs `--prune-storage` or it stores *every* state — the single most important flag for it.
- **nimbus** is simply the heaviest (~6.8× lighthouse), but otherwise clean.

We ran this whole sweep twice — once anchored to ethrex, once to geth — and the ranking held. The absolute sizes shifted (they grow the longer a CL follows the chain), but the order didn't, which is the empirical proof that **your CL choice doesn't depend on your EL choice.**

## The one rule that ties it together

Cold-sync benchmarks measure day one. You operate a node for months, and you *restart* it constantly — upgrades, config changes, crashes, host maintenance. So the question that actually predicts pain is: **what happens after a restart with a gap?**

Clients split into three behaviors:

1. **Graceful resume** — comes back, imports the blocks it missed, keeps its state. Minutes to catch up. (geth, measured after a 52-hour gap; nethermind and reth expected here by design.)
2. **Re-snap cliff** — after a gap past a threshold, discards its synced state and re-syncs from scratch. (**ethrex**, past ~25 minutes.)
3. **Mid-sync deadlock** — if the CL stops driving the engine during an unfinished sync, the sync wedges permanently while the process still answers RPC. (**besu**, when a stale CL stalled ~28h.)

Behaviors #2 and #3 come from the *same* root cause: the network only serves recent state (~128 blocks ≈ 25 minutes of history). Miss that window and you can't heal your database from peers — you're forced back to a full re-sync. Graceful-resume clients dodge it by importing missed *blocks* (always available) instead of re-fetching *state*. This is exactly why geth and nethermind clear the bar and ethrex doesn't, despite ethrex having the best cold-sync numbers.

**One cross-cutting lesson:** keep your CL binary current. A stale consensus client (in our case a prysm build with a known PeerDAS bug) stalled for ~28 hours and is precisely what wedged besu's sync. Binary freshness is an operational requirement, not a nicety.

## TL;DR

- **Run geth or nethermind.** nethermind if you want small (~251 GiB, 4.5× leaner) and diverse; geth if you want boring and well-documented. besu only if you're an enterprise shop that babysits its CL.
- **Any CL works.** lighthouse is the lean default (~739 MB); lodestar and grandine are close; teku and nimbus are heavier but fine.
- **Restart-resilience beats cold-sync speed.** Fast initial sync (ethrex) and small archive-context footprints do not make a client operationally viable — surviving restarts and uptime does, and that's an EL-layer problem.
- **Keep your consensus client updated.** A stale CL is how the one un-recoverable failure we saw actually happened.

*Curious how we measured all this — and the forensic detail behind the ethrex cliff and the besu deadlock? See the full technical write-up: [The Fastest Ethereum Client Is One Almost Nobody Runs](../CLIENT_BAKEOFF_BLOG.md).*

---

*Methodology in brief: one shared semi-prod host, sequential (one client at a time), MEV off, no validator keys, 72h cap per candidate, footprint = final synced datadir (never the peak). EL scorecard holds the CL constant at prysm; CL scorecard holds the EL constant (ethrex, then geth). The `nimbus_eth1` execution-client full-sync row is a partial — ~40 GB at ~21.6% after the full 72h cap (0 restarts, stable throughout) — a full-sync-only client that can't reach tip inside the cap, so it lands as a client-limitation footnote, not a ranking entry. One bonus finding from that run: its `prune = true` flag is confirmed to prune history online, settling a previously-contested question.*
