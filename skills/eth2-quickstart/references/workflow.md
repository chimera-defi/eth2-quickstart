# Workflow

Use the wrapper first.

## Choose The Path

- Fresh bootstrap from a host shell: `./scripts/eth2qs.sh bootstrap --non-interactive`
- Configure generated scripts before execution: `./scripts/eth2qs.sh configure --interactive` or `--non-interactive`
- Phase 1 hardening as root: `sudo ./scripts/eth2qs.sh phase1`
- Reboot boundary: reboot after `run_1.sh`/Phase 1, then continue as `LOGIN_UNAME`
- Phase 2 client install as non-root: `./scripts/eth2qs.sh phase2`

## Underlying Commands

- `./scripts/eth2qs.sh bootstrap` routes to `install.sh`
- `./scripts/eth2qs.sh phase1` routes to `run_1.sh`
- `./scripts/eth2qs.sh phase2` routes to `run_2.sh`

## Agent Guidance

- Prefer non-interactive/bootstrap defaults unless a human asks for TUI interaction.
- Use explicit flags for `run_2.sh` client selection when reproducibility matters.
- After installs or updates, verify state with `./scripts/eth2qs.sh doctor --json`.
