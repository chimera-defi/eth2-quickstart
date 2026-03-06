# Agent Handoff

Use this file to preserve context across sessions.

## Active Defaults
- Start new work from latest `origin/master`.
- Preserve valuable uncommitted work before syncing (stash or branch).
- Use a fresh branch + fresh PR for each new task.

## Latest Update
- Date: 2026-03-05
- Author: codex
- Summary:
  - Added a canonical systemd service registry and service lifecycle helpers in `lib/common_functions.sh`.
  - Restored missing utility behavior by implementing `start_all_services`, `restart_all_services`, and `show_service_status`.
  - Fixed service-name consistency: standardized runtime checks on `mev` unit name (not `mev-boost`).
  - Improved `install/utils/doctor.sh` to report both MEV-Boost (`mev`) and Commit-Boost services.
  - Added unified wrapper `scripts/eth2qs.sh` as a stable command entrypoint for humans and AI agents.
  - Added machine-readable health output in `install/utils/doctor.sh --json` while keeping human-readable output as default.
  - Fixed CI regression in matrix job `besu+lighthouse+commit-boost` by removing deprecated Besu key `fast-sync-min-peers`.
  - Reworked `install/utils/update.sh` path handling and version reporting to use correct repo/home paths.
  - Expanded purge service coverage by using canonical service list in `install/utils/purge_ethereum_data.sh`.
  - Updated docs (`README.md`, `docs/SCRIPTS.md`, `install/utils/README_UPDATE_SCRIPTS.md`) with canonical service references and helper usage.
  - Added regression tests for service consistency:
    - `install/test/test_common_functions.sh` now validates service registry contents, helper existence, MEV stack precedence, and doctor unit-name checks.
    - `test/ci_test_run_2.sh` now verifies newly added service helpers and MEV service naming consistency.
- Validation:
  - `bash -n` passed for all touched utility/core scripts.
  - `install/utils/start.sh` runs successfully.
  - `install/utils/refresh.sh` runs successfully.
  - `install/utils/stats.sh` runs successfully.
  - `./test/run_tests.sh --full` passed (276/276).
  - `USE_MOCKS=true bash install/test/test_common_functions.sh` passed.
  - `bash test/ci_test_run_1.sh` passed.
  - `./scripts/eth2qs.sh doctor --json | python3 -m json.tool >/dev/null` passed.
  - `bash test/ci_test_run_2.sh` passed as non-root user in a writable copy under `/tmp`.
- Validation:
  - `SKIP_BUILD=true E2E_EXECUTION=besu E2E_CONSENSUS=lighthouse E2E_MEV=commit-boost ./test/run_e2e.sh --phase=2` passed (`26 passed, 0 failed`).
  - `./test/run_tests.sh --full` passed (`Total: 279, Passed: 279, Failed: 0`).
- Follow-ups:
  - Consider exposing `scripts/eth2qs.sh` as `eth2qs` in release artifacts for global PATH usage.
  - Add a dedicated helper script to run `ci_test_run_2.sh` non-root in environments where repo is under `/root` (permission boundary).
  - Optionally add a machine-readable service manifest for CI drift checks between code and docs.
  - Track Besu release note changes for config schema removals/additions and update `configs/besu/besu_base.toml` proactively.
  - Consider adding per-client config smoke tests (invoke client binary with config-only parse) in CI to catch deprecated keys earlier.

## Update: 2026-03-05 (PR130 Cleanup Iteration)
- Author: codex
- Summary:
  - Reviewed PR #130 for dead code and TUI fallback complexity.
  - Removed unused `show_msg` alias from `install/utils/configure.sh`.
  - Simplified `install.sh` interactive path by removing `script -q -c` PTY wrapper logic and keeping direct `/dev/tty` stdin redirect.
  - Added regression guard in `test/ci_test_run_1.sh` to prevent reintroducing `script(1)` wrapper dependency.
  - Preserved non-interactive auto-fallback behavior and explicit `--interactive`/`--non-interactive` controls.
- Validation:
  - `bash -n install.sh install/utils/configure.sh test/ci_test_run_1.sh scripts/eth2qs.sh install/utils/doctor.sh` passed.
  - `bash test/ci_test_run_1.sh` passed.
  - `bash test/ci_test_run_2.sh` passed as non-root user in `/tmp` repo copy.
  - `./test/run_tests.sh --full` passed (`Total: 279, Passed: 279, Failed: 0`).
- Follow-ups:
  - If we later retire interactive TUI entirely, replace whiptail flow with a first-class pure-CLI flag-driven configurator.

## Update: 2026-03-05 (CI RCA + Flake Hardening)
- Author: codex
- Summary:
  - Investigated reported CI failures after PR130 updates.
  - Confirmed `run-2-structure` is green in CI and passes locally as non-root.
  - RCA: observed flaky CI behavior in Docker/E2E path (transient GHCR pull timeout and matrix cancellations obscuring root cause).
  - Hardened `.github/actions/docker-prep/action.yml` with pull retry/backoff (3 attempts) before failing.
  - Hardened `.github/workflows/ci.yml` matrix behavior:
    - switched `e2e-client-matrix.strategy.fail-fast` to `false` so one flake does not cancel sibling client combinations.
    - added one retry with backoff around matrix E2E command execution.
- Validation:
  - YAML parsing passed for `.github/workflows/ci.yml` and `.github/actions/docker-prep/action.yml`.
  - `bash test/ci_test_run_2.sh` passed as non-root user in `/tmp` repo copy.
- Follow-ups:
  - If matrix failures persist after hardening, add per-client targeted readiness diagnostics in `test/ci_test_e2e.sh` (service status + recent journal excerpts before fail).

## Update: 2026-03-05 (Stale Docs Closure + TUI E2E Enforcement)
- Author: codex
- Summary:
  - Performed a focused stale-doc review and closed out old planning/review artifacts that were still active on `master`.
  - Moved historical frontend planning/prompt/review docs to `docs/archive/frontend/`.
  - Moved one-off RCA/review/progress/task docs to `docs/archive/reports/`.
  - Added `docs/FRONTEND.md` as the single active frontend documentation entrypoint.
  - Updated active indexes/references in:
    - `docs/README.md`
    - `README.md`
    - `.cursorrules`
    - `docs/archive/README.md`
  - Fixed moved-archive link path in `docs/archive/reports/LOCAL_VERIFICATION_CHECKLIST.md`.
  - Hardened TUI verification:
    - `test/whiptail_pipe_test.sh` now supports `REQUIRE_WHIPTAIL_PIPE_TEST=1` to fail instead of skip when dependencies are missing.
    - Added CI job `tui-whiptail-pipe` in `.github/workflows/ci.yml` that installs `expect` + `whiptail` and runs the enforced test.
  - Fixed local validation ergonomics:
    - `scripts/pre-commit.sh` now ignores `frontend/node_modules/` and `frontend/.next/` in shebang/dependency scans to avoid false failures from third-party files.
- Validation:
  - `sudo apt-get install -y expect whiptail` completed.
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 ./test/whiptail_pipe_test.sh` passed.
  - `./scripts/pre-commit.sh` passed.
  - `./test/run_tests.sh --full` passed (`Total: 279, Passed: 279, Failed: 0`).
  - Active-doc link integrity sweep passed (`TOTAL_BROKEN=0` for `README.md` and `docs/**/*.md`).
- Follow-ups:
  - If desired, add one more explicit CI assertion that fails when `whiptail_pipe_test.sh` records `SKIP` in any shell-test context outside the dedicated TUI job.

## Update: 2026-03-05 (Final Pass: Status Snapshot + Docs Consistency)
- Author: codex
- Summary:
  - Cherry-picked two pending cleanup branches onto latest `origin/master` and rebased cleanly:
    - docs/frontend alignment + stale-doc archiving
    - strict TUI pipe verification in CI
  - Added `docs/STATUS.md` as a concise current-state snapshot (capabilities, validation coverage, optional follow-ups, canonical doc pointers).
  - Linked `docs/STATUS.md` from:
    - `README.md` (Additional Documentation)
    - `docs/README.md` (Core Documentation)
  - Opened PR #135 for this final-pass consolidation.
- Validation:
  - `./test/run_tests.sh --full` passed (`279 passed, 0 failed`).
  - `./scripts/pre-commit.sh` passed.
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 ./test/whiptail_pipe_test.sh` passed.
  - `cd frontend && bun run lint` passed.
  - `cd frontend && bun run test` passed (`30 passed, 0 failed`).
  - `cd frontend && bun run build` passed.
- Follow-ups:
  - Optional: add installer end-to-end smoke execution in CI (beyond current structure and interaction checks).

## Update: 2026-03-05 (Recreated PR: Installer/CI Hardening)
- Author: codex
- Why:
  - Recreated previously stale PR #131 as a clean branch on latest `origin/master` after superseded PR cleanup.
  - Preserved only the unique hardening changes that were not yet merged.
- Changes:
  - `install.sh`: fail fast with explicit error if neither `curl` nor `wget` is installed.
  - `.github/actions/docker-prep/action.yml`: if GHCR pull retries all fail, fallback to local build from `test/Dockerfile`.
  - `.github/workflows/ci.yml`: normalized top-level comments for consistency/readability.
  - `scripts/eth2qs.sh`: clearer error when command target is missing or not executable.
  - `test/ci_test_run_1.sh`: regression guard for explicit missing `curl/wget` check in installer.
- Validation:
  - `./test/run_tests.sh --full` passed (`279 passed, 0 failed`).
  - `./scripts/pre-commit.sh` passed.
- Follow-ups:
  - Monitor CI runtime impact from docker-prep local-build fallback on GHCR outage scenarios.

## Update: 2026-03-06 (Prysm Checkpoint Live Smoke Test)
- Author: codex
- Summary:
  - Added `test/prysm_checkpoint_smoke.sh`, an opt-in live smoke test for Prysm checkpoint-sync behavior that:
    - verifies `checkpoint-sync-url` and `genesis-beacon-api-url` are configured,
    - restarts `cl.service` and inspects journal logs for checkpoint bootstrap indicators,
    - verifies fallback behavior via: `Origin checkpoint found in the database, ignoring checkpoint sync flags`.
  - Integrated the smoke into phase-2 E2E as an explicit opt-in path for Prysm:
    - `test/ci_test_e2e.sh` now runs the smoke when `E2E_CONS=prysm` and `E2E_PRYSM_CHECKPOINT_SMOKE=true`.
    - default E2E wiring sets `PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG=false` for resilience in short CI log windows.
  - Integrated the smoke into local full test runner as optional:
    - `test/run_tests.sh` reports PASS/SKIP/FAIL for `prysm_checkpoint_smoke.sh` based on env and prerequisites.
  - Updated testing docs in `test/README.md` with usage and env flags for the new smoke test.
- Validation:
  - `bash -n test/prysm_checkpoint_smoke.sh test/ci_test_e2e.sh test/run_tests.sh` passed.
  - `ENABLE_PRYSM_CHECKPOINT_SMOKE=true bash test/prysm_checkpoint_smoke.sh` returned expected `SKIP` in this workspace (`cl.service` not installed).
  - `./test/run_tests.sh --full` passed (`Total: 280, Passed: 279, Failed: 0, Skipped: 1`).
  - `./scripts/pre-commit.sh` passed.
- Follow-ups:
  - Optional: enable `E2E_PRYSM_CHECKPOINT_SMOKE=true` in one CI matrix Prysm job once runtime stability is confirmed.
  - Optional: tighten to `PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG=true` in CI if log-window reliability is acceptable.

## Update: 2026-03-06 (Lean Recovery of #93/#141 Intent)
- Author: codex
- Summary:
  - Reopened closed PRs `#93` and `#141` so their branches remain active/reviewable while recovering intent in a cleaner implementation.
  - Implemented a leaner help-flow evolution directly in core scripts:
    - `run_1.sh`: added early `--help` path before privilege checks.
    - `run_2.sh`: moved arg/help parsing before log setup to avoid side effects on help calls.
    - `run_2.sh`: removed stale legacy bootstrap comments and centralized usage text in `print_usage`.
  - Added regression coverage:
    - `test/ci_test_run_1.sh` validates `run_1.sh --help` output.
    - `test/ci_test_run_2.sh` validates `run_2.sh --help` output and asserts no `run_2` log file is created by help.
  - Kept existing Prysm checkpoint smoke coverage and integrations unchanged.
- Validation:
  - `./test/ci_test_run_1.sh` passed.
  - `./test/run_tests.sh --full` passed (`Total: 280, Passed: 279, Failed: 0, Skipped: 1`).
  - `./scripts/pre-commit.sh` passed.
- Follow-ups:
  - After merging this lean replacement, close `#93`/`#141` again with a superseded-by comment pointing to the replacement PR.
## Update: 2026-03-06 (Local Prysm Checkpoint Smoke Validation + Fixes)
- Author: codex
- Summary:
  - Performed live local validation of Prysm checkpoint smoke behavior inside systemd Docker E2E containers using current workspace bind mounts.
  - Found and fixed smoke execution privilege issue in `test/ci_test_e2e.sh`:
    - smoke hook now runs via `sudo` and preserves caller `HOME` to avoid looking under `/root` for Prysm config.
  - Found and fixed wrapper env propagation gap in `test/run_e2e.sh`:
    - now forwards `E2E_PRYSM_CHECKPOINT_SMOKE`,
    - `PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG`,
    - `PRYSM_CHECKPOINT_REQUIRE_FALLBACK_LOG`.
  - Improved `test/prysm_checkpoint_smoke.sh` behavior for fresh-node timing:
    - added `PRYSM_CHECKPOINT_REQUIRE_FALLBACK_LOG` (default `false`),
    - allows pass when checkpoint bootstrap evidence exists even if fallback log has not appeared yet.
  - Executed explicit cleanup after runs:
    - removed temporary E2E containers,
    - pruned dangling Docker build layers (~2.56GB reclaimed),
    - removed generated temporary `run_2` logs from validation loops.
- Validation:
  - Focused live run succeeded with patched flow:
    - `/workspace/run_2.sh --execution=geth --consensus=prysm --mev=mev-boost --skip-deps`
    - `sudo HOME="$HOME" ENABLE_PRYSM_CHECKPOINT_SMOKE=true PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG=false /workspace/test/prysm_checkpoint_smoke.sh`
    - output included: `Prysm checkpoint-sync smoke passed`.
  - `bash -n test/ci_test_e2e.sh test/prysm_checkpoint_smoke.sh test/run_e2e.sh` passed.
- Follow-ups:
  - Optional: add a lightweight CI path that mounts workspace into the E2E container for faster script-iteration validation without full image rebuild.

## Update: 2026-03-05 (Lean Pass: Archive Bloat Prune)
- Author: codex
- Why:
  - User requested a new audit pass to reduce repository code/docs/artifacts without changing functionality.
  - Archived frontend prompt/task/review artifacts and stale report files were dominating context with low current value.
- Changes:
  - Pruned stale archive artifacts:
    - removed large historical files under `docs/archive/frontend/` (prompt packs, task trackers, review/progress/marketing/spec docs).
    - removed stale one-off reports under `docs/archive/reports/` (`CI_RCA_BEACON_CONNECTION.md`, `CI_TROUBLESHOOTING.md`, `MULTI_PASS_REVIEW.md`, `PR_86_DESCRIPTION.md`, `progress_2026-02-16.md`, `task.md`).
  - Added concise replacement index: `docs/archive/frontend/README.md`.
  - Updated `docs/archive/README.md` wording to reflect pruned archive structure.
  - Reduced CI workflow comment noise in `.github/workflows/ci.yml` without changing behavior.
- Size impact:
  - Net reduction: `-5520` lines (`4` added, `5524` deleted).
- Validation:
  - `./test/run_tests.sh --full` passed (`279 passed, 0 failed`).
  - `./scripts/pre-commit.sh` passed.
  - `cd frontend && bun run lint` passed.
  - `cd frontend && bun run test` passed (`30 passed`).
  - `cd frontend && bun run build` passed.
- Follow-ups:
  - Optional: prune additional archive files with the same rule (keep active docs + concise archive indexes, rely on git history for deep historical artifacts).

## Update: 2026-03-06 (Multipass Consolidated Reduction)
- Author: codex
- Why:
  - User requested additional multi-pass reduction and an explicit merge/close recommendation.
  - `master` had not yet merged PRs #137/#138, and archive context bloat remained high.
- Passes applied:
  - Pass 1: consolidated already-validated reductions from #137/#138 (archive/frontend and reports pruning + dead script/template removals).
  - Pass 2: pruned remaining unreferenced root archive artifacts and retained compact indexes only.
  - Pass 3: re-ran dead-code scan for shell surfaces and validated behavior remains unchanged.
- Changes:
  - Added compact archive indexes:
    - `docs/archive/README.md` (rewritten as minimal index)
    - `docs/archive/reports/README.md` (new)
  - Removed stale root archive artifacts:
    - `docs/archive/AGENT_CONTEXT.md`
    - `docs/archive/AGENT_HANDOFF.md`
    - `docs/archive/DOCUMENTATION_CONSOLIDATION_SUMMARY.md`
    - `docs/archive/INSTALL_SCRIPTS_REVIEW.md`
    - `docs/archive/PRYSM_FLAGS_ANALYSIS.md`
    - `docs/archive/REFACTORING_AUDIT_REPORT.md`
    - `docs/archive/SHELL_SCRIPT_TEST_RESULTS.md`
    - `docs/archive/progress.md`
    - `docs/archive/reports/LOCAL_VERIFICATION_CHECKLIST.md`
- Validation:
  - `./test/run_tests.sh --full` passed (`272 passed, 0 failed`).
  - `./scripts/pre-commit.sh` passed.
- Follow-ups:
  - `install/examples/run_prysm_checkpt_sync.sh` appears unreferenced by repo call-sites but was retained as a user-facing example script.

## Update: 2026-03-06 (Prysm Checkpoint Sync Audit + Legacy Cleanup)
- Author: codex
- Summary:
  - Audited current Prysm checkpoint-sync behavior against upstream source and confirmed checkpoint sync is URL-flag driven (`--checkpoint-sync-url`), not an always-on mode.
  - Confirmed expected startup behavior in Prysm code paths:
    - checkpoint initializer runs when checkpoint URL is configured,
    - on subsequent runs with origin already present, Prysm ignores checkpoint bootstrap flags and continues normal sync flow.
  - Removed obsolete legacy helper script:
    - deleted `install/examples/run_prysm_checkpt_sync.sh` (old checkpoint SSZ flow).
  - Cleaned stale docs and script references to match current repo behavior:
    - refreshed Prysm checkpoint wording and script paths in `README.md`.
    - updated old utility/web/ssl script paths and checkpoint wording in `docs/WORKFLOW.md`.
    - removed stale `checkpoint_ssz` and obsolete Prysm sync config references in `docs/CONFIGURATION_GUIDE.md`.
    - updated SSL script references in `docs/SCRIPTS.md`.
  - Fixed broken internal script calls in:
    - `install/ssl/install_acme_ssl.sh`
    - `install/ssl/install_ssl_certbot.sh`
    so they call canonical `install/web/*` scripts.
  - Removed stale historical comment block from `run_2.sh` (old manual checkpoint SSZ usage notes).
  - Added regression tests in `test/ci_test_run_2.sh`:
    - verify Prysm uses `checkpoint-sync-url` + `genesis-beacon-api-url` from `PRYSM_CPURL`.
    - verify no legacy `checkpoint-block` reference remains.
    - verify SSL scripts reference canonical `install/web/*` paths.
- Validation:
  - `./test/run_tests.sh --full` passed (`Total tests run: 276, Passed: 276, Failed: 0`).
  - `./scripts/pre-commit.sh` passed.
  - Active-repo stale reference sweep passed (legacy mentions only remain under `docs/archive/`).
- Follow-ups:
  - Optional: add an explicit CI assertion that no active docs outside `docs/archive/` reference removed legacy scripts/files.

## Update: 2026-03-06 (Consolidated PR for #136/#139/#140)
- Author: codex
- Why:
  - User requested merging the remaining open cleanup/refactor PRs into a single, up-to-date PR on latest `master`.
- Changes:
  - Created consolidation branch from latest `origin/master`:
    - `chore/consolidate-136-139-140-20260306`
  - Cherry-picked and conflict-resolved validated commits from:
    - PR `#136` (installer prereq/docker prep hardening)
    - PR `#139` (multi-pass archive/code reduction)
    - PR `#140` (Prysm checkpoint legacy cleanup and related docs/tests)
  - Opened consolidated PR:
    - `#143` `chore: consolidate #136, #139, #140 on latest master`
  - Closed superseded PRs:
    - `#136`, `#139`, `#140`
- Validation:
  - `./test/run_tests.sh --full` passed (`270 passed, 0 failed, 1 skipped`).
  - `./scripts/pre-commit.sh` passed (`257 passed, 0 failed` in its suite).
- Follow-ups:
  - Merge `#143` as the single replacement for the three superseded open PRs.

## Update: 2026-03-06 (PR #144 Post-#143 Merge Refresh)
- Author: codex
- Summary:
  - Updated `#144` branch by merging latest `origin/master` after `#143` merged, to avoid stale-base CI and integration/structure drift.
  - Resolved merge conflict in `docs/agent-handoff.md` while preserving both relevant update entries.
  - Verified `#144` scoped diff remains limited to:
    - `run_1.sh`, `run_2.sh`, `test/ci_test_run_1.sh`, `test/ci_test_run_2.sh`, `docs/agent-handoff.md`.
- Validation:
  - `./test/run_tests.sh --full` passed (`270 total, 269 passed, 0 failed, 1 skipped`).
  - `./scripts/pre-commit.sh` passed (includes run_1/run_2 structure gates).
- Follow-ups:
  - Monitor fresh CI run on `#144`; close superseded legacy PRs after `#144` merges.

## Update: 2026-03-06 (PR #144 CI Fix: run-2-structure)
- Author: codex
- Summary:
  - Investigated failing CI job `run-2-structure` on PR `#144`.
  - RCA: `test/ci_test_run_2.sh` used a double-quoted grep pattern intended to match the literal `$PRYSM_CPURL`, but CI env expansion turned it into a concrete URL pattern that cannot match the script source.
  - Fixed test assertion to use literal fixed-string matches:
    - `grep -Fq 'checkpoint-sync-url: $PRYSM_CPURL'`
    - `grep -Fq 'genesis-beacon-api-url: $PRYSM_CPURL'`
    - and retained legacy guard `! grep -Fq "checkpoint-block"`.
- Validation:
  - `./test/run_tests.sh --full` passed (`270 total, 269 passed, 0 failed, 1 skipped`).
  - `./scripts/pre-commit.sh` passed.
- Follow-ups:
  - Re-run PR `#144` CI and confirm `run-2-structure` now passes.

## Update: 2026-03-06 (PR #144 CI Fixes: run-2-structure + shellcheck-extended)
- Author: codex
- Summary:
  - Investigated failing PR `#144` jobs while monitoring CI.
  - Fixed `run-2-structure` failure root cause in `test/ci_test_run_2.sh`:
    - assertion now correctly matches literal Prysm config variable references in `install/consensus/prysm.sh`.
  - Fixed follow-up `shellcheck-extended` failure (`SC2016`) on the same assertions:
    - switched to double-quoted patterns with escaped `$` for literal matching that passes shellcheck.
- Validation:
  - `shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 test/ci_test_run_2.sh` passed.
  - `./scripts/pre-commit.sh` passed.
- Follow-ups:
  - Keep watching `#144` CI and patch quickly if any additional regressions surface.
