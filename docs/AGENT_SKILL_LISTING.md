# Agent Skill Listing

Use this copy for registry listings, launch posts, README snippets, or website blurbs.

## Positioning

`eth2-quickstart` now includes a repo-aware agent skill for Ethereum node operations.

It is not a generic blockchain prompt. It is a tested command map over the real repo workflows.

## Short Description

Install, operate, diagnose, update, and clean Ethereum node stacks through one canonical repo command surface.

## One-Liner Pitch

Give an agent a safe, repo-local interface to `eth2-quickstart` so it can bootstrap hosts, inspect node health, and propose cleanup without inventing commands or deleting secrets.

## Key Claims

- Repo-aware: built to run inside an `eth2-quickstart` checkout
- Canonical commands: routes through `./scripts/eth2qs.sh`
- Machine-readable health: uses `./scripts/eth2qs.sh doctor --json`
- Safe cleanup: prefers `clean-data --dry-run` and preserves secrets by design
- CI-backed: skill structure, command mapping, safety, and distribution path are tested

## Use It Like This

1. Clone `eth2-quickstart`
2. Install or copy the skill into that repo workspace
3. Run from inside the repo so the skill can resolve the repo root
4. Use the wrapper commands for real operations

## Demo Flow

```bash
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh logs --run2 -n 200
./scripts/eth2qs.sh clean-data --dry-run
```

## Do Not Claim

- Do not claim it is a global standalone agent package
- Do not claim it manages validator secrets
- Do not claim it replaces human confirmation for root, reboot, or destructive actions
