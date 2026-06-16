# Disk cleanup handoff — geth state bloat / freezer pruning

_Last updated: 2026-06-16_

## TL;DR

- Root `/dev/md2` hit **99% full** (1.7T/1.8T, ~35G free). Geth datadir
  `/home/eth/.ethereum/geth` is **~1.6T**.
- `geth snapshot prune-state` **does not work and never will** on this node —
  it's the wrong tool for our setup.
- The fix is **`geth prune-history --history.chain postmerge`**, wrapped in
  [`clean_geth_history.sh`](./clean_geth_history.sh).
- There is **only one geth database**. A whole-disk scan found exactly one
  `chaindata` + one `ancient`. No second/duplicate db.

## Why `prune-state` fails

Geth runs the **path-based state scheme (PBSS)**, not the old hash scheme.
`geth snapshot prune-state` is the hash-scheme offline pruner; under PBSS geth
exits with:

```
CRIT  Offline pruning is not required for path scheme
```

PBSS prunes live state **online/automatically**, so there is genuinely nothing
for `prune-state` to do. Evidence the node is PBSS:
`/home/eth/.ethereum/geth/triedb/merkle.journal` (~344M) and an `ancient/state`
freezer dir.

The stale `statebloom…bf.gz.tmp` (Oct 2023, ~196K) in the geth dir is a
leftover from an old hash-scheme prune attempt from before the PBSS migration.
Harmless; can be deleted.

## Where the space actually goes

| Component | Size | Touched by `prune-state`? | Touched by `prune-history`? |
|---|---|---|---|
| `ancient/chain` freezer (bodies + receipts, genesis→now) | **~1.2T** | ❌ never | ✅ pre-merge dropped |
| live Pebble state db (`*.sst`, ~11.8k files) | ~374G | (PBSS self-prunes) | ❌ |

So the dominant hog is the freezer, which only `prune-history` can shrink.

## The fix

`geth prune-history --history.chain postmerge` removes **pre-merge** block
bodies + receipts (genesis → Sep 2022 merge), keeps headers and everything
post-merge. A staking node does not need pre-merge history. Expected reclaim:
**~500–800G**.

### Run it (in screen, geth must be stopped — it's offline)

```bash
cd ~/eth2-quickstart
screen -S geth-prune ./clean_geth_history.sh
# detach: Ctrl-A then D   |   reattach: screen -r geth-prune
```

Or manually:

```bash
screen -S geth-prune
sudo systemctl stop eth1
geth prune-history --history.chain postmerge --datadir /home/eth/.ethereum
#   ^ run as the eth user, NOT sudo (sudo would use /root/.ethereum)
sudo systemctl start eth1
# Ctrl-A then D to detach
```

The script then patches `/etc/systemd/system/eth1.service` to add
`--history.chain postmerge` so the freezer stays pruned and pre-merge history
isn't re-fetched. `install/execution/geth.sh` also sets this flag for fresh
installs.

### Caveats

- **Offline + validator downtime**: geth is down for the duration (likely a few
  hours on ~1.2T). The CL/validator misses attestations until geth restarts and
  catches up the gap. Run in a low-duty window.
- **One-way**: un-pruning means re-downloading history.
- Does **not** shrink the ~374G live state. If that needs to come down to
  ~130–150G, do a separate from-scratch snap re-sync (bigger downtime; not the
  emergency). PBSS keeps live state self-pruned in normal operation.

## Did NOT need

- Re-syncing from scratch — rebuilds the same 1.2T freezer; only worth it for
  the live-state reclaim, separately.
- A second datadir cleanup — there is only one.
