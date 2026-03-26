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

## Latest Update (MCP server feature branch, 2026-03-26)

- Added a thin stdio MCP server under `mcp_server/` so Claude Code and Codex can use `eth2-quickstart` as native tools instead of only skill/docs ingestion
- Server wraps the canonical `./scripts/eth2qs.sh` surface; it does not reimplement install or operations logic
- Added guarded MCP tools for `doctor --json`, `plan --json`, `ensure` preview/apply, `stats`, bounded `logs`, `start/stop/restart`, dry-run cleanup, and explicit `monad-install`
- Mutating MCP tools require `confirm=true` and `confirmation_token='apply'`
- Added `skills/eth2-quickstart/references/mcp.md` plus README wiring for Claude Code / Codex setup via `./mcp_server/run_eth2qs_mcp.sh`
- Added Python/unit/contract coverage in `test/test_mcp_tools.py` and `test/ci_test_mcp_server.sh`
- Wired MCP checks into CI, `test/run_tests.sh`, and `scripts/pre-commit.sh`
- Tightened lint scope in `test/run_tests.sh` and `scripts/pre-commit.sh` to tracked repo shell files only so unrelated workspace content does not break validation
- Validation run: `bash test/ci_test_mcp_server.sh`, `bash test/ci_test_skill_distribution.sh`, `bash test/ci_test_docs_consistency.sh`, `./scripts/pre-commit.sh`
- Follow-up: publish/test the skill separately in ClawHub once auth exists; MCP server itself is local-stdio ready now
- Follow-up on 2026-03-26: fixed `.github/actions/docker-prep` to take `github_token` as an input instead of referencing `secrets` directly, which was breaking all Docker-based CI jobs on PR #157
- Local runtime proof on 2026-03-26: the MCP server initialized successfully through the Python MCP SDK, `codex exec` invoked `eth2qs_info` and returned the wrapper path, and Claude Code reached MCP connection state locally but non-interactive tool invocation was blocked by local usage quota rather than by the server
- Discoverability pass on 2026-03-26: added a compact MCP quickstart to `README.md`, added an MCP pointer to `llms.txt`, and added a native MCP tools callout/snippet to `frontend/components/sections/Agents.tsx`; validated with docs consistency, frontend lint/test/build
- MCP lifecycle pass on 2026-03-26: added explicit `eth2qs_phase1` and `eth2qs_phase2` tools so server hardening and Ethereum client install are first-class MCP actions instead of only planner-driven behavior; validated in unit tests and via live MCP `list_tools`
