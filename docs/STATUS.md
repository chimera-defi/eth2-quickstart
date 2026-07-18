# Project Status

Last updated: 2026-07-18

## Current Capabilities

- Installation model: two-phase (`run_1.sh` -> reboot -> `run_2.sh`)
- Frontend/one-liner bootstrap: `install.sh` with explicit `--interactive` and `--non-interactive`
- One-liner default behavior: auto-fallback to non-interactive when stdin is piped
- Execution clients (7): geth, erigon, reth, nethermind, besu, nimbus_eth1, ethrex
- Consensus clients (6): prysm, lighthouse, teku, nimbus, lodestar, grandine
- MEV options: MEV-Boost, Commit-Boost, optional ETHGas (with Commit-Boost)
- Validator lifecycle helpers (`scripts/eth2qs.sh`): `validators` inventory, `validator-exit`, `validator-create-0x01`/`validator-create-0x02`, `validator-deploy`, `validator-manage`, and `validator-withdrawal-changes` (BLS-to-execution, with a `--dry-run` rehearsal path) — see [VALIDATOR_MANAGEMENT.md](VALIDATOR_MANAGEMENT.md)
- Diagnostics & operations (`scripts/eth2qs.sh`): `doctor` health checks, `monitor`/`stats` (JSON-capable), `repair`, `update-check`, `clean-data`, `cleanup-host`, `update-all`
- Agent integration: MCP server (`mcp_server/`) exposing `phase1`/`phase2`/`client-options`/monitoring/repair as first-class tools
- Experimental: Monad devnet install path (`monad-install`)
- Client bake-off complete: all 7 execution clients plus 5 non-Prysm consensus clients benchmarked for synced disk footprint and sync time (Stage A triage + Stage B full sync + CL matrix; Prysm was the fixed execution-sweep anchor) — see [CLIENT_BAKEOFF_RESULTS.md](CLIENT_BAKEOFF_RESULTS.md)
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
- Validator management: `docs/VALIDATOR_MANAGEMENT.md`
- Client bake-off (results + methodology): `docs/CLIENT_BAKEOFF_BLOG.md`, `docs/CLIENT_BAKEOFF_RESULTS.md`
