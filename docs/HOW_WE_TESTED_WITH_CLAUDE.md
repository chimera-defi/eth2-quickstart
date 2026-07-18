# How We Ran a 23-Day Ethereum Client Bake-Off With Claude

*A companion to [the results write-up](CLIENT_BAKEOFF_BLOG.md). That post is about the clients. This one is about the machine that tested them: the agent orchestration model, the harness we built to keep ourselves honest, and what actually breaks when a benchmark runs for three weeks on a shared host with an AI in the driver's seat.*

The [client bake-off](CLIENT_BAKEOFF_BLOG.md) measured, for every execution and consensus client [eth2-quickstart](https://github.com/chimera-defi/eth2-quickstart) supports, two numbers: final synced disk footprint and sync duration. In practice that meant **seven execution-client syncs** against fixed Prysm, then a **five-way consensus-client sweep** against a fixed execution client (Prysm was held constant only for the execution-client sweep) — one candidate at a time, on one shared semi-production host, from **June 22 to July 14, 2026 — 23 days end-to-end**.

A campaign that long, that sequential, and that easy to get subtly wrong is exactly the kind of work you don't want a human babysitting around the clock. So we didn't. It was run by **Claude** — Claude Opus 4.8 as the orchestrator, fresh Claude Sonnet subagents as builders, and a set of delegate models for the cheap and the sandboxed work — with a human operator holding the handful of levers that genuinely need a human. This is the story of that setup, written both for the curious and for the next person (or agent) who has to run something like it.

> **Up front, honestly:** this was AI-*driven*, not AI-*unsupervised*. Every destructive action against the live node was gated behind an explicit human confirmation, every result was committed under conventional-commit review, and no agent could merge its own pull request. The interesting claim here is not "the AI did it alone" — it's that the *right division of labor* between an agent and an operator let a 23-day, disk-and-timing-sensitive benchmark run to completion without a person watching it sync.

---

## The shape of the problem

Benchmarking a sync client is deceptively expensive:

- **It's slow.** A single mainnet sync ranges from ~2 hours (ethrex, snap) to *never finishes in three days* (the full-sync-only clients). Each candidate got a **72-hour cap**.
- **It's sequential.** One shared host, one execution slot, one consensus slot. You cannot run geth and nethermind side by side and call the disk numbers fair — they'd contend for CPU, IO, and peers. So candidates run **strictly one at a time**.
- **It's easy to measure the wrong thing.** A client that "installed and followed the chain" can still be silently broken (0 peers, frozen execution head). A datadir size means nothing if the client was accidentally running in archive mode. A footprint sampled mid-compaction over-counts.
- **It's destructive.** Measuring the next client means wiping the last one's datadir on a shared box that also runs other people's work.

Multiply that across the whole supported field of clients and three weeks and you have a task defined less by any single hard step than by *sustained correctness* — the discipline to run the same careful protocol dozens of times, capture the right sample on every exit path, and never let a shared-host quirk masquerade as a client property. That is what the harness and the orchestration model exist to enforce.

---

## The orchestration model

The core design choice was to **decouple node wall-clock from agent wall-clock**, and then to decouple **durable state from agent context**. Get those two right and a three-week campaign stops needing a three-week attention span.

### 1. The node runs; the agent doesn't watch it run

Every client is installed as a **native systemd service** (`eth1.service`, `cl.service`) — no Docker — and the sampling harness runs as a detached process. A sync can proceed for 72 hours whether or not any Claude session is alive. Long runs were owned by **detached `tmux` sessions** so a sync survived an agent session ending, being compacted, or dying outright. On several occasions the orchestrating session *did* die mid-run (once to an out-of-memory event under host load); the systemd unit and its sampler kept going, and a fresh session picked the campaign back up from durable state with nothing lost.

Instead of polling logs, the agent armed **event-driven watchers** — small background scripts that fire a single notification on a terminal condition (`DRIVER_EXIT`, service death, a 72-hour deadline) — so the orchestrator slept until something decision-worthy happened rather than burning attention on a progress bar.

### 2. Three tiers of agent, by cost and capability

Not every sub-task deserves the strongest, most expensive model. The campaign used a deliberate hierarchy:

| Role | Who | What they did |
|------|-----|---------------|
| **Orchestrator / reviewer** | Claude Opus 4.8 | Planned the queue, made the judgment calls, reviewed every committed diff, wrote the durable state. Did *not* hand-write most client code. |
| **Builders** | fresh Claude Sonnet subagents | Implemented harness fixes and config changes against a written brief, then reported a short result summary back — keeping the bulk of the tokens out of the orchestrator's context. |
| **Delegates** | cheaper / sandboxed models | Cheap read-only research and review, and any genuinely sandboxed work, routed through wrapper binaries that handle auth, fallback, and telemetry. |

The point of the hierarchy is **context economy**. A builder subagent can read ten thousand lines of client source, produce a three-line commit, and return "done, here's the diff" — and the orchestrator never has to hold those ten thousand lines. The orchestrator reviews the *diff*, not the *investigation*.

### 3. Durable state is the backbone

The single most important lesson of the campaign (see [the issues log, §E3](CLIENT_BAKEOFF_ISSUES_LOG.md)) is this:

> **The orchestrating agent's context window — not node wall-clock — is the real scaling bottleneck of a long agent-driven campaign.**

The harness had already solved node time (detached services). But every status check, every diagnosis, every "is it stalled?" pulled raw `journalctl`, `du`, and RPC output into the context window, and *that* filled up in hours, not weeks. The fix was architectural, and it generalizes far beyond Ethereum:

- **Push conclusions down to where the data lives.** The harness computes a verdict (`SYNCING` / `STALLED_NO_PEERS` / `STALLED_NO_PROGRESS` / `SYNCED` / `CAPPED`) so the agent reads a *word*, not a log.
- **Keep durable state small and in files.** Results, the governance rules, the queue, and a live self-handoff note live in a handful of markdown files. A mid-campaign context clear becomes a non-event: the next session reads the handoff and continues.
- **Keep transient investigation off the context path.** Logs, probes, and sample dumps are ephemeral. They get computed, summarized, and dropped — never carried.

Separating *durable state* (small, persistent, decisions) from *transient investigation* (huge, ephemeral, telemetry) is the difference between an agent that can run a 23-day campaign and one that suffocates on its own status checks by day two.

### 4. Governance the agent could not override

A handful of rules were treated as non-negotiable, and they are what made it safe to let an agent drive:

- **One candidate at a time. No batching.** Ever.
- **72-hour cap** per candidate; **footprint is the last near-cap sample, never the peak** (on-disk size oscillates during compaction — see [issues log §E2](CLIENT_BAKEOFF_ISSUES_LOG.md)).
- **Destructive data-cleans are gated** behind an explicit `ETH2QS_BAKEOFF_CONFIRMED=yes`, and wiping the *live* shared node always required a fresh human go-ahead — surfaced as a structured decision prompt, never assumed.
- **Conventional Commits, new commits only**, never a force-push to `master`, secrets never written to disk or committed.
- **An agent cannot merge its own pull request.** A human does that.

None of these are clever. All of them are the reason a three-week autonomous benchmark against real client software didn't turn into a three-week autonomous incident.

---

## The harness

The measurement machinery lives in [`test/bakeoff/`](../test/bakeoff). It's plain bash — deliberately, so it has no runtime that can drift out from under a systemd service — and it's built around a few pieces:

- **[`run_bakeoff.sh`](../test/bakeoff/run_bakeoff.sh)** — the sequential orchestrator. Walks a candidate manifest one row at a time, with a resume guard so a killed campaign restarts where it left off rather than re-running finished candidates.
- **[`run_candidate.sh`](../test/bakeoff/run_candidate.sh)** — the single-candidate runner: hard-reset the shared systemd units, install the client under test, apply resource caps, then sample to a verdict. It captures the measurement on **every** exit path — success, cap, *and* error — always **before** the destructive teardown.
- **[`lib.sh`](../test/bakeoff/lib.sh)** — the shared probe/sample library: the sampling loop, the disk snapshotter, and the config-optimality gate.
- **[`apply_resource_caps.sh`](../test/bakeoff/apply_resource_caps.sh)** — systemd `CPUQuota`/`MemoryMax` caps so a heavy client's sync can't starve the co-resident workloads on the shared host.
- **[`summarize.sh`](../test/bakeoff/summarize.sh)** — turns the per-run artifacts into the results table, splitting rows by whether the config was verified optimal.
- **[`run_anchor_rotation.sh`](../test/bakeoff/run_anchor_rotation.sh)** — the anchor-preserving mode used for the consensus-client sweep (below).

### The config-optimality gate, and why it needed six bug-fixes

Early in the campaign we corrupted our own results: we recorded a footprint *before* confirming the client was running in its most disk-efficient mode. reth, left at its defaults, runs a ~2.8 TiB **archive** node; we nearly recorded that as "reth's footprint" when the pruned full-node number (`--full`) is ~1.2 TiB. A benchmark that measures your own misconfiguration is worse than no benchmark, because it looks authoritative.

So the harness grew a **config-optimality gate**: before it trusts a footprint, it inspects the *actually-generated, actually-running* config and stamps every row `config_optimal=yes|no`. `summarize.sh` puts non-optimal rows in a separate "superseded" section where they can't contaminate the ranking.

The gate itself needed **six bug-fixes across three review rounds** before we trusted it — and every one of those bugs was the same species: *"the flag I asserted on doesn't match the real generated config"* (a separator, a quoting rule, a section header, a value format). That is precisely the failure mode the gate exists to catch, turned on itself. We consider the gate's own debugging history a feature: the credibility of every number in the results doc rests on it, so it earned its paranoia. It also forced us to *empirically settle* config questions we'd otherwise have guessed at — most notably nimbus_eth1's history-pruning flag, where the binary's `--help` and the online docs flatly contradicted each other and only a live run (`prune=true` logging `Pruning history … pruned=N` during import) resolved it.

### Anchor-preserving mode: don't re-sync the world five times

The consensus-client matrix holds the execution client constant and cycles the CL. Naively, that's five full EL re-syncs — days of wasted work measuring the *same* EL. Anchor-preserving mode (`ETH2QS_BAKEOFF_ANCHOR_EL=…`) keeps a single already-synced execution client running and cycles **only** the `cl` service per candidate, purging just the consensus datadir between runs. Five CL candidates, one EL sync. We ran the whole sweep twice — against an ethrex anchor and again against a geth anchor — precisely to *prove* the EL/CL decoupling empirically rather than assert it. The ranking reproduced.

---

## War stories the harness lived through

Every one of these produced a fix that shipped back into eth2-quickstart, so the next operator (human or agent) doesn't re-live it. The full set is in the [issues log](CLIENT_BAKEOFF_ISSUES_LOG.md); the greatest hits:

- **The 13-hour silent stall (nethermind).** Everything looked healthy — beacon `sync_distance=0`, `el_offline=false`, `eth_syncing=false` — but 13.3 hours in, the validated execution head was frozen at **block 4,651** with **0 peers**. nethermind's `Network.LocalIp` was pinned to `127.0.0.1`, so it advertised *loopback* for P2P and no peer could ever reach it. This is the trap that reshaped our verdict logic: `eth_syncing=false` is returned **both** before a sync starts and after it finishes, so it is never a standalone "done" signal. A real sync verdict must combine **peers > 0 AND execution head advancing AND beacon `sync_distance`** — never any one of them alone.
- **The deadlock that answered RPC while it was dead (besu).** A stale pinned CL (prysm v7.1.5, a PeerDAS bug) stalled the beacon for ~28 hours. With nothing driving `forkchoiceUpdated`, besu's snap-sync pivot block aged out of the network's ~128-block (~25-minute) servable-state window, the world-state heal became un-completable, and besu's downloader thread died — while the process stayed alive and kept answering `eth_blockNumber`. Lesson: **liveness is not progress.** Judge a sync by disk growth and DB writes, not by whether RPC responds. This is also what motivated the harness **stall-watchdog** (opt-in: restart only the stuck unit a bounded number of times, then fail the row cleanly rather than spinning to the 72-hour cap).
- **The sprinter with a glass jaw (ethrex).** Fastest cold sync in the field (~2h16m), but after a restart with a gap past **~128 blocks (~24–25 minutes)** it throws away its entire synced state and re-syncs from scratch. We bisected the cliff edge by controlled `stop`/`wait`/`start` cycles: 23 min / 124 blocks resumed cleanly, 26 min / 132 blocks stuck. Fast to stand up, brutal to operate — the best explanation we found for why the fastest-syncing client is one almost nobody runs.
- **The detached-shell landmine (SIGTTIN).** A client install that read the terminal (`geth version | head -1`) worked interactively and **hung for 90 minutes** when run from a detached tmux session in a non-foreground process group — the tty read raised `SIGTTIN` and stopped the whole subtree. Fix: redirect `</dev/null` on unattended invocations. The kind of bug you only meet when your automation genuinely runs unattended.
- **The measurement that vanished at the cap (capped-path footprint).** The disk snapshot was taken only inside the *synced* branch. When a slow client hit the 72-hour cap, the script fell through to teardown — which wiped the datadir — and snapshotted *after* the wipe. reth's partial footprint survived only because we could reconstruct it from the raw sample series. Fix: snapshot on every exit path, before teardown. **The cap path is the one you forget, and it's the one a slow client actually takes.**

There were smaller ones too — GitHub release API rate limits (authenticate even for public metadata), a `du | awk` pipeline that a vanishing file under `pipefail` turned into a spurious run-killing failure, interactive `unzip` prompts hanging a detached install. Each is a paragraph in the issues log and a commit in the history.

---

## What we'd tell the next person running this

- **Decouple the three clocks.** Node wall-clock (solve with detached services), agent wall-clock (solve with event-driven wakeups), and — the one everybody forgets — agent *context* (solve by pushing conclusions down to the data and keeping durable state in small files). The third is the real limit.
- **Measure on every exit path, before you destroy anything.** Success is the easy path. The cap and the error paths are where your data quietly disappears.
- **Gate your benchmark on config, not just on outcome.** Stamp every number with "was this the client's best mode?" or you will eventually publish a measurement of your own mistake.
- **Give an agent a job and a fence.** The division that worked: the agent owns the tedious, sustained correctness (run the protocol, capture the sample, diagnose the stall); the human owns the few irreversible levers (wipe the live node, merge the PR). Neither could have done this alone in a reasonable amount of time.

### Honest limitations

This is a real benchmark, not a lab result. It ran on a **shared, semi-production host** (12 cores, ~62 GB RAM, co-resident workloads), which is representative of how many people actually run nodes but introduces contention the numbers can't fully isolate. Each client was measured on **one run** at a pinned version, so a single result is a data point, not a distribution. And an AI-in-the-loop campaign carries its own risk surface — which is exactly why the governance fence (one-at-a-time, confirmation-gated destruction, human merges, `config_optimal` stamping) was non-negotiable rather than advisory.

---

## Reproduce it

The harness is in the repo and the data is committed:

- **The harness:** [`test/bakeoff/`](../test/bakeoff) — start with [`run_candidate.sh`](../test/bakeoff/run_candidate.sh) and [`lib.sh`](../test/bakeoff/lib.sh).
- **The results:** [`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md) — every measured footprint, sync time, and verdict, with methodology.
- **The narrative:** [`CLIENT_BAKEOFF_BLOG.md`](CLIENT_BAKEOFF_BLOG.md) — the findings write-up this post accompanies.
- **The war stories:** [`CLIENT_BAKEOFF_ISSUES_LOG.md`](CLIENT_BAKEOFF_ISSUES_LOG.md) — symptom → root cause → fix → takeaway for every real issue.
- **Running a node for real:** [`blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md`](blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md) — turning these findings into an operator's decision.

The one-line takeaway from the numbers: **nethermind won on disk (~251 GiB, the smallest pruned-comparable footprint), ethrex won on speed (~2h16m) but pays it back on every restart, and the consensus layer is effectively solved — all five CLs checkpoint-synced in ~22 minutes with zero failures.** The [results post](CLIENT_BAKEOFF_BLOG.md) has the why.
