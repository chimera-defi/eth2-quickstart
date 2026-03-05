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
  - Fixed installer UX for one-liner + TUI by adding explicit mode controls:
    - `--non-interactive` (alias `--vibe`)
    - `--interactive` (force whiptail, requires TTY)
    - `ETH2_NON_INTERACTIVE=1` env override
  - Added automatic non-interactive fallback when installer stdin is piped (common `curl | bash` case) to avoid blocked whiptail `OK` interactions.
  - Updated `install/utils/configure.sh` with TTY detection and automatic fallback to non-interactive mode when TUI is unavailable.
  - Updated README one-liner guidance with both explicit interactive and non-interactive usage.
  - Added CI regression checks in `test/ci_test_run_1.sh` to enforce installer mode flags and fallback behavior.
- Validation:
  - `bash -n install.sh install/utils/configure.sh test/ci_test_run_1.sh` passed.
  - `bash test/ci_test_run_1.sh` passed.
  - `./test/run_tests.sh --full` passed (`Total: 276, Passed: 276, Failed: 0`).
  - `bash test/ci_test_run_2.sh` passed as non-root user in `/tmp` repo copy.
- Follow-ups:
  - Consider adding an integration test that executes `install.sh` in a pseudo-TTY and piped-stdin harness to validate mode switching behavior end-to-end (not just static checks).
  - If additional installer flags are added, keep `install.sh` and `install/utils/configure.sh` mode semantics in sync.
