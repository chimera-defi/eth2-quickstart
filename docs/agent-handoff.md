# Agent Handoff

Use this file to preserve context across sessions.

## Active Defaults
- Start new work from latest `origin/master`.
- Preserve valuable uncommitted work before syncing (stash or branch).
- Use a fresh branch + fresh PR for each new task.

## Latest Update
- Date: 2026-03-04
- Author: codex
- Summary:
  - Updated `install/utils/purge_ethereum_data.sh` to purge only default node data/state directories.
  - Preserved keys/secrets by default and removed the `--include-secrets` destructive path.
  - Added default coverage for Ethrex (`~/ethrex/data`), Commit-Boost (`~/commit-boost`), and ETHGas (`~/ethgas`).
  - Added preservation rules for validator/keystore/secrets paths in consensus client data trees.
  - Updated `docs/SCRIPTS.md` to match new purge behavior and directory coverage.
- Validation:
  - `bash -n install/utils/purge_ethereum_data.sh` passed.
- Follow-ups:
  - If new clients are added, extend `DATA_DIRS` and preservation paths in purge script.
  - Consider adding unit tests for safe path preservation logic.
