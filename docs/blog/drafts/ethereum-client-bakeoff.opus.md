# Which Ethereum Client Should You Run at Home? Watch What Happens When You Restart It

If you run, or are about to run, an Ethereum validator at home, this is for you: we synced
seven execution clients and five consensus clients on the same machine to see which ones
are worth running. The short answer is geth or nethermind, with lighthouse as the
consensus client. The longer answer is more interesting: the fastest client we tested is
also the one most likely to ruin your afternoon, and the numbers that explain why are not
the ones benchmarks usually publish.

## The short answer

| If you want… | Run | Why |
|---|---|---|
| The safe default | **geth** | Synced cleanly in ~8h28m and picked up where it left off after a ~52-hour shutdown. |
| A minority client, or a smaller disk | **nethermind** | Recovered from every restart gap we tried, like geth. The eth2-quickstart installer's default setup settles at ~250–280 GiB. |
| A consensus client | **lighthouse** (or any of the five) | All five synced in minutes without crashing. They differ mainly in disk use. |
| The fastest sync | ethrex, but not yet | Synced in ~2h16m, then stalled after a 26-minute stop and started over after a ~2-hour one. |

The rest of this post is why.

## How we tested

We ran one client at a time on a single shared server and gave each up to 72 hours to reach
the head of mainnet, the newest block. It was a test box, not a live validator: no validator
keys and no MEV (the extra block-building income a validator can opt into). The main runs
started on 2026-06-22; follow-up restart and disk tests ran until 2026-08-03. The setups we
tested are the ones the open-source eth2-quickstart installer produces, which is what "our
installer" means below.

An Ethereum node is two programs. The **execution client** (geth, nethermind, besu, …)
holds the chain's state and runs transactions. The **consensus client** (prysm,
lighthouse, …) follows the proof-of-stake chain and tells the execution client which block
is current. To compare execution clients fairly, we paired every one with the same
consensus client, prysm. Then we tested the other five consensus clients against a fixed
execution client, three times over with a different one each time.

For each client we recorded how long it took to sync and how much disk it used. A disk
number is only meaningful if you know *when* it was taken, because a client can grow
several-fold after it first reports "synced" while it downloads older history in the
background. So every disk figure below says whether it was taken at the moment of sync,
after the datadir settled (steady state), or partway through when the 72-hour cap hit.

## Speed: one client wins by hours

Time to a fully synced, validating node:

| Execution client | Sync time | Result |
|---|---|---|
| ethrex | ~2h16m | synced |
| geth | ~8h28m | synced |
| nethermind | ~14.5h | synced |
| besu | ~19h18m | synced |
| reth | — | hit the 72h cap at ~47% of blocks (~21% of the work, weighted by gas) |
| nimbus_eth1 | — | hit the 72h cap at ~21.6% |
| erigon | — | stuck, never synced |

ethrex finished nearly 4× faster than geth. It is a young, minimalist Rust client with a
near-zero share of mainnet nodes, and it beat every established client by hours.

reth and nimbus_eth1 can't fast-sync: they don't support **snap sync**, where a client
downloads a recent copy of the state instead of replaying every block since 2015. They
replay the whole chain, and neither finished within 72 hours: reth got about halfway by
block count, nimbus_eth1 about a fifth. That's a design choice, not
a bug, and reth is widely run elsewhere. Just plan for a long first sync if you pick one.

erigon (version 3) never synced. Paired with a consensus client that started from a recent
checkpoint, each side waited for the other to make the next move, and neither did.
Avoid that combination for now.

## Disk: no winner, because the setting decides

Here is what the clients that finished settled at:

| Execution client | Disk at steady state | What it keeps |
|---|---|---|
| geth | ~1.13 TiB | all history since the Merge (`--history.chain postmerge`) |
| besu | ~1.08 TiB | all history since the Merge (no pruning) |
| nethermind, full history | ~1.06 TiB | all history since the Merge |
| ethrex | ~470–476 GiB | almost no history |
| nethermind, minimal history (installer default) | ~250–280 GiB | no old blocks or receipts |

The three clients that keep full post-Merge history all land around 1.1 TiB. Disk size
comes from how much history you keep, not from which client you run, so it's a poor way to
pick a winner.

That changes the useful question to: **do you need old history at all?** A validator
doesn't. It needs current state and new blocks. History only matters if you let other
people query your node over RPC (the API that wallets and apps use to read the chain):
wallets looking up past transactions, indexers, block explorers, tax tools.

That's why our installer now sets nethermind to minimal history by default
(`NETHERMIND_FULL_HISTORY=false`). A fresh sync settles at ~250–280 GiB, about a quarter of
the full-history size. The cost: requests for old blocks, logs or receipts return nothing.
If you plan to expose a public RPC endpoint, set `NETHERMIND_FULL_HISTORY=true` before the
first sync. Switching an existing datadir means rebuilding it.

ethrex's smaller footprint comes from the same trade, made without asking you. It serves
nothing older than the point where its sync started, and keeps state for only the last
~128 blocks. Current balances work; anything historical fails. It's not a drop-in
replacement for a geth RPC endpoint.

One trap when reading other people's numbers: with full history on, nethermind measured
~251 GiB right after its snap sync finished, and only reached ~1.06 TiB once it had downloaded the
post-Merge history in the background. A disk figure without its timing can be off by 4×.

## Restarts: the test that matters

You will restart your node. Client upgrades, OS updates, power cuts, a full disk. What
the client does after that restart matters more day to day than how fast it synced the
first time, and the clients split into three groups.

First, one fact explains the groups. Peers on the network only serve the chain's
*current state* for roughly the last 128 blocks, about 25 minutes. A client that catches up
by importing the blocks it missed doesn't need that state, and geth and nethermind recovered
that way from every gap we tried. A client that needs peers to hand it state or headers
from before it stopped gets stuck once those are older than the window.

**1. Picks up where it left off: geth and nethermind.** We stopped geth for ~52 hours
(~15,400 blocks). On restart it kept its datadir, imported the missed blocks one by one,
and got back to the head. We tested nethermind (with full history on) at gaps from 12
minutes up to ~35 hours. It
resumed every time the same way. A 12-minute gap took ~2 minutes to close, a 4-hour gap ~8
minutes, and the ~35-hour gap (10,607 blocks) ~35 minutes, about 302 blocks a minute. No
gap size broke it.

**2. Falls off a cliff: ethrex.** We stopped ethrex for longer and longer gaps:

| Stopped for | Blocks missed | What happened |
|---|---|---|
| 12 min | 68 | resumed |
| 20 min | 108 | resumed |
| 23 min | 124 | resumed |
| 26 min | 132 | stuck: head frozen, couldn't fetch the missing headers |

Past ~25 minutes, ethrex couldn't get the data it needed from peers and stopped
advancing. After a routine 1.5–2 hour stop it went further: it threw away its fully synced
286 GiB datadir and started over from scratch, a re-sync that took 2h11m. That was on
v19.0.0. ethrex is moving fast and we haven't retested restarts on newer versions, so this
may already be better. But a node that can wipe itself after a two-hour maintenance window
is a hard sell for something that's supposed to run unattended. That's our best
explanation for why the fastest client in the field has almost no users.

**3. Can break mid-sync: besu.** besu's first sync reached a validated head in ~19h18m. A later re-run with history
pruning turned on hit a different problem. Our consensus client, an outdated prysm build
(v7.1.5) with a bug, stalled for ~28 hours. With nobody telling it which block was
current, besu's in-progress sync drifted outside that ~25-minute state window, and its
sync thread died. The process kept running and answering RPC, so it *looked* healthy, but it
had stopped syncing. Restarting it got stuck the same way, and we abandoned the run. Two
lessons: keep your consensus client healthy and updated while besu is syncing, and judge a
node by whether its disk and block height are moving, not by whether it answers RPC.

On the consensus side we only restart-tested prysm. It came back from its own database
in all four restarts without re-syncing; after a 30-minute stop it was back in sync in ~2m44s.

## Consensus clients: pick on disk and familiarity

All five consensus clients we swept (lighthouse, lodestar, grandine, teku, nimbus) synced to
a validating head with no crashes, starting from a recent checkpoint rather than from
genesis. With geth as the execution client that took 6–9 minutes each. Disk use, measured
minutes after sync:

| Consensus client | Disk after sync (geth paired) | Pruning setting |
|---|---|---|
| lodestar | ~177 MiB | `pruneHistory=true` |
| lighthouse | ~518 MiB | checkpoint sync (`checkpoint-sync-url`) |
| grandine | ~725 MiB | `--prune-storage` (without it, it keeps every state) |
| teku | ~936 MiB | `data-storage-mode=minimal` |
| nimbus | ~1.2 GiB | `history=prune` |

These grow as the client keeps running, but the three tiers held when we repeated the test
against nethermind and ethrex: lodestar and lighthouse lightest, teku and grandine in the
middle, nimbus heaviest. Any of them is fine; we suggest lighthouse as a lean, safe default.

None of the five crashed during its measured run. The reruns we needed traced to our own
measuring script, a too-small Java heap for teku, and an execution client still catching up
after an earlier lodestar crash loop on the shared host. Every serious problem in this test
came from the execution side, so that's the choice to spend your time on. (We only
restart-tested prysm on the consensus side, so that part is less proven.)

## What we'd tell a friend

- Run **geth** with **lighthouse** unless you have a reason not to.
- For client diversity, or a much smaller disk, run **nethermind** at its minimal-history
  default. Switch to full history before the first sync only if you'll serve public RPC.
- Size your disk for steady state, not for the number a client shows the moment it syncs.
- Test what happens when you restart, not just how fast the first sync goes.
- Keep an eye on **ethrex**. It's very fast; check its restart behaviour on a current release
  before you rely on it.
- Go in knowing the limits: **reth** and **nimbus_eth1** need a long first sync, and don't
  pair **erigon 3** with a checkpoint-synced consensus client yet.

---

Every measured number here comes from the raw results page, which also has the per-run detail,
the consensus clients' numbers against all three execution clients, and the full incident
log: [Ethereum client bake-off: raw results](https://eth2quickstart.com/blog/bakeoff-results).
