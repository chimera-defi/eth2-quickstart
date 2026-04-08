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

## Latest Update (Client Options Surface, 2026-04-07)

- Added `config/client_options.json` as the shared machine-readable source of truth for supported execution clients, consensus clients, MEV options, ETHGas constraints, and tested presets
- Added `./scripts/eth2qs.sh client-options --json` via `install/utils/client_options.sh` so external wrappers can discover valid flags without re-encoding repo knowledge
- Updated MCP `eth2qs_client_options` to read the same JSON file instead of maintaining a separate hardcoded copy
- Updated README, `docs/SCRIPTS.md`, and agent reference docs to point at the new command
- Validation run: `./scripts/eth2qs.sh client-options --json`, `python3 -m unittest discover -s test -p 'test_mcp_tools.py'`, `bash test/ci_test_mcp_server.sh`
- Follow-up: external harnesses like CLI-Anything can switch from embedded client enums to the repo-native `client-options --json` surface

## Latest Update (Monitoring / Triage Surface, 2026-04-08)

- Added `install/utils/stats_json.py` and `./scripts/eth2qs.sh stats --json` as the machine-readable monitoring surface for service states, recent errors, planner/doctor context, and bounded repair previews
- Added MCP `eth2qs_stats_json` so Claude/Codex can inspect current host state without scraping human-oriented `stats.sh` output
- `stats --json` now classifies several common failure modes from recent journal evidence:
  - missing validator wallet / keys
  - service flag mismatch after binary/config drift
  - config parse failures
  - peer connectivity degradation
  - MEV endpoint refusal
  - locked database / duplicate process symptoms
- Monitoring output now includes planner/doctor context instead of showing a false `pass` on partially installed or warning-state hosts
- Added tests:
  - `install/test/test_stats_json_contract.sh`
  - `test/test_stats_json.py`
  - existing MCP/skill contract tests updated to require `stats --json`
- Updated `README.md`, `docs/SCRIPTS.md`, and skill references to advertise `stats --json` as the preferred monitoring/triage surface
- Validation run:
  - `bash install/test/test_stats_json_contract.sh`
  - `bash install/test/test_stats_read_only.sh`
  - `python3 -m unittest discover -s test -p 'test_*.py'`
  - `bash test/ci_test_mcp_server.sh`
  - `bash test/ci_test_skill_command_mapping.sh`
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 SKIP_SHELLCHECK=true USE_MOCKS=true ./test/run_tests.sh --unit`
- Follow-up:
  - add a guarded `repair --apply` path for clearly safe actions only
  - add explicit software release freshness checks before offering updater automation

## Latest Update (Safe Repair Workflow, 2026-04-08)

- Added `install/utils/repair.sh` and wrapper command `./scripts/eth2qs.sh repair`
- `repair` previews allowlisted safe restart actions derived from `stats --json` and requires `--apply --confirm` before making changes
- Smart refresh now exists via `./scripts/eth2qs.sh restart --smart`, which delegates to the same bounded repair logic instead of restarting the full stack blindly
- Added MCP tools:
  - `eth2qs_repair_preview`
  - `eth2qs_repair_apply`
- Tightened `stats --json` repair previews so some warnings now map to targeted restarts instead of broad full-stack restarts:
  - peer connectivity degradation -> restart consensus client
  - MEV endpoint refusal -> restart the active builder sidecar when one is present
- Added tests:
  - `install/test/test_repair_safe_actions.sh`
  - unit coverage in `test/test_stats_json.py`
  - MCP contract updates in `test/test_mcp_tools.py` and `test/ci_test_mcp_server.sh`
- Updated README, `docs/SCRIPTS.md`, SKILL docs, and MCP docs to point agents toward `repair` and `restart --smart`
- Validation run:
  - `bash install/test/test_repair_safe_actions.sh`
  - `python3 -m unittest discover -s test -p 'test_*.py'`
  - `bash test/ci_test_mcp_server.sh`
  - `bash test/ci_test_skill_command_mapping.sh`
  - `bash test/ci_test_docs_consistency.sh`
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 SKIP_SHELLCHECK=true USE_MOCKS=true ./test/run_tests.sh --unit`
- Follow-up:
  - compare installed client versions to upstream releases before suggesting software updates
  - collapse more of the human `stats.sh` flow onto the JSON triage core to reduce duplicated monitoring logic

## MCP Meta Learnings

- Composite GitHub actions must not reference `secrets.*` directly in `action.yml`; pass tokens through explicit action inputs from the workflow.
- For agent-facing MCP servers, core repo offerings must be explicit tools, not only indirect planner paths. `phase1` and `phase2` needed to be first-class, not hidden behind `ensure_apply`.
- MCP `list_tools` should remain the authoritative schema surface for agents. A compact info/catalog tool is useful, but it should complement the protocol surface rather than replace it.
- Shared-workspace validation should lint tracked repo files only. Untracked neighboring directories can otherwise create false CI/pre-commit failures unrelated to the repo.
- For agent install flows, add a read-only client-options tool when the underlying CLI supports non-interactive flags. Agents should not have to infer valid enum values from prose or source.
