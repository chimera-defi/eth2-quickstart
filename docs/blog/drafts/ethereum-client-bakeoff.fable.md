# Which Ethereum Clients Should a Home Validator Run? We Synced Twelve to Find Out

If you run one validator at home and want to know which execution client and consensus client to pick, this is what we measured and what we'd do with it. We synced seven execution clients and five consensus clients to Ethereum mainnet on one machine, one at a time, with prysm held fixed as the consensus client for every execution-client run, and then we stopped and restarted the synced ones to see how they recovered. The short answer: run geth, or nethermind if you want to help client diversity; pick any of the five consensus clients; and the thing most likely to bite you is not how long the first sync takes but what the client does after a restart.

## The short answer

| Execution client | First sync | Disk (and when we measured it) | Our verdict |
|---|---|---|---|
| Geth | ~8h28m | ~1.13 TiB, steady-state, post-merge history only | Run it. Nothing went wrong. |
| Nethermind | ~14.5h | ~1.06 TiB steady-state with full post-merge history; the installer default is minimal-history at ~250–280 GiB | Run it. Installer bugs found early on, since fixed. |
| Besu | ~19h18m | ~1.08 TiB, steady-state, history pruning off | Caution: wedged when its consensus client stalled mid-sync. |
| Ethrex | ~2h16m (fastest) | ~470–476 GiB steady-state, keeps no history (~286–300 GiB when first synced) | Watch, don't deploy yet: restarts longer than ~25 minutes stall it. |
| Reth | Did not finish in 72h (47% of blocks) | ~0.98 TiB, partial at the 72-hour cap | Fine client, no snap sync; plan for a multi-day first sync. |
| Nimbus-eth1 | Did not finish in 72h (~21.6%) | ~40 GB, partial at the 72-hour cap | Same: no snap sync, slow by design. |
| Erigon | Never synced | ~1.21 TiB, frozen partial | Avoid with a checkpoint-synced consensus client for now. |

Four clients reached the chain tip. Three did not, each for a specific reason covered below. The rest of this post is what sits behind each row, and what we think a home operator should take from it.

## How we tested

Everything ran on one shared Linux box between late June and early August 2026. It was not a live validator: no validator keys, MEV disabled. Each execution client got the machine to itself, paired with prysm, with a 72-hour cap. We recorded two numbers per client: how long it took to reach a fully validated chain head, and how much disk its data directory used at the end of the run (for the clients that hit the cap, the last reading before the cap).

Two things to know before reading the numbers. First, "snap sync" means the client downloads a recent copy of the chain's state from peers and only replays blocks from that point, which takes hours; "full sync" means replaying every block from genesis, which takes days. Which one a client supports decides most of the table above. Second, disk numbers are only comparable at the same point in a client's life. A freshly snap-synced node is often much smaller than the same node a day later, after it has backfilled old blocks and receipts in the background. We say which phase every disk figure comes from, because we got burned by this ourselves.

## First sync: ethrex is fast, everyone else is a workday or more

Among the four clients that finished, ethrex reached a validated head in about 2 hours 16 minutes, nearly four times faster than geth at 8 hours 28 minutes. Nethermind took about 14.5 hours and besu 19 hours 18 minutes. Ethrex held 50 peers throughout, healed one stale sync pivot on its own in about four minutes, and never crashed. On this axis it simply won.

Nethermind's time is from its second attempt. The first sat for 13.3 hours with zero peers because our installer had bound its peer-to-peer port to the loopback address, a bug we fixed before re-running. Whatever you run, check the peer count in the first few minutes; a node with no peers looks exactly like a slow sync.

Reth and nimbus-eth1 have no snap sync. They replay from genesis, and after 72 hours reth was at 47% of blocks (about 21% of the work when weighted by gas, since recent blocks are heavier) and nimbus-eth1 at about 21.6%. That is a design choice, not a defect; reth is widely run elsewhere. If you pick either, budget days for the first sync, not hours. Nimbus-eth1 did settle one open question for us: its `prune = true` setting, which its own `--help` text and its online docs described differently, does prune history online as it syncs. The run logged continuous pruning and stayed up 72 hours with zero restarts.

Erigon never synced. Its execution head froze a few thousand blocks behind the tip while prysm, which had started from a recent checkpoint, stayed in its "optimistic" mode waiting on erigon; neither side issued the update that would have closed the gap. Tripling the CPU we allowed prysm moved it about 5,000 blocks and then it froze again. We would not pair erigon with a checkpoint-synced consensus client until this is resolved.

## Disk: once you keep the same history, every client lands in the same band

The three clients that finished with full post-merge history all settled within about 7% of each other: geth at ~1.13 TiB, nethermind at ~1.06 TiB and besu at ~1.08 TiB, all measured at steady state. Reth, which was at ~0.98 TiB when the 72-hour cap hit, projects into the same band once finished. Disk size is set by how much history you keep, not by which client you run, so it is a poor way to pick a winner.

That said, there is one real disk lever, and it is a configuration choice rather than a client choice. Nethermind lets you skip storing post-merge block bodies and receipts. With that off, a fresh sync settles at roughly 250–280 GiB; with it on, the datadir grows to the ~1.06 TiB above as the history backfills. Our installer ships nethermind in minimal-history mode by default (`NETHERMIND_FULL_HISTORY=false`). The cost is that the node cannot answer questions about old blocks: requests for a block, log or receipt from before your sync return null. For a validator that is fine. If you want to serve a public RPC for wallets or indexers, set `NETHERMIND_FULL_HISTORY=true` on a fresh data directory; an existing minimal-history datadir needs a rebuild. Geth's shipped configuration keeps post-merge history only, which is what the ~1.13 TiB figure measures.

Two disk figures are easy to misread. Nethermind read ~251 GiB right after its snap sync in the full-history run; once the background backfill of old blocks and receipts had finished, it was over a terabyte. And ethrex's ~470–476 GiB steady-state footprint is not a win: ethrex keeps no history at all. We probed its RPC and found the cutoff is exactly its sync pivot block. One block earlier returns null, and it never backfills. Current balances and allowances work; anything historical does not, so it is not a drop-in replacement for a geth endpoint. Besu's ~1.08 TiB came from a run with history pruning off; our installer ships besu with pruning on, and we never got a clean footprint for that configuration because of the deadlock described next.

## Restarts: this is what will actually bite you

You will restart your node: upgrades, config edits, a reboot, a power cut. What a client does after a gap turned out to split the field more sharply than sync time or disk. The reason is a property of the network: a full node only serves peers the state for roughly the last 128 blocks, about 25 minutes. Geth and nethermind resume by importing the blocks they missed, and both recovered that way from every gap we tried. A client that needs peers to serve it state from the moment it went down has a 25-minute window to come back in.

| Client | Gaps we tested | What happened |
|---|---|---|
| Geth | One ~52-hour gap (~15,400 blocks) | Kept its datadir, imported the missed blocks, converged on the tip. We did not time it. |
| Nethermind | 12 min, 30 min, 1 h, 4 h, and one ~35 h gap (69 to 10,607 blocks) | Every gap resumed by block import. 121 s to catch up after 12 min, 483 s after 4 h, 35m09s after ~35 h (~302 blocks/min). Datadir grew 1.1% over that last gap. |
| Ethrex | 12, 20, 23 and 26 min; one ~1.5–2 h gap | Resumed at 12, 20 and 23 min (up to 124 blocks). Stalled at 26 min (132 blocks). The 1.5–2 h gap threw away the synced state and re-synced from scratch in 2h11m. |
| Besu | Consensus client stalled ~28 h while besu was still syncing | Besu's sync pivot aged out; the sync thread died while the process kept answering RPC. A restart hit the same stale pivot and deadlocked again. We abandoned the run. |
| Prysm (consensus) | Four restarts, one timed 30-minute stop | Resumed from its own database every time, no fresh checkpoint needed. The 30-minute stop was back in sync in about 2m44s. |

Geth and nethermind are the boring ones, in the good sense. Nethermind's catch-up cost stayed constant per block: its state directory grew a steady ~1.0–1.3 MiB per imported block across every gap, and catch-up time rose only gently with gap length, the signature of plain block import rather than a re-download, and we found no gap length at which it fell off a cliff.

Ethrex has a cliff, and we pinned it. Gaps of 12, 20 and 23 minutes resumed. At 26 minutes the head froze with `Failed to fetch headers for sync head`, because peers would no longer serve the headers it needed. After a routine gap of about 1.5 to 2 hours, a fully synced ethrex dropped its data directory from 286 GiB to about 9 GiB and started a fresh snap sync from near genesis; that re-sync took 2h11m, essentially the whole cold sync again. We saw this on ethrex v19.0.0. It is a young client and this may improve, and it does not change its sync-time result. But a client that stops resuming after a 25-minute outage and starts over after a two-hour one is hard to run today, and we think it is a strong candidate explanation for why the fastest-syncing client in our field has a near-zero share of mainnet nodes.

Besu's problem is different: it only showed up mid-sync, and its root cause was on the consensus side. A bug in the prysm version we were running stalled prysm for about 28 hours while besu was still snap-syncing. With nothing telling it where the chain head was, besu's sync pivot aged past the window peers would serve, it logged `The pivot block number has not increased`, and its sync thread died. The process stayed up and answered `eth_blockNumber`, so a liveness check would have said everything was fine. Restarting resumed on the same stale pivot and wedged again, and we abandoned that run. Two lessons for operators: keep your consensus client healthy and up to date while an execution client is still syncing, and judge sync progress by disk growth and block height, not by whether RPC answers. Besu's other run, with history pruning off, snap-synced to a validated head in ~19h18m; that is where its ~1.08 TiB figure comes from. The deadlock hit the re-run with pruning on.

A scope note: these restart tests cover geth, nethermind and ethrex after they had synced, besu during its sync, and prysm as the only consensus client. Reth, nimbus-eth1 and erigon never got far enough to restart. We did not restart-test the other five consensus clients.

## Consensus clients: all five work; pick on disk and familiarity

We ran lighthouse, lodestar, grandine, teku and nimbus each paired with a synced execution client, then repeated the sweep with two more execution clients to check the results did not depend on the pairing. All five checkpoint-synced (started from a recent trusted state instead of replaying from genesis) to a validated head in minutes: about 6–9 minutes paired with geth, 7–10 with nethermind, 22–23 with ethrex. None crashed. Four runs needed a redo, for reasons we could trace: teku's first attempt starved the shared machine of memory until we gave it a larger Java heap (it then synced in 22 minutes), one grandine run was killed by a bug in our own measuring script, lodestar's first run was slow because the execution client it was paired with was catching up a two-day gap left by an earlier lodestar crash loop on the shared host, and our health check misreported teku twice during its startup.

Since sync time was effectively a tie, disk is the differentiator. These are data directories measured minutes after checkpoint sync, so treat them as a starting size, not a steady state:

| Consensus client | Disk, paired with geth | Disk, paired with nethermind | Pruning setting that matters |
|---|---|---|---|
| Lodestar | ~177 MiB | ~178 MiB | `pruneHistory` on |
| Lighthouse | ~518 MiB | ~470 MiB | checkpoint sync (blob pruning is default) |
| Grandine | ~725 MiB | ~730 MiB | `--prune-storage` (without it, stores every state) |
| Teku | ~936 MiB | ~835 MiB | `data-storage-mode=minimal` |
| Nimbus | ~1.2 GiB | ~1.3 GiB | `history=prune` |

The same three tiers showed up on every pairing: lodestar and lighthouse small, grandine and teku in the middle, nimbus largest. On the ethrex pairing lighthouse edged out lodestar, and teku's two runs on nethermind differed by about 25% from each other, so do not read anything into the order within a tier. Every client in this table is a reasonable choice. We default to lighthouse. Prysm, our fixed baseline, is the only consensus client we restart-tested, and it resumed cleanly every time.

## What we'd do

Run geth by default: the cleanest sync of the clients that finished, and it kept its data through a ~52-hour outage. Run nethermind if you want a minority client; its first sync took 14.5 hours against geth's 8.5, it resumed every gap we threw at it, and in the installer's default minimal-history mode it needs roughly a quarter of the disk, as long as you do not need to serve old blocks. Pair either with lighthouse, or whichever consensus client you already know. Give teku a generous heap, and do not run grandine without `--prune-storage`.

Keep ethrex on your watch list. It syncs in two hours, but until it can survive a half-hour restart without starting over, it is not a client we would leave running unattended. Treat besu as a client that needs a healthy consensus client beside it, especially during its first sync. Expect reth and nimbus-eth1 to take days to sync, and skip erigon with a checkpoint-synced consensus client for now.

The one thing we would want every home operator to take away: the number on the benchmark chart is the first sync, and you will do that once. What a client does after a restart is what you live with.

Every figure here, with exact byte counts, block numbers and the incident log, is in the raw results: [`docs/CLIENT_BAKEOFF_RESULTS.md`](https://github.com/chimera-defi/eth2-quickstart/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md).
