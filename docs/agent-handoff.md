# Agent Handoff

Use this file to preserve context across sessions.

## Active Defaults
- Start new work from latest `origin/master`.
- Preserve valuable uncommitted work before syncing (stash or branch).
- Use a fresh branch + fresh PR for each new task.

## Latest Update (PR #156 — Agent Skill Rollup, 2026-03-13 through 2026-03-20)

- Implemented repo-owned agent skill at `skills/eth2-quickstart/` with SKILL.md routing, reference docs, and resolver script
- Added `./scripts/eth2qs.sh` as canonical wrapper entrypoint for humans and agents
- Added planner-driven install routing: `plan --json`, `ensure` preview, `ensure --apply --confirm` execution
- Shared planning logic lives in `lib/install_planner.sh`; `plan.sh` and `ensure.sh` call `planner_prepare_context`
- Chain-aware routing distinguishes Ethereum vs Monad; partial installs fail safe into review
- `doctor --json` provides machine-readable health output including service-unit drift detection
- `clean-data --dry-run` preserves keys/secrets; `cleanup-host` covers root-managed datadirs
- `stats.sh` is read-only (no Prysm bootstrap downloads)
- Hardened `ensure --apply` to require `--confirm` for phase1/phase2/monad_install execution
- Added `llms.txt` and `llms-full.txt` as raw-ingest fallback for agents without ClawHub
- Added frontend `Agents.tsx` homepage section and `docs/AGENT_SKILL_LISTING.md` marketing copy
- Skill distribution CI enforces ClawHub install language, resolver, and llms.txt presence
- Test coverage: structure, command-mapping, safety, distribution, planner, ensure-dispatch, plan-json, doctor-drift, host-cleanup, stats-read-only
- Removed packaging-only surfaces: `agents/openai.yaml`, observation recorder, duplicate install-routes doc
- Deduplicated planner context setup across plan/ensure scripts
- Trimmed README and docs of repeated install/marketing wording
- All validation passing: `pre-commit.sh`, `run_tests.sh`, frontend lint/test/build
