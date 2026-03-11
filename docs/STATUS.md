# Project Status

Last updated: 2026-03-11

## Current Capabilities

- Installation model: two-phase (`run_1.sh` -> reboot -> `run_2.sh`)
- Frontend/one-liner bootstrap: `install.sh` with explicit `--interactive` and `--non-interactive`
- One-liner default behavior: auto-fallback to non-interactive when stdin is piped
- Execution clients (7): geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex
- Consensus clients (6): prysm, lighthouse, teku, nimbus, lodestar, grandine
- MEV options: MEV-Boost, Commit-Boost, optional ETHGas (with Commit-Boost)
- Canonical service units:
  - `eth1.service`
  - `cl.service`
  - `validator.service`
  - `mev.service`
  - `commit-boost-pbs.service`
  - `commit-boost-signer.service`
  - `ethgas.service`

## Validation Coverage

- Shell/static/integration suite: `./test/run_tests.sh --full`
- Local pre-push checks: `./scripts/pre-commit.sh`
- Frontend checks:
  - `cd frontend && bun run lint`
  - `cd frontend && bun run test`
  - `cd frontend && bun run build`
- TUI pipe interaction test:
  - `./test/whiptail_pipe_test.sh`
  - enforced mode: `REQUIRE_WHIPTAIL_PIPE_TEST=1 ./test/whiptail_pipe_test.sh`
- CI includes dedicated `tui-whiptail-pipe` job to verify whiptail/Enter behavior with `expect`.
- CI includes `tui-whiptail-nonskip-guard` so required shell-test coverage fails instead of skipping.
- Installer smoke coverage:
  - `./test/install_sh_smoke.sh`
  - enforced in CI via `install-sh-smoke`
- Docs consistency checks:
  - `./test/ci_test_docs_consistency.sh`
  - enforced in CI via `docs-consistency` job

## Open Gaps / Incomplete Work

- Standardize config merge tooling across clients (some docs still describe simple concat/generation rather than schema-aware merge).
- Keep pruning active docs when one-off reports appear; move them to `docs/archive/reports/`.
- Optional: enable a stable Prysm checkpoint smoke path in CI without adding flake or excessive runtime.

## Canonical Docs

- Main docs index: `docs/README.md`
- Script reference: `docs/SCRIPTS.md`
- Frontend guide: `docs/FRONTEND.md`
- Closed PR follow-up tracker: `docs/PR_FOLLOWUPS.md`
- Session continuity: `docs/agent-handoff.md`
