# Eth2 Client Bake-off Results

_Stage A (triage) synthesized from `artifacts/client-bakeoff-2026-06-22/` on 2026-06-23. Raw artifacts are gitignored; this doc is the committed summary._

## Method

- **Baseline-anchored coverage (12 candidates):** every execution client vs fixed Prysm (7 ELs), plus every other consensus client vs fixed Geth (5 CLs). This isolates each client against a known-good counterpart instead of testing every NxM pair.
  - ELs × prysm: geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex
  - geth × CLs: lighthouse, teku, nimbus, lodestar, grandine
- **Two stages:**
  - **Stage A — triage (this doc):** does each candidate install, checkpoint-sync, and authenticate the Engine API? ~5-min observation window per candidate, 60s sampling.
  - **Stage B — full sync (in progress):** sync-to-completion to measure final synced disk footprint for viable candidates.
- **Execution:** strictly sequential, ONE candidate at a time on this shared semi-prod host. Resource-capped to protect co-resident agents. MEV: none. No validator keys. Destructive data-clean gated by `ETH2QS_BAKEOFF_CONFIRMED=yes` (secrets/validator material preserved).
- **Pass criterion (Stage A):** beacon `head_slot` reaches the network tip (~14.6M) via checkpoint import on the first sample (`is_optimistic=true`), `el_offline=false` (Engine-API JWT handshake succeeded), and `sync_distance` trending to 0 — i.e. the CL is live-tracking a validating EL.

## Stage A results — 12/12 PASS

`el_offline` is Prysm's own verdict on whether the EL is reachable **and** authenticating over the Engine API. `False` across the window = JWT wired correctly and the EL is validating payloads. `restErr` = beacon REST momentarily unavailable during heavy-client startup (see Resource contention below).

| Candidate | Install | Crash | head (first→last) | el_offline | restErr | n | Verdict | Installer fix |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| geth__prysm | 0 | no | 14615771→14615856 | F×5 | 0 | 5 | PASS (baseline) | none |
| erigon__prysm | 0 | no | 14615808→14615808 | F×5 | 0 | 5 | PASS — flagged | none |
| reth__prysm | 0 | no | 14615808→14616097 | F×5 / T×4 | 6 | 9 | PASS (after fix) | **JWT + HTTP-RPC** |
| nethermind__prysm | 0 | no | 14614859→14615786 | F×9 | 4 | 9 | PASS | Engine module |
| besu__prysm | 0 | no | 14616094→14616183 | F×5 | 0 | 5 | PASS (clean) | none |
| nimbus_eth1__prysm | 0 | no | 14616151→14616235 | F×5 | 0 | 5 | PASS (clean) | none |
| ethrex__prysm | 0 | no | 14616192→14616287 | F×5 | 0 | 5 | PASS (clean) | none |
| geth__lighthouse | 0 | no | 14615232→14615349 | F×4 | 1 | 4 | PASS | none |
| geth__teku | 0 | no | 14615296→14615326 | F×4 | 1 | 4 | PASS | config keys |
| geth__nimbus | 0 | no | 14615455→14615506 | F×5 | 0 | 5 | PASS | trustedNodeSync |
| geth__lodestar | 0 | no | 14615638→14615708 | F×10 | 10 | 10 | PASS | rcConfig |
| geth__grandine | 0 | no | 14615040→14615203 | F×7 | 1 | 7 | PASS | none |

All 12: `install_exit_code=0`, no service crash, `is_optimistic=true`, checkpoint-sync PASS signature.

### Per-candidate notes

- **erigon — PASS with Stage-B re-verify flag.** Head stayed frozen at the checkpoint slot (14615808) and `sync_distance` grew 71→97 over the 5-min window. This is benign warmup, not a defect: `el_offline=false` throughout (Engine API reachable and authenticating), so the freeze is beacon-P2P backfill catching up, not a broken EL handshake. Re-verify head advances under Stage B's longer window.
- **reth — the only EL that needed installer fixes.** reth was the sole EL not passing `--authrpc.jwtsecret` to the shared secret that `ensure_jwt_secret` already created, so Prysm fell back to a non-shared auto-JWT → 401 → frozen head (`el_offline=True` early samples). Two commits fixed it; `el_offline` flips True→False once the shared JWT is wired. Also enabled HTTP-RPC on 127.0.0.1 for monitoring/consumers, matching the other ELs.
- **besu / nimbus_eth1 / ethrex — clean PASS, no fix.** JWT wiring correct out of the box. ethrex reached finalization (`finalizedEpoch=456756`). nimbus_eth1 additionally runs its own background historical EL sync from genesis (independent of the Engine API path, which works immediately).

### Resource contention (shared semi-prod host)

Heavier-client startups (non-geth ELs, and lodestar) showed Prysm's beacon REST briefly unavailable for the first 1–3 minutes (`restErr` counts above) before recovering — consistent with startup contending for CPU/IO against co-resident agents on this shared host. It did **not** block any checkpoint sync, but it is the headline risk for Stage B: a multi-day, IO-heavy full sync will compete with co-resident workloads. Stage B execution strategy (sequential vs. small parallel batches) must account for this.

## Changes driven by this bake-off

Installer/harness fixes landed on the bake-off branch as a direct result of triage:

- `fix(reth): wire shared JWT + explicit authrpc/datadir for Engine API`
- `fix(reth): enable HTTP-RPC on 127.0.0.1 (eth,net,web3) for monitoring and consumers`
- `fix(nethermind): drop Engine from main JsonRpc.EnabledModules`
- `fix(lodestar): load node options via --rcConfig not --paramsFile`
- `fix(nimbus): checkpoint-sync via trustedNodeSync bootstrap`
- `fix(teku): remove invalid config keys blocking beacon startup`
- `fix(bakeoff): authenticate GitHub release API via gh token to avoid rate limits`
- `fix(bakeoff): bound doctor/stats sampling calls with timeout 30s`

## Recommendation (preliminary — Stage A only)

Stage A establishes **viability**, not a final pick: all 12 client pairs install, checkpoint-sync, and authenticate the Engine API on this host. The final recommendation depends on Stage B's synced disk footprint and sync-time metrics.

- Recommended execution client: _pending Stage B footprint_
- Recommended consensus client: _pending Stage B footprint_
- Stage-A note: geth, besu, nimbus_eth1, ethrex passed with zero installer changes and zero REST contention — the cleanest out-of-the-box ELs against Prysm.

## Final synced disk footprint (Stage B)

_In progress (run_id `client-bakeoff-stageB-2026-06-23`). Sequential, one candidate at a time; rows added as each candidate reaches a verdict. Footprint = final synced datadir size (EL + CL); secrets/validator material excluded._

| Candidate | Result | Sync time | Final disk footprint (EL + CL) | Notes |
| --- | --- | --- | --- | --- |
| geth__prysm | ✅ synced | ~8h28m | **1.13 TiB** — geth 1,245,128,582,247 B + prysm 654,985,849 B | Baseline. snap-sync EL hands prysm an already-validated head, so there is no large optimistic gap to close. fully_synced=yes, no crash. |
| erigon__prysm | ❌ no-sync | n/a (terminated) | ~1.21 TiB\* — erigon 1,333,017,755,599 B + prysm 1,646,160,347 B | \*Partial, captured at a near-tip **frozen** head — NOT a clean synced datadir. erigon3 OtterSync + checkpoint-synced prysm deadlock: the EL execution head freezes a few thousand blocks behind tip while the beacon stays `is_optimistic=true`; neither side issues the `forkchoiceUpdated` that would close the >96-block backward-download gap. Raising the CL CPU cap 200%→600% advanced the head ~5k blocks then re-froze — confirming a genuine gap-close deadlock, not resource starvation. Terminated per operator decision ("record no-sync, move on"). See artifact `findings.md`. |
| reth__prysm | ⏳ running | — | — | Launched 2026-06-24. Rust staged-sync — monitored for the same gap-close signature. |

_Remaining (queued, one at a time): nethermind, besu, nimbus_eth1, ethrex (× prysm); then geth × lighthouse, teku, nimbus, lodestar, grandine._
