# Which Ethereum Client Should You Run at Home? Watch What Happens When You Restart It

If you run, or are about to run, an Ethereum validator at home, this is for you: we tried to
sync seven execution clients and six consensus clients on the same machine to see which ones
are worth running. The short answer is geth or nethermind, with lighthouse as the
consensus client. The longer answer is more interesting: the fastest client we tested is
also the one most likely to ruin your afternoon, and the reason isn't in the numbers
benchmarks usually publish.

## The short answer

| If you want… | Run | Why |
|---|---|---|
| The safe default | **geth** | Synced cleanly in ~8h28m and picked up where it left off after a ~52-hour shutdown. |
| A less common client, or a smaller disk | **nethermind** | Recovered from every restart gap we tried. The installer's default setup is ~250–280 GiB right after sync. |
| A consensus client | **lighthouse** (or any of the five we compared) | All five synced in minutes without crashing. They differ mainly in disk use. |
| The fastest sync | ethrex, but not yet | Synced in ~2h16m, then stalled after a 26-minute stop and started over after a ~2-hour one. |

## How we tested

We ran one client at a time on a single test server (no validator keys) and gave each up to
72 hours to reach the head of mainnet, the newest block. Each client was installed with the
open-source eth2-quickstart installer.

An Ethereum node is two programs. The **execution client** (geth, nethermind, besu, …)
holds the chain's state and runs transactions. The **consensus client** (prysm,
lighthouse, …) follows the proof-of-stake chain and tells the execution client which block
is current. To compare execution clients fairly, we paired every one with the same
consensus client, prysm. Then we tested the other five consensus clients against a fixed
execution client.

For each client we recorded how long it took to sync and how much disk it used. Disk use
keeps changing after a sync, so each figure below says when it was taken.

## Speed: one client wins by hours

Time to a fully synced, validating node:

| Execution client | Sync time | Result |
|---|---|---|
| ethrex | ~2h16m (v19) | synced |
| geth | ~8h28m | synced |
| nethermind | ~14.5h | synced |
| besu | ~19h18m | synced |
| reth | — | ~47% of blocks (~21% of the work) when the 72h cap hit |
| nimbus_eth1 | — | ~21.6% when the 72h cap hit |
| erigon | — | stuck, never synced |

ethrex finished nearly 4× faster than geth, ahead of every established client by hours.

reth and nimbus_eth1, as we ran them, don't **snap sync**, where a client
downloads a recent copy of the state instead of replaying every block since 2015. That's a
design choice, not a bug, and reth is widely run elsewhere. Plan on days, not hours, for
the first sync if you pick one.

erigon (version 3) never synced. Paired with prysm started from a recent trusted snapshot (a checkpoint), each side waited for the other to make the next move, and neither did.
Avoid that combination for now.

## Disk: no winner, because the setting decides

Disk use for the clients that finished, once it stopped growing unless noted:

| Execution client | Disk | What it keeps |
|---|---|---|
| geth | ~1.13 TiB | blocks and receipts since the Merge |
| besu | ~1.08 TiB | full block history |
| nethermind, full history | ~1.06 TiB | blocks and receipts since the Merge |
| ethrex (a later re-sync) | ~470–476 GiB | almost no history |
| nethermind, minimal history (installer default) | ~250–280 GiB right after sync | no old blocks or receipts |

The three clients that keep block history (since the Merge, Ethereum's 2022 switch to proof
of stake, or longer) all land around 1.1 TiB. Disk size
comes from how much history you keep, not from which client you run.

So the useful question is: **do you need old history at all?** A validator doesn't. It
needs current state and new blocks. History only matters if other people query your node
over RPC (the API wallets and apps use to read the chain) for past transactions: indexers,
block explorers, tax tools.

That's why the installer sets nethermind to minimal history by default
(`NETHERMIND_FULL_HISTORY=false`): a fraction of the full-history size, but it can't serve
old blocks, logs or receipts. If you'll serve public RPC, set
`NETHERMIND_FULL_HISTORY=true` before the first sync; switching later means rebuilding the
data directory. ethrex makes the same trade without asking: it serves nothing older than where its
sync started, so it can't stand in for a geth RPC endpoint.

One trap when reading anyone's disk numbers, ours included: with full history on,
nethermind measured ~251 GiB right after its sync finished and ~1.06 TiB once it had
downloaded the post-Merge history in the background. A disk figure without its timing can
be off by 4×.

## Restarts: the test that matters

You will restart your node: client upgrades, OS updates, power cuts. What the client does
next matters more day to day than how fast it synced the first time.

One fact explains the results. Peers only serve the chain's *current state* for roughly the
last 128 blocks, about 25 minutes. A client that catches up by importing the blocks it missed
doesn't need that state. A client that needs peers to hand it state or headers from before it
stopped gets stuck once those are older than the window.

**1. Picks up where it left off: geth and nethermind.** We stopped geth for ~52 hours
(~15,400 blocks); on restart it imported the missed blocks and got back to the head. We
stopped nethermind for 12 minutes up to 4 hours: a 12-minute gap took ~2
minutes to close, a 4-hour gap ~8 minutes. Separately, a consensus-client restart left it
~35 hours behind, and it caught up in ~35 minutes. No gap broke it.

**2. Falls off a cliff: ethrex.** We stopped ethrex for longer and longer gaps:

| Stopped for | Blocks missed | What happened |
|---|---|---|
| 12 min | 68 | resumed |
| 20 min | 108 | resumed |
| 23 min | 124 | resumed |
| 26 min | 132 | stuck: head frozen, couldn't fetch the missing headers |

After a routine 1.5–2 hour stop it went further: it threw away its fully synced data
directory and started over, a re-sync that took 2h11m. That was v19.0.0,
and ethrex moves fast, so newer versions may do better. But a node that can wipe itself after a two-hour
maintenance window is a hard sell for something meant to run unattended.

**3. Can break mid-sync: besu.** besu's first sync was fine. On a later re-sync, our
consensus client (an outdated prysm release) stalled for ~28 hours. With nothing telling it which block was current,
besu's sync fell outside that ~25-minute window and its sync thread died, while the process
kept running and answering RPC. It *looked* healthy. Restarting got stuck the same way. Two
lessons: keep your consensus client up to date and healthy while besu syncs, and don't take a node that
answers requests as proof that it's still syncing.

## Consensus clients: pick on disk and familiarity

All five consensus clients we tried (lighthouse, lodestar, grandine, teku, nimbus) started
from a recent checkpoint and reached a validating head in 6–9 minutes with geth, without
crashing. Disk use, measured minutes after sync:

| Consensus client | Disk after sync |
|---|---|
| lodestar | ~177 MiB |
| lighthouse | ~518 MiB |
| grandine | ~725 MiB |
| teku | ~936 MiB |
| nimbus | ~1.2 GiB |

These grow as the client runs, but the same three groups held when we repeated the test
with nethermind and ethrex: lodestar and lighthouse lightest, teku and grandine in the
middle, nimbus heaviest. Any of them is fine; lighthouse is a lean, safe default. (On the
consensus side we only restart-tested prysm. It resumed from its own database each time,
back in sync ~2m44s after a 30-minute stop.)

## What we'd tell a friend

- Run **geth** with **lighthouse** unless you have a reason not to.
- For client diversity, or a much smaller disk, run **nethermind** at its minimal-history
  default. Switch to full history before the first sync only if you'll serve public RPC.
- Size your disk for steady state, not for the number a client shows the moment it syncs.
- Test what happens when you restart, not just how fast the first sync goes.
- Keep an eye on **ethrex**, but check its restart behaviour on a current release first.
- As we ran them, **reth** and **nimbus_eth1** need days for a first sync; don't pair **erigon 3** with a
  checkpoint-synced prysm yet.

---

Every measured number here, with per-run detail and the full incident log, is on the
[raw results page](https://eth2quickstart.com/blog/bakeoff-results).
