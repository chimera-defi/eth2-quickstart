---
name: eth2-quickstart
description: Use this skill when working with this repo to bootstrap, operate, diagnose, update, or clean up Ethereum node stacks through the canonical repo commands with strict safety guardrails.
metadata:
  openclaw:
    skillKey: eth2-quickstart
---

# Eth2 Quickstart

Use this skill for Ethereum node workflows inside an `eth2-quickstart` checkout. Publish/install it through ClawHub or `npx clawhub`, then run it from the repo so it can use the canonical wrapper commands.

## Routing

- For end-to-end node operator goals, read [operator.md](references/operator.md).
- Install/bootstrap: use `./scripts/eth2qs.sh bootstrap ...`. Read [workflow.md](references/workflow.md).
- Configure or rerun phases: use `./scripts/eth2qs.sh configure`, `phase1`, or `phase2`. Read [workflow.md](references/workflow.md).
- Diagnose or inspect status: use `./scripts/eth2qs.sh doctor --json` for machine-readable output. Read [outputs.md](references/outputs.md).
- Operate services, logs, cleanup, or updates: use the mapped commands in [commands.md](references/commands.md).
- Before destructive or privilege-sensitive actions, load [safety.md](references/safety.md).
- For concrete user-task phrasing, read [examples.md](references/examples.md).

## Rules

- Do not invent new command entrypoints when an existing wrapper command fits.
- Prefer `./scripts/eth2qs.sh` over calling utility scripts directly.
- Do not generate validator keys.
- Do not remove secrets.
- Require human confirmation before destructive cleanup, host-wide changes, or steps that require reboot/root.
- Treat `doctor --json` as the canonical machine-readable status surface.

## References

- [workflow.md](references/workflow.md): choose bootstrap vs configure vs phase workflows
- [operator.md](references/operator.md): operator-focused install, resume, run, update, and cleanup flows
- [commands.md](references/commands.md): canonical command mapping
- [safety.md](references/safety.md): destructive boundaries and secrets policy
- [outputs.md](references/outputs.md): expected outputs and checks for agents
- [examples.md](references/examples.md): concrete prompt/task examples for common operator goals
