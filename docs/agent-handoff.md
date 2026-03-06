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
