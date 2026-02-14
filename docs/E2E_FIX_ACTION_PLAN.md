# E2E CI Regression Fix - Action Plan

## Problem
User reports: "I don't see the docker script and end-to-end test running in CI anymore"
"breaking the docker container into n test runs"

## Root Cause Analysis

### What I Changed (that broke it)
In the last commit I modified `.github/workflows/ci.yml`:
- Replaced single `run_2.sh - E2E` step with `run_2.sh - E2E (client matrix)` 
- Added `strategy:` and `matrix:` under the step

### The Bug
**In GitHub Actions, `strategy` and `matrix` are JOB-level keys, NOT step-level keys.**

Putting `strategy` under a step makes the workflow invalid. GitHub may:
- Fail to parse the workflow
- Ignore the step
- Or produce undefined behavior

Result: The E2E step likely never runs or the workflow fails.

## Fix Strategy

1. **REVERT** the CI workflow change: restore single `run_2.sh - E2E` step (no matrix)
2. **KEEP** the caddy/nginx E2E tests in ci_test_e2e.sh (they run in the single E2E)
3. **KEEP** the client env vars (E2E_EXECUTION etc) - they default to geth/prysm/mev-boost, so single run still works
4. **KEEP** the hardening path fixes (install_caddy.sh, install_nginx.sh) - those are correct
5. **DO NOT** add matrix back unless we create a proper separate job with job-level strategy

## What to Change

| File | Action |
|------|--------|
| .github/workflows/ci.yml | Revert to single E2E step, remove strategy/matrix from step |
| (no other files) | Leave ci_test_e2e.sh, run_e2e.sh, install/* as-is |

## Verification Before Push

1. Validate workflow YAML syntax
2. Run `./test/run_tests.sh --lint-only` 
3. If Docker available: `SKIP_BUILD=true ./test/run_e2e.sh --phase=2`
4. Inspect workflow structure - ensure run_1 E2E and run_2 E2E steps exist and run

## Attempt Log

| # | What | Result |
|---|------|--------|
| 1 | Identify root cause: strategy at step level is invalid | Documented |
| 2 | Revert CI workflow to single E2E step | Done |
| 3 | Validate workflow YAML (python yaml.safe_load) | Pass |
| 4 | Run lint-only tests | Pass (250 tests) |
| 5 | Docker build | N/A (Docker not in env) |

## Third Review Checklist

- [x] CI workflow has all 6 steps: Build, Lint, Unit, run_1 Structure, run_1 E2E, run_2 Structure, run_2 E2E
- [x] run_2.sh - E2E uses `SKIP_BUILD=true ./test/run_e2e.sh --phase=2` (single run, no matrix)
- [x] No strategy/matrix at step level (invalid in GHA)
- [x] ci_test_e2e.sh still has caddy+nginx install (unchanged)
- [x] Default E2E_EXEC/CONS/MEV in ci_test_e2e.sh = geth/prysm/mev-boost (single run works)
