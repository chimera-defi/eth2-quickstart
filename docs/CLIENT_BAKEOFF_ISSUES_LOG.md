# Eth2 Client Bake-off — Issues Log (war stories)

_An append-only log of every real issue we hit running a baseline-anchored bake-off of 7 execution
clients × Prysm and Geth × 5 consensus clients on a shared semi-prod Linux host. Written for the
eventual blog post, and to save the next human or agent the hours we spent. Each entry: **Symptom →
Root cause → Fix → Takeaway**, with the literal error/log signatures you'd grep for. Companion to
`CLIENT_BAKEOFF_RESULTS.md` (the clean metrics) — this is the messy reality behind those numbers._

**Environment:** shared host (12 cores, ~62 GB RAM), co-resident agent workloads, Ubuntu 24.04.
Clients installed as native systemd services (no Docker), checkpoint-synced CL, `--mev=none`, no
validator keys. Resource-capped via systemd (`CPUQuota`/`MemoryMax`) to protect co-residents.

---

## A. Execution-client install / triage issues (Stage A)

### A1. reth — shared JWT not wired → Engine API 401 → frozen head
- **Symptom:** Prysm reported `el_offline=true` on early samples; beacon head frozen at the checkpoint slot. reth was up but the CL couldn't drive it.
- **Root cause:** reth wasn't passing `--authrpc.jwtsecret` to the shared secret that the rest of the stack uses, so Prysm and reth generated *different* auto-JWTs → every Engine API call 401'd.
- **Fix:** wire `--authrpc.jwtsecret $HOME/secrets/jwt.hex` (the shared secret), plus explicit `--authrpc.addr/--authrpc.port` and `--datadir`. Also enabled HTTP-RPC on `127.0.0.1` (`eth,net,web3`) for monitoring parity with the other ELs. Commits `fix(reth): wire shared JWT…` + `fix(reth): enable HTTP-RPC…`.
- **Takeaway:** the #1 EL↔CL integration failure is a JWT mismatch. If the beacon says `el_offline=true` but the EL process is healthy, suspect the JWT before anything else. One shared `jwt.hex`, passed explicitly to both sides.

### A2. reth — defaults to ARCHIVE (~2.8 TiB), not a pruned full node
- **Symptom:** reth datadir ballooning far past the other ELs.
- **Root cause:** reth with no sync flag runs an **archive** node (retains all historical state). We were about to record an accidental ~2.8 TiB archive as reth's "footprint."
- **Fix:** pass `--full` (pruned full node ~1.2 TiB: keeps full block/receipt history, prunes historical state changesets+indices, retains ~last 10k blocks of state). Commit `fix(reth): run pruned full node (--full)`.
- **Takeaway:** always confirm each EL's sync/prune mode before trusting a datadir size. reth specifically defaults to archive — pass `--full` unless you explicitly want archive. (See the disk/sync-flag audit, §C5.)

### A3. nethermind — `Engine` in the public JSON-RPC module list broke the auth gate
- **Symptom:** Engine API auth behaved incorrectly; RPC module exposure wrong.
- **Root cause:** `Engine` was listed in the main `JsonRpc.EnabledModules` (the unauthenticated public RPC), which conflicts with the dedicated authenticated Engine endpoint.
- **Fix:** drop `Engine` from `JsonRpc.EnabledModules`; the Engine API lives only on the authenticated `:8551` path. Commit `fix(nethermind): drop Engine from main JsonRpc.EnabledModules`.
- **Takeaway:** never put `Engine` in the public RPC module list. It belongs only on the JWT-authenticated engine port.

### A4. nethermind — interactive unzip prompt hung the install
- **Symptom:** install stalled silently.
- **Root cause:** `unzip` prompting to overwrite an existing file with no `-o`, waiting on stdin that never comes in a detached run.
- **Fix:** `unzip -o` (overwrite, non-interactive). Commit in task #9.
- **Takeaway:** every archive/extract/download in an unattended installer must be non-interactive (`unzip -o`, `curl -fsS`, `apt-get -y`, `DEBIAN_FRONTEND=noninteractive`). One interactive prompt hangs the whole detached run.

---

## B. Consensus-client install / triage issues (Stage A)

### B1. lodestar — `catalog:` protocol install failure
- **Symptom:** lodestar build/install failed resolving dependencies with a `catalog:` protocol error.
- **Root cause:** the `catalog:` workspace-protocol version specifier wasn't resolvable in our install path.
- **Fix:** task #11. (Install path adjusted so dependencies resolve without the catalog protocol.)
- **Takeaway:** monorepo/workspace protocol specifiers (`catalog:`, `workspace:`) can leak into release installs — pin/resolve them explicitly.

### B2. lodestar — checkpoint sync flags passed the wrong way
- **Symptom:** lodestar wouldn't checkpoint-sync; node options ignored. High `restErr` in samples.
- **Root cause:** node options were passed via `--paramsFile` (which is for network/spec params), not the node runtime config.
- **Fix:** load node options via `--rcConfig` (or direct CLI flags), reserve `--paramsFile` for network params. Commit `fix(lodestar): load node options via --rcConfig not --paramsFile`.
- **Takeaway:** lodestar splits *network params* (`--paramsFile`) from *node options* (`--rcConfig`/CLI). Mixing them silently drops your settings.

### B3. grandine — node settings rejected from the config file
- **Symptom:** grandine ignored/failed on settings placed in a configuration file.
- **Root cause:** grandine expects node settings as **CLI flags**, not via `--configuration-file`. We also had a dead `grandine_base.toml` + config-verify references for a config format grandine doesn't consume.
- **Fix:** move node settings to CLI flags; delete the dead `grandine_base.toml` and its references. Commits in tasks #12, #13.
- **Takeaway:** don't assume every client takes a config file. grandine is CLI-flag driven; verify each client's actual config surface before templating one.

### B4. teku — unknown config keys crash-loop
- **Symptom:** teku beacon crash-looped on startup.
- **Root cause:** `teku_beacon_base.yaml` contained config keys teku didn't recognize → hard startup failure.
- **Fix:** remove the invalid keys. Commit `fix(teku): remove invalid config keys blocking beacon startup`.
- **Takeaway:** teku fails closed on unknown keys (good!). Validate config keys against the exact client version; don't copy keys between client versions blindly.

### B5. nimbus — genesis sync instead of checkpoint sync
- **Symptom:** nimbus tried to sync from genesis (impractically slow) rather than from a checkpoint.
- **Root cause:** missing checkpoint bootstrap step; nimbus needs `trustedNodeSync` to seed state from a checkpoint URL before the service starts.
- **Fix:** add a `trustedNodeSync` checkpoint bootstrap. Commit `fix(nimbus): checkpoint-sync via trustedNodeSync bootstrap`.
- **Takeaway:** nimbus checkpoint sync is a *pre-start bootstrap* (`trustedNodeSync`), not a runtime flag like other CLs. Easy to miss.

### B6. prysm — live version check 403 on rate-limited hosts
- **Symptom:** `prysm.sh` failed its live version check (HTTP 403) against prysmaticlabs.com on rate-limited/shared hosts.
- **Root cause:** `prysm.sh` phones home to resolve the latest version; that endpoint 403s under rate limits.
- **Fix:** pin `USE_PRYSM_VERSION` to the locally-cached binary (parsed from `dist/beacon-chain-v*-linux-amd64`) via a systemd `Environment=` line, bypassing the live check. (Later caused a CI regression that was separately fixed — see §C6.)
- **Takeaway:** installers that "phone home" for a version are fragile on shared infra. Pin to the downloaded artifact's version and skip the check.

---

## C. Harness / methodology issues

### C1. GitHub release API rate limits broke asset downloads
- **Symptom:** intermittent download failures resolving GitHub release assets.
- **Root cause:** unauthenticated GitHub API calls hit the low anonymous rate limit on a shared host.
- **Fix:** authenticate with `gh auth token` → `GITHUB_TOKEN` for all release API calls. Commit `fix(bakeoff): authenticate GitHub release API via gh token`.
- **Takeaway:** always auth the GitHub API in automation, even for public release metadata. The anonymous limit is far lower than it looks on a busy host. (Never write the token to disk — read it at call time.)

### C2. doctor/stats `--json` empty + unbounded sampling calls
- **Symptom:** sample records had empty `doctor` JSON; some sampling calls could hang.
- **Root cause:** a `doctor --json` output gap, and sampling sub-commands weren't time-bounded.
- **Fix:** investigated/fixed the empty `doctor --json`; wrapped doctor/stats sampling in `timeout 30s`. Tasks #8, harness hardening.
- **Takeaway:** every probe in a sampling loop needs a hard `timeout`. One hung probe stalls the whole sampler and you lose the time series.

### C3. Candidate isolation — stale services bled across candidates
- **Symptom:** risk of a previous candidate's `eth1`/`cl` services still running when the next started.
- **Root cause:** no explicit teardown at candidate start.
- **Fix:** stop+disable `eth1`/`cl` at the start of each candidate. Commit in task #10.
- **Takeaway:** sequential benchmarks must hard-reset shared singletons (systemd units, ports, datadirs) at the *start* of each run, not rely on the previous run's cleanup.

### C4. Capped-path footprint capture gap (cost us reth's clean footprint)
- **Symptom:** reth hit the 72h window cap; its footprint file (`disk-synced.tsv`) was absent and `disk-after-cleanup.tsv` was ~0. The partial footprint survived only because we could reconstruct it from `samples.jsonl`.
- **Root cause:** `bakeoff_snapshot_disk "$out/disk-synced.tsv"` was called ONLY inside the synced branch. When the window CAPS, the script fell through to teardown (`clean-data --confirm` wipes datadirs) and only snapshotted *after* the wipe.
- **Fix:** snapshot `disk-final.tsv` on ALL exit paths *before* the cleanup; `summarize.sh` reads `disk-synced.tsv` when `fully_synced=yes`, else falls back to `disk-final.tsv`. Commit `fix(bakeoff): capture partial footprint on window-cap path before teardown clean` (af0d77f).
- **Takeaway:** capture your measurement on *every* exit path (success, cap, error) and always *before* destructive teardown. The cap path is the one you forget — and it's the one a slow client actually takes.

### C5. Disk/sync-flag audit — make footprints apples-to-apples
- **What:** before running the slow ELs, we audited every EL's sync/prune mode so footprint numbers reflect each client's *best* config, not an accidental archive. (Triggered by geth's `--history.chain postmerge` post-merge history prune.)
- **Result:** 6 of 7 ELs were already disk-optimal (geth snap+postmerge-prune, besu SNAP+BONSAI, nethermind SnapSync+FastBlocks, ethrex snap, erigon OtterSync+`prune.mode=full`, nimbus_eth1 fast-sync). **reth was the sole gap** (archive→`--full`, see A2).
- **Takeaway:** footprint comparisons are only fair if every client runs its pruned/snap mode. Audit *before* you spend days syncing. (Time-to-sync still isn't apples-to-apples: full-sync ELs execute all ~25M blocks; only footprint is comparable.)

### C6. prysm-pin CI regression (PR #186)
- **Symptom:** the prysm version-pin fix (§B6) broke a CI check.
- **Root cause:** the pinning logic needed guarding so it didn't fire/parse in the CI environment.
- **Fix:** guarded the `USE_PRYSM_VERSION` pin (`find … dist/` only when the dir exists). Task #25.
- **Takeaway:** installer logic that reads the local filesystem (`find dist/`) must be guarded for environments where that path doesn't exist (CI, fresh clone).

### C7. SIGTTIN — an install that read the tty hung a detached run for 90 minutes
- **Symptom:** a bake-off candidate install launched from a detached `tmux` session hung and eventually hit the 90-minute install timeout (`install_exit_code=124`), leaving a subtree of *stopped* (not killed) processes behind. The identical install run interactively (attached terminal) completed fine — so it looked like a phantom, environment-only hang.
- **Root cause:** the install shelled out to `geth version | head -1` to log the binary version. In a detached session the process ran in a **non-foreground process group** against a controlling tty it did not own; the `geth version` read from that tty raised **`SIGTTIN`**, which *stops* the whole process subtree rather than killing it. The install never progressed and the outer `timeout` eventually fired (rc=124). Not a geth defect — a shell-job-control interaction that only surfaces when nothing owns the foreground.
- **Fix:** redirect stdin from `/dev/null` on unattended invocations so no child can block on a tty read — both at the harness install entrypoints and defensively at the `geth version` call site. Commits [`fix(bakeoff): prevent SIGTTIN install-hang by giving installs /dev/null stdin`](https://github.com/chimera-defi/eth2-quickstart/commit/df743ce528a5d60aa7d449cdfad427143b95966b) and [`fix(geth): guard geth version call against SIGTTIN install-hang`](https://github.com/chimera-defi/eth2-quickstart/commit/f495892aa5475f867299e77bfcbf59f28af3fdcd).
- **Takeaway:** any command in an unattended pipeline that *might* read the terminal must have its stdin redirected from `/dev/null`. Because `SIGTTIN` **stops** rather than kills, the tell is a hung run with children in the `T` (stopped) state, not a crash — a failure mode you only meet once your automation genuinely runs detached. (Same family as the interactive-`unzip` hang in A4, one layer deeper.)

### C8. teku anchor-watchdog false positive — `anchor_synced=no` on a demonstrably healthy anchor
- **Symptom:** during the nethermind-anchor CL-matrix sweep (2026-07-26, run_id `client-bakeoff-anchor-nethermind-2026-07-26b`), teku's row finalized `anchor_synced=no` on **both** of its runs (first attempt and the deliberate clean re-read), despite the nethermind anchor being independently verified at the exact mainnet head (`eth_syncing=false`, teku itself reporting `sync_distance=0`, `is_optimistic=false`) at the moment of each check. Both runs' sync-time/footprint measurements were otherwise valid.
- **Root cause:** the anchor-mode watchdog in `run_candidate.sh` (the `anchor_miss` check, `run_candidate.sh:284-323`) polls the anchor's `eth_syncing` and treats a sample as a "miss" unless it parses as `currentBlock >= highestBlock` (with `highestBlock != "0x0"`) — a nethermind object-form response, since a synced nethermind returns an *object*, not boolean `false` (a gotcha already documented in `CLIENT_BAKEOFF_RESULTS.md`'s Gotchas section). teku's notably slow JVM warm-up left the anchor briefly **undriven** — no `forkchoiceUpdated` arriving from teku while it spins up — during which the anchor's reported `currentBlock` transiently lagged the live `highestBlock` it was tracking from the network. Two samples landing during that lag window tripped the watchdog's `anchor_miss_streak -ge 2` rule and touched `.anchor-poisoned`, which finalizes `anchor_synced=no` at teardown regardless of the anchor's true state a moment later. Reproducing on a deliberate second (clean) re-read is what promotes this from a fluke to a documented harness limitation (`CLIENT_BAKEOFF_RESULTS.md:138,146`).
- **Fix:** none landed yet. `CLIENT_BAKEOFF_RESULTS.md:146` records the proposed direction: the watchdog should tolerate a bounded head lag, or only start sampling once the CL under test itself reports synced, rather than treating an object-form transient lag as an immediate invalidation.
- **Takeaway:** `anchor_synced=no` is not proof the anchor was actually unhealthy — it can be an artifact of a slow-warming CL transiently leaving the anchor undriven while the anchor's own `eth_syncing` reports live network head as `highestBlock`. Always independently re-check the anchor's state (peer-driven head, `sync_distance`, `is_optimistic`) at the moment of a `no` verdict before discarding an otherwise-clean row. (Same family of trap as the nethermind object-form `eth_syncing` gotcha in the Gotchas section of `CLIENT_BAKEOFF_RESULTS.md` — one layer further in, at the watchdog that consumes it.)

### C9. lodestar gapped run — a 76-minute measurement that was really "waiting for the anchor," not lodestar
- **Symptom:** in the same 2026-07-26 nethermind-anchor sweep, lodestar's first CL-matrix run recorded a sync time of **~76m14s** — an outlier next to the other four CLs' ~7-10 minute checkpoint syncs on the same anchor.
- **Root cause:** an *unrelated* crash-loop incident on this host had left the shared nethermind anchor EL roughly **2 days behind** mainnet tip before this run began. lodestar's beacon could not report `is_optimistic=false` until the anchor closed that gap, so almost the entire 76 minutes was the anchor catching up, not a property of lodestar's own sync path.
- **Fix:** none needed for lodestar. Once the anchor was back at head and the crash-loop root cause was fixed, lodestar was re-measured from scratch: **~7m36s / 186,083,466 B (~178 MiB)**, `anchor_synced=yes`, `config_optimal=yes` — in line with the other four CLs and within ~1 MiB of its geth-anchor footprint (~177 MiB). The discarded first run is retained in the artifacts for provenance as `nethermind__lodestar.gapped-run-76m`; the clean re-run is the published row (`CLIENT_BAKEOFF_RESULTS.md:145`).
- **Takeaway:** a CL's measured sync time in anchor mode is only as trustworthy as the anchor's own state at the *start* of that window. Always confirm the anchor is genuinely at head — not just "active" — before trusting a CL row's sync-time number, especially after any incident (crash-loop, restart, prior poisoning) that could have left the shared anchor behind. This is the CL-matrix-sweep analogue of besu's prysm-stall deadlock (D-section) and nethermind's zero-peer stall (D3): a shared, silently-lagging dependency can make an otherwise-healthy candidate's number look wrong.

---

## D. Stage B full-sync issues (the expensive ones)

### D1. erigon — OtterSync + checkpoint-synced Prysm gap-close DEADLOCK (no-sync)
- **Symptom:** erigon's execution head froze a few thousand blocks behind tip; beacon stayed `is_optimistic=true` indefinitely; neither side issued the `forkchoiceUpdated` that would close the gap. Raising the CL CPU cap 200%→600% advanced the head ~5k blocks then re-froze.
- **Root cause:** a genuine gap-close deadlock between erigon3 OtterSync and a checkpoint-synced Prysm — not resource starvation. The backward-download gap (>96 blocks) never closes.
- **Fix:** none — terminated per operator decision ("record no-sync, move on"). Recorded as the one Stage B no-sync.
- **Takeaway:** a checkpoint-synced CL + an EL that needs to backfill can wedge in mutual "you go first" optimism. The tell: beacon `is_optimistic=true` forever with a head frozen *near* tip. Raising caps to rule out starvation is a good diagnostic; if it advances then re-freezes, it's a deadlock, not resources.

### D2. reth — `--full` too slow to finish in 72h (window-capped)
- **Symptom:** reth `--full` capped at the 72h window at ~21% gas-weighted execution (block 11.97M/25.4M).
- **Root cause:** reth `--full` is the **only no-snap EL** — it executes every block sequentially. Full block execution of ~25M blocks doesn't finish in 3 days under resource caps.
- **Fix:** none needed — expected. Recorded as capped/partial (~0.97 TiB at 21% exec; projected final ~1.1–1.2 TiB because `--full` downloads full block/receipt history up front, which dominates disk).
- **Takeaway:** if a client has no snap mode, budget *days* and expect a cap on a time-boxed run. Don't confuse "capped" with "broken." Footprint can still be projected because history download (not state execution) dominates the disk.

### D3. nethermind — P2P pinned to LOOPBACK → 0 peers → 13h silent stall ⚠️ (the worst trap)
- **Symptom:** looked alive — beacon `sync_distance=0`, `el_offline=false`, `eth_syncing=false` — but after **13.3 hours** the validated execution head was frozen at **block 4,651** (tip ~25.4M). Logs: `Waiting for peers... 48012s`, `Connected to 0 bootnodes, 0 trusted/persisted nodes`, `Could not communicate with any nodes`. The EL was only optimistically inserting Prysm's live-head blocks (`Syncing... Inserting block 25,42x,xxx`) it could never execute (no state).
- **Root cause:** `"Network": { … "LocalIp": "127.0.0.1" }` in both `install/execution/nethermind.sh` and `configs/nethermind/nethermind_base.cfg`. nethermind's `Network.LocalIp` is the address it **binds and advertises for P2P** — pinning it to loopback means 0 inbound/outbound peers and discovery announces loopback. The firewall was fine (30303 tcp+udp open); purely config.
- **Fix:** drop `LocalIp`, advertise the real IP via `"ExternalIp": "$(curl -s v4.ident.me)"` (mirrors Prysm's `p2p-host-ip`). Commit `fix(nethermind): advertise external IP for P2P, not loopback`. Relaunched clean → immediately downloaded Beacon Headers at ~13k blk/s (peers connected, real snap-sync). Audited the other ELs: **nethermind was the only one** pinning P2P to loopback; the rest external-bind by default.
- **Takeaway (humans):** bind *RPC/Engine* to loopback (`127.0.0.1`), but **NEVER** the *P2P/discovery* address — that must be your external interface or peers can't reach you. Two different bind settings; don't conflate them. If peers stay at 0, check the advertised P2P IP before the firewall.
- **Takeaway (agents):** `eth_syncing=false` is a **trap** — it returns false *both* before sync starts (no pivot) *and* after it finishes. Never treat it as a standalone "synced" signal. Real snap-sync shows headers downloading at thousands of blk/s and a climbing head. Verdict logic must combine **peer-count > 0 AND EL-head advancing AND beacon sync_distance**.

---

## E. Process / orchestration issues (meta — for the agent-workflow angle)

### E1. Stage A triage is blind to a silently-stalled EL
- **Issue:** a node whose CL checkpoint-syncs and whose Engine API authenticates **passes install triage** even if the EL has 0 peers and never backfills state — the CL just follows the live head optimistically forever. nethermind (D3) passed Stage A and still hadn't synced 13h into Stage B.
- **Takeaway:** "installs + authenticates + CL reaches tip" ≠ "the EL is actually syncing." A real sync gate must verify the EL is downloading/executing historical state (peers + head progress), not just that the live head is followed.
- **Mitigation (implemented, #31 / PR #190):** an opt-in stall-watchdog in `run_candidate.sh` — set `ETH2QS_BAKEOFF_STALL_RESTART=yes` and if the unit under test makes no forward progress (EL block number / CL `head_slot` flat) for `ETH2QS_BAKEOFF_STALL_SAMPLES` polls (default 10), it does up to `ETH2QS_BAKEOFF_STALL_MAX_RESTARTS` bounded restarts (default 3) of *only that unit*, then writes `.stalled` + `stall_failed=yes` and fails the row instead of spinning to the 72h cap. Detection-only by default (opt-in), and it never touches any unit other than the one under test.

### E2. Footprint over-count — MAX sample vs LAST sample
- **Issue:** we initially reported reth's partial footprint as the **max** across all samples (1.06 TiB) — but that caught a transient DB-compaction peak. The settled near-cap value was **~0.97 TiB**.
- **Takeaway:** on-disk size oscillates during compaction. Report the **last/near-terminal sample**, not the max. (And reconcile any headline number against the raw series before publishing.)

### E3. Orchestrator context is the real scaling bottleneck, not node wall-clock
- **Issue:** the harness decoupled *node* wall-clock from any agent session (detached systemd + sampling → syncs run for days while the agent is parked). But the **orchestrating agent's context** still filled up, because every status check and diagnosis pulled raw telemetry (journalctl, du, RPC probes, sample parsing) into the context window. We compacted/cleared mid-campaign.
- **Fix (in progress):** (1) push verdict/health logic *down into the harness* so the agent reads a verdict (`SYNCING/STALLED_NO_PEERS/STALLED_NO_PROGRESS/SYNCED/CAPPED`), not logs; (2) a one-screen STATUS digest file the agent reads per check-in; (3) event-driven monitoring (wake only on terminal events) instead of polling; (4) delegate deep dives to subagents that return short conclusions.
- **Takeaway:** for long-running agent-driven campaigns, separate **durable state** (small, in files: results, governance, queue) from **transient investigation** (huge, ephemeral: logs, probes). Keep transient telemetry *off* the orchestrator's context path. Compute conclusions where the data lives; let the agent read conclusions. A self-handoff file in durable memory makes mid-campaign context clears a non-event.

### E4. Benign resource contention on a shared host looks alarming
- **Issue:** heavy-client startups (non-geth ELs, lodestar) briefly made Prysm's beacon REST unavailable (`restErr` in samples) for 1–3 min; co-resident agents drove load1 to 28–34 on 12 cores. Easy to misread as a node defect.
- **Takeaway:** on a shared/semi-prod host, expect startup contention and self-correcting load spikes. Cap clients with systemd `CPUQuota`/`MemoryMax`, and don't alarm on transient `restErr`/load unless a client actually crashes or stalls. Tune monitors to fire on real thresholds (mem<8G, load>50), not every spike.

---

_Last updated: 2026-07-29. Campaign complete — this log now spans Stage A triage, Stage B full
sync, the CL matrix (including the teku anchor-watchdog false positive and the lodestar gapped-run
incident from the 2026-07-26 nethermind-anchor sweep, §C8-C9), and the harness hangs (SIGTTIN, §C7)
surfaced by running detached for weeks. Companion to
[`CLIENT_BAKEOFF_RESULTS.md`](CLIENT_BAKEOFF_RESULTS.md) (the clean metrics) and
[`HOW_WE_TESTED_WITH_CLAUDE.md`](HOW_WE_TESTED_WITH_CLAUDE.md) (the orchestration story)._
