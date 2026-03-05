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
  - Fixed CI regression in matrix job `besu+lighthouse+commit-boost` where Besu failed to start.
  - Root cause: deprecated Besu TOML key `fast-sync-min-peers` in `configs/besu/besu_base.toml`.
  - Removed the deprecated key from Besu base config.
  - Added regression guard in `test/ci_test_run_2.sh` to fail if `fast-sync-min-peers` reappears.
- Validation:
  - `bash test/ci_test_run_2.sh` passed as non-root user in `/tmp` repo copy.
  - `SKIP_BUILD=true E2E_EXECUTION=besu E2E_CONSENSUS=lighthouse E2E_MEV=commit-boost ./test/run_e2e.sh --phase=2` passed (`26 passed, 0 failed`).
  - `./test/run_tests.sh --full` passed (`Total: 279, Passed: 279, Failed: 0`).
- Follow-ups:
  - Track Besu release note changes for config schema removals/additions and update `configs/besu/besu_base.toml` proactively.
  - Consider adding per-client config smoke tests (invoke client binary with config-only parse) in CI to catch deprecated keys earlier.
