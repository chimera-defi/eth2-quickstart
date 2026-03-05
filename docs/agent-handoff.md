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
  - Added unified wrapper `scripts/eth2qs.sh` as a stable command entrypoint for humans and AI agents.
  - Added machine-readable health output in `install/utils/doctor.sh --json`.
  - Kept human-readable doctor output as default; `--json` returns summary + check list.
  - Aligned doctor MEV service status check to `mev` service name.
  - Updated `README.md` and `docs/SCRIPTS.md` with wrapper usage.
  - Added CI regression checks in `test/ci_test_run_1.sh` for wrapper presence and valid `doctor --json` output.
- Validation:
  - `bash -n scripts/eth2qs.sh install/utils/doctor.sh test/ci_test_run_1.sh README.md docs/SCRIPTS.md` passed.
  - `bash test/ci_test_run_1.sh` passed.
  - `./test/run_tests.sh --full` passed (`Total: 279, Passed: 279, Failed: 0`).
  - `bash test/ci_test_run_2.sh` passed as non-root user in `/tmp` repo copy.
- Follow-ups:
  - Consider exposing `scripts/eth2qs.sh` as `eth2qs` in release artifacts for global PATH usage.
  - If more scripts gain machine interfaces, keep JSON output contracts backward-compatible.
