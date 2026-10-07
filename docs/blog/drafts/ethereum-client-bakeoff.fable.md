# Which Ethereum Clients Should a Home Validator Run? We Tested Twelve to Find Out

If you run one validator at home and want to know which execution client and consensus client to pick, this is what we measured and what we'd do with it. We tried to sync seven execution clients and five consensus clients to Ethereum mainnet on one machine, one at a time, with prysm held fixed as the consensus client for every execution-client run, and then we stopped and restarted the synced ones to see how they recovered. The short answer: run geth, or nethermind if you want to help client diversity; pick any of the five consensus clients; and the thing most likely to bite you is not how long the first sync takes but what the client does after a restart.

## The short answer

| Execution client | First sync | Disk (and when we measured it) | Our verdict |
|---|---|---|---|
| Geth | ~8h28m | ~1.13 TiB, steady-state, post-merge history only | Run it. Nothing went wrong. |
| Nethermind | ~14.5h | ~1.06 TiB steady-state with full post-merge history; the installer default is minimal-history at ~250–280 GiB right after sync | Run it. |
| Besu | ~19h18m | ~1.08 TiB, steady-state, history pruning off | Caution: wedged when its consensus client stalled mid-sync. |
| Ethrex | ~2h16m (fastest, v19) | ~470–476 GiB steady-state on a later re-sync, keeps no history (~286–300 GiB when first synced) | Watch, don't deploy yet: restarts longer than ~25 minutes stall it. |
| Reth | Did not finish in 72h (47% of blocks) | ~0.98 TiB, partial at the 72-hour cap | Fine client, no snap sync as we ran it; plan for a multi-day first sync. |
| Nimbus-eth1 | Did not finish in 72h (~21.6%) | ~40 GB, partial at the 72-hour cap | Same: no snap sync as we ran it, slow by design. |
| Erigon | Never synced | ~1.21 TiB, frozen partial | Avoid erigon 3 with checkpoint-synced prysm for now. |

Four clients reached the chain tip. Three did not, each for a specific reason covered below. The rest of this post is what sits behind each row, and what we think a home operator should take from it.

## How we tested

Everything ran on one shared Linux box between late June and early August 2026. It was not a live validator: no validator keys. Each execution client ran alone, one at a time, paired with prysm, with a 72-hour cap. We recorded two numbers per client: how long it took to reach a fully validated chain head, and how much disk its data directory used at the end of the run (for the clients that hit the cap, the last reading before the cap).

Two things to know before reading the numbers. First, "snap sync" means the client downloads a recent copy of the chain's state from peers and only replays blocks from that point, which takes hours; "full sync" means replaying every block from genesis, which takes days. Which one a client supports decides most of the table above. Second, disk numbers are only comparable at the same point in a client's life. A freshly snap-synced node is often much smaller than the same node a day later, after it has backfilled old blocks and receipts in the background. We say which phase every disk figure comes from, because we got burned by this ourselves.

## First sync: ethrex is fast, everyone else is a workday or more

Among the four clients that finished, ethrex reached a validated head in about 2 hours 16 minutes, nearly four times faster than geth at 8 hours 28 minutes. Nethermind took about 14.5 hours and besu 19 hours 18 minutes. On this axis it simply won.

Reth and nimbus-eth1, as we ran them, don't snap sync. They replay from genesis, and after 72 hours reth was at 47% of blocks (about 21% of the work, since recent blocks are heavier) and nimbus-eth1 at about 21.6%. That is a design choice, not a defect; reth is widely run elsewhere. If you pick either, budget days for the first sync, not hours.

Erigon never synced. Its execution head froze a few thousand blocks behind the tip while prysm, which had started from a recent checkpoint, waited on erigon; neither side issued the update that would have closed the gap. We would not pair erigon 3 with checkpoint-synced prysm until this is resolved.

## Disk: once you keep the same history, every client lands in the same band

The three clients that finished with full post-merge history all settled within about 7% of each other: geth at ~1.13 TiB, nethermind at ~1.06 TiB and besu at ~1.08 TiB, all measured at steady state. Reth, which was at ~0.98 TiB when the 72-hour cap hit, projects into the same band once finished. Disk size is set by how much history you keep, not by which client you run, so it is a poor way to pick a winner.

That said, there is one real disk lever, and it is a configuration choice rather than a client choice. Nethermind lets you skip storing post-merge block bodies and receipts. With that off, a fresh sync lands at roughly 250–280 GiB; with it on, the data directory grows to the ~1.06 TiB above as the history backfills. Our installer ships nethermind in minimal-history mode by default (`NETHERMIND_FULL_HISTORY=false`). The cost is that the node cannot answer questions about old blocks: it can't serve blocks, logs or receipts from before your sync. For a validator that is fine. If you want to serve a public RPC for wallets or indexers, set `NETHERMIND_FULL_HISTORY=true` on a fresh data directory; an existing minimal-history data directory needs a rebuild. Geth's shipped configuration keeps post-merge history only, which is what the ~1.13 TiB figure measures.

Two disk figures are easy to misread. Nethermind read ~251 GiB right after its snap sync in the full-history run; once the background backfill of old blocks and receipts had finished, it was over a terabyte. And ethrex's ~470–476 GiB steady-state footprint is not a win: ethrex keeps no history at all. We probed its RPC: nothing from before the block where its sync started is served, and it never backfills. Current balances and allowances work; older blocks, logs and receipts don't, so it is not a drop-in replacement for a geth endpoint. Besu's ~1.08 TiB came from a run with history pruning off; our installer ships besu with pruning on, and we never got a clean footprint for that configuration because of the deadlock described next.

## Restarts: this is what will actually bite you

You will restart your node: upgrades, config edits, a reboot, a power cut. What a client does after a gap turned out to split the field more sharply than sync time or disk. The reason is a property of the network: a full node only serves peers the state for roughly the last 128 blocks, about 25 minutes. Geth and nethermind resume by importing the blocks they missed, and both recovered that way from every gap we tried. A client that needs peers to serve it state from the moment it went down has a 25-minute window to come back in.

| Client | Gaps we tested | What happened |
|---|---|---|
| Geth | One ~52-hour gap (~15,400 blocks) | Kept its data directory, imported the missed blocks, converged on the tip. We did not time it. |
| Nethermind | Stops of 12 min, 30 min, 1 h and 4 h, plus a ~35 h catch-up after a consensus-client restart | Every gap resumed by block import. 121 s to catch up after 12 min, 483 s after 4 h, 35m09s after ~35 h. |
| Ethrex | 12, 20, 23 and 26 min; one ~1.5–2 h gap | Resumed at 12, 20 and 23 min (up to 124 blocks). Stalled at 26 min (132 blocks). The 1.5–2 h gap threw away the synced state and re-synced from scratch in 2h11m. |
| Besu | Consensus client stalled ~28 h while besu was still syncing | The block it was syncing toward aged out; the sync thread died while the process kept answering RPC. A restart hit the same stale block and deadlocked again. We abandoned the run. |
| Prysm (consensus) | Four restarts, one timed 30-minute stop | Resumed from its own database every time, no fresh checkpoint needed. The 30-minute stop was back in sync in about 2m44s. |

Geth and nethermind are the boring ones, in the good sense. Nethermind's catch-up time rose only gently with gap length, and we found no gap at which it fell off a cliff.

Ethrex has a cliff, and we pinned it. Gaps of 12, 20 and 23 minutes resumed. At 26 minutes the head froze, because peers would no longer serve the headers it needed. After a routine gap of about 1.5 to 2 hours, a fully synced ethrex dropped its data directory from 286 GiB to about 9 GiB and started a fresh snap sync from near genesis; that re-sync took 2h11m, essentially the whole cold sync again. We saw this on ethrex v19.0.0. It is a young client and this may improve, and it does not change its sync-time result. But a client that stops resuming after a 25-minute outage and starts over after a two-hour one is hard to run today.

Besu's problem is different: it only showed up mid-sync, and its root cause was on the consensus side. A bug in the outdated prysm release we were running (v7.1.5) stalled it for about 28 hours while besu was still snap-syncing. With nothing telling it where the chain head was, the block besu was syncing toward aged past the window peers would serve, and its sync thread died. The process stayed up and answered `eth_blockNumber`, so a liveness check would have said everything was fine. Restarting resumed toward the same stale block and wedged again, and we abandoned that run. Two lessons for operators: keep your consensus client healthy and up to date while an execution client is still syncing, and don't take a node that answers RPC as proof that it's still syncing. Besu's other run, with history pruning off, snap-synced to a validated head in ~19h18m; that is where its ~1.08 TiB figure comes from. The deadlock hit the re-run with pruning on.

A scope note: these restart tests cover geth, nethermind and ethrex after they had synced, besu during its sync, and prysm as the only consensus client. Reth, nimbus-eth1 and erigon never got far enough to restart. We did not restart-test the other five consensus clients.

## Consensus clients: all five work; pick on disk and familiarity

We ran lighthouse, lodestar, grandine, teku and nimbus each paired with a synced execution client, then repeated the sweep with two more execution clients to check the results did not depend on the pairing. All five checkpoint-synced (started from a recent trusted state instead of replaying from genesis) to a validated head in minutes: about 6–9 minutes paired with geth, 7–10 with nethermind, 22–23 with ethrex. None crashed.

Since sync time was effectively a tie, disk is the differentiator. These are data directories measured minutes after checkpoint sync, so treat them as a starting size, not a steady state:

| Consensus client | Disk, paired with geth | Disk, paired with nethermind | Pruning setting that matters |
|---|---|---|---|
| Lodestar | ~177 MiB | ~178 MiB | `pruneHistory` on |
| Lighthouse | ~518 MiB | ~470 MiB | checkpoint sync (blob pruning is default) |
| Grandine | ~725 MiB | ~730 MiB | `--prune-storage` (without it, stores every state) |
| Teku | ~936 MiB | ~835 MiB | `data-storage-mode=minimal` |
| Nimbus | ~1.2 GiB | ~1.3 GiB | `history=prune` |

The same three tiers showed up on every pairing: lodestar and lighthouse small, grandine and teku in the middle, nimbus largest. On the ethrex pairing lighthouse edged out lodestar, so do not read anything into the order within a tier. Every client in this table is a reasonable choice. We default to lighthouse. Prysm, our fixed baseline, is the only consensus client we restart-tested, and it resumed cleanly every time.

## What we'd do

Run geth by default: the cleanest sync of the clients that finished, and it kept its data through a ~52-hour outage. Run nethermind if you want a minority client; its first sync took 14.5 hours against geth's 8.5, it resumed every gap we threw at it, and in the installer's default minimal-history mode it needs a fraction of the disk, as long as you do not need to serve old blocks. Pair either with lighthouse, or whichever consensus client you already know. Do not run grandine without `--prune-storage`, and whatever you run, check the peer count in the first few minutes: a node with no peers looks exactly like a slow sync.

Keep ethrex on your watch list. Our v19 run synced in about two hours, but until it can survive a half-hour stop without stalling, it is not a client we would leave running unattended. Treat besu as a client that needs a healthy consensus client beside it, especially during its first sync. Expect reth and nimbus-eth1, as we ran them, to take days to sync, and skip erigon 3 with checkpoint-synced prysm for now.

The one thing we would want every home operator to take away: the number on the benchmark chart is the first sync, and you will do that once. What a client does after a restart is what you live with.

Every figure here, with exact byte counts, block numbers and the incident log, is in the raw results: [`docs/CLIENT_BAKEOFF_RESULTS.md`](https://github.com/chimera-defi/eth2-quickstart/blob/master/docs/CLIENT_BAKEOFF_RESULTS.md).
