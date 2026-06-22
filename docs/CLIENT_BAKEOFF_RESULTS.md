# Eth2 Client Bake-off Results

_Synthesized from `artifacts/client-bakeoff-2026-06-22/` on 2026-06-22T12:46:02Z. Raw artifacts are gitignored._

## Method

- Baseline-anchored coverage: every execution client vs fixed Prysm; every consensus client vs fixed Geth.
- Two stages: triage (~90m, checkpoint sync) then full sync-to-completion for viable candidates.
- Strictly sequential, resource-capped (eth1 600%/24G, cl 200%/12G) to protect co-resident agents.
- MEV: none. No validator keys.

## Results

| Pair | Install | Crash | Samples | Last doctor | Last disk (bytes) | Residual after cleanup |
| --- | --- | --- | --- | --- | --- | --- |
| geth__prysm | 0 | no | 1 | ok | 0 | 0 |

## Recommendation

<!-- Reviewer: fill the recommended stack and rationale from the table + per-candidate findings.md -->
- Recommended execution client:
- Recommended consensus client:
- Rationale:

## Final synced disk footprint (Stage B)

<!-- Reviewer: record per-client final synced disk size once Stage B completes -->

## Changes driven by this bake-off

<!-- Reviewer: list repo fixes (install scripts, config tuning) landed as a result. 'None' if clean. -->
