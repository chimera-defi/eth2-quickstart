# Operator Workflows

Use this reference when the agent's goal is to get a node running or keep one running, not just to answer repo questions.

## Primary Goals

- Bootstrap a new Ubuntu/Debian host for node use
- Resume an interrupted install after the reboot boundary
- Start, stop, restart, inspect, update, or safely clean an installed node
- Explain what is blocking readiness in machine-readable terms

## Choose The Workflow

### 1. Fresh Host Bootstrap

Use this for a blank host that has not run `run_1.sh` yet.

1. Confirm the host is intended for repo-managed node setup.
2. Confirm the human accepts root access, SSH hardening, and the reboot boundary.
3. Run `./scripts/eth2qs.sh bootstrap --non-interactive` for the one-line installer if the host is starting from scratch.
4. If working from an existing checkout, use:
   - `sudo ./scripts/eth2qs.sh phase1`
   - reboot
   - `./scripts/eth2qs.sh phase2 --execution=<client> --consensus=<client> --mev=<stack>`
5. After install, run `./scripts/eth2qs.sh doctor --json`.

### 2. Resume After Reboot

Use this when Phase 1 has already run and the host rebooted.

1. Confirm the agent is logged in as the non-root repo user.
2. Run `./scripts/eth2qs.sh phase2 ...` with explicit client flags when reproducibility matters.
3. Validate with `./scripts/eth2qs.sh doctor --json`.
4. If service status is unclear, run `./scripts/eth2qs.sh stats` and `./scripts/eth2qs.sh logs --run2 -n 200`.

### 3. Operate A Running Node

Use these commands for routine operations:

- Start services: `./scripts/eth2qs.sh start`
- Stop services: `./scripts/eth2qs.sh stop`
- Restart services: `./scripts/eth2qs.sh restart`
- Show current status: `./scripts/eth2qs.sh stats`
- Machine-readable health: `./scripts/eth2qs.sh doctor --json`
- Update software: `./scripts/eth2qs.sh update-all`

### 4. Recover Disk Space Safely

1. Inspect current health first: `./scripts/eth2qs.sh doctor --json`
2. Dry-run cleanup: `./scripts/eth2qs.sh clean-data --dry-run`
3. Require human confirmation before `--confirm`
4. Explain that default cleanup preserves secrets, validator keystores, wallets, and `~/secrets`

## Decision Guidance

- Prefer explicit `phase2` client flags when another agent or CI needs reproducibility.
- Prefer `doctor --json` before and after any install, update, or cleanup step.
- Prefer `stats` and `logs` when a human needs a readable RCA.
- If the requested action falls outside repo-supported workflows, say so instead of improvising.

## Not Covered

- Validator key generation
- Secret management outside the repo's existing flows
- Arbitrary non-repo node deployments
