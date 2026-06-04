# Agent Handoff

Use this file to preserve context across sessions.

## Active Defaults
## Latest Update (Withdrawal helper dry-run and live Prysm/geth smoke, 2026-06-04)

- Added a dry-run path to `./scripts/eth2qs.sh validator-withdrawal-changes` so operators can preview the exact signing and submission commands without writing or POSTing anything.
- The validator inventory now includes freshness metadata in JSON (`generated_at_utc`, `beacon_query_status`) so agents can tell when the snapshot was taken and whether the beacon query succeeded.
- Added a fixture-backed smoke test for the withdrawal helper and wired it into the phase-2 E2E flow so the helper is exercised in the live Prysm + geth container.
- Repo guidance updates:
  - tightened the validator management docs for dry-run usage and inventory freshness
  - added the new dry-run command to the script reference and agent skill command list
  - recorded the rehearsal pattern in the skill improvement notes

- Start new work from latest `origin/master`.
- Preserve valuable uncommitted work before syncing (stash or branch).
- Use a fresh branch + fresh PR for each new task.

## Latest Update (Withdrawal helper dry-run and live Prysm/geth smoke, 2026-06-04)

- Added focused validator lifecycle wrappers on top of the shared inventory surface:
  - `./scripts/eth2qs.sh validators --json` lists active validators with index, status, and balance.
  - `./scripts/eth2qs.sh validator-exit` prints the 0x00/0x01 exit checklist and hands off to the managed voluntary-exit flow.
  - `./scripts/eth2qs.sh validator-withdrawal-changes` prints and optionally submits BLS-to-execution changes for `0x00` validators.
  - `./scripts/eth2qs.sh validator-create-0x02` prints the 0x02 compounding checklist and can launch a local deposit CLI with `--compounding`.
  - `./scripts/eth2qs.sh validator-manage` remains the combined exit / consolidation menu.
- Reused the local validator inventory path in both the exit and compounding helpers so operators see the current node state before taking action.
- Validated the helper flow locally with the repo's existing E2E tooling on Geth + Prysm:
  - `bash test/ci_test_run_2.sh`
  - `bash test/run_e2e.sh --phase=2`
  - `bash -n install/utils/validator_exit.sh install/utils/validator_create_0x02.sh scripts/eth2qs.sh test/ci_test_run_2.sh test/docker_test.sh test/validate_nginx_config.sh`
  - `shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 install/utils/validator_exit.sh install/utils/validator_create_0x02.sh scripts/eth2qs.sh test/ci_test_run_2.sh test/docker_test.sh test/validate_nginx_config.sh`
- Repo guidance updates:
  - added validator helper routing to `skills/eth2-quickstart/SKILL.md`
  - added the validator commands to `skills/eth2-quickstart/references/commands.md`
  - added a durable learning note to `skills/eth2-quickstart/references/improvement.md`
- Review note:
  - the PR commit-message rule failed only because of an earlier non-conventional commit subject; rebasing and renaming it to `fix(validators): pass compounding flag to deposit CLI` fixed the gate locally.

## Latest Update (Batteries-included Caddy guardrails pass, 2026-04-20)

- Added a dry-run path to `./scripts/eth2qs.sh validator-withdrawal-changes` so operators can preview the exact signing and submission commands without writing or POSTing anything.
- The validator inventory now includes freshness metadata in JSON (`generated_at_utc`, `beacon_query_status`) so agents can tell when the snapshot was taken and whether the beacon query succeeded.
- Added a fixture-backed smoke test for the withdrawal helper and wired it into the phase-2 E2E flow so the helper is exercised in the live Prysm + geth container.
- Repo guidance updates:
  - tightened the validator management docs for dry-run usage and inventory freshness
  - added the new dry-run command to the script reference and agent skill command list
  - recorded the rehearsal pattern in the skill improvement notes

## Latest Update (Withdrawal credential changes and safe rehearsal path, 2026-06-04)

- Added a dedicated BLS-to-execution helper for `0x00` validators: `./scripts/eth2qs.sh validator-withdrawal-changes`.
- The local validator inventory now shows withdrawal credential type so agents can see `0x00`, `0x01`, and `0x02` at a glance before taking action.
- The helper is designed for safe rehearsal with `--validators-json`, stubbed deposit CLI, and stubbed beacon POSTs before live usage.
- The tested flow for this branch now includes: `bash test/ci_test_run_2.sh`, `bash test/run_e2e.sh --phase=2`, and a fixture-driven helper test that stubs signing/submission.
- Repo guidance updates:
  - added validator withdrawal-change routing to `skills/eth2-quickstart/SKILL.md`
  - added the command to `skills/eth2-quickstart/references/commands.md`
  - added durable learning notes to `skills/eth2-quickstart/references/improvement.md`

## Latest Update (Validator lifecycle helpers and local geth/Prysm E2E, 2026-06-04)

- Added focused validator lifecycle wrappers: `validators --json`, `validator-exit`, `validator-create-0x02`, `validator-manage`.
- Reused local validator inventory in exit and compounding helpers.
- Validated: `bash test/ci_test_run_2.sh`, `bash test/run_e2e.sh --phase=2`, shellcheck pass on all new scripts.

## Archived Updates (compressed)

**Batteries-included Caddy guardrails (2026-04-20):** `install/web/caddy_helpers.sh` now bootstraps required modules (`http.handlers.rate_limit`, `dns.providers.cloudflare`) via Caddy download API. `CADDY_ENSURE_MODULES`, `CADDY_REQUIRED_MODULES`, `CADDY_REQUIRED_PACKAGES` added to exports.sh. E2E: 29/29 passing.

**Rate-limit dedupe + guardrail hooks (2026-04-20):** `proxy_config_renderer.sh` centralizes shared anti-abuse thresholds (RPM/burst/conn-limit) rendered into both Nginx + Caddy. `config/edge_policy.env` uses `VAR="${VAR:-default}"` semantics. Added `test/validate_review_guardrails.sh`; wired into ci_test_run_2.sh (Test 16) and docker_test.sh. E2E: 29/29.

**Security/regression audit gate + cleanup (2026-04-20):** Added persistent completion criteria to AGENTS.md. shellcheck + bash -n + E2E all pass.

**Strict-mode parity + multi-pass revalidation (2026-04-20):** Strict-mode consistency pass across run_1/run_2 and install scripts. All gates pass.

**Multi-pass Caddy/Nginx hardening + non-root run_2 parity (2026-04-19):** run_2 enforces non-root execution. Nginx/Caddy hardening parity. E2E: 29/29.

**CI run-2 fix: /workspace ownership (2026-04-19):** Docker testuser ownership fix for /workspace. CI green.

**CI shellcheck fix + fresh-image multi-pass rerun (2026-04-19):** Shellcheck exclusion gaps fixed. All CI checks passing.

**Multi-pass CI/local parity review + Docker E2E hardening (2026-04-19):** Docker image hardening. E2E matrix consistent.

**CI fix: Nginx hardening backup include collision (2026-04-19):** Resolved nginx include collision on fresh image. CI green.

**CI fix: Nginx gzip duplicate in run_2 E2E (2026-04-18):** Deduped gzip directive. CI green.

**Merge-hardening CI flake guard (2026-04-18):** Added flake guard for merge-race conditions in CI. Green.

**Edge polish loop pass (2026-04-18):** Minor edge policy cleanup pass. All validators pass.

**Edge performance + parity feature bundle (2026-04-18):** RPC caching, keepalive tuning, Nginx/Caddy parity. E2E: 29/29.

**Edge-policy refactor pass (2026-04-18):** Policy variables extracted to `config/edge_policy.env`. Backward compatible.

**PR #170 docker-integration CI fix (2026-04-18):** Fixed docker-integration CI workflow for PR #170. Green.

**Unified Nginx/Caddy edge policy + RPC cache hardening (2026-04-18):** Single shared edge-policy config rendered into both proxies. RPC path cache added.

**PR watch refinement pass (2026-04-13):** PR watch cron improved. Fewer false-positive responses.

**CLI-Anything PR watch cron (2026-04-13):** Added pr-watch cron automation to agent skill.

**PR #168 CI fix (2026-04-10):** Fixed CI failure in PR #168. Green.

**run_2 unknown-option hardening (2026-04-08):** run_2.sh rejects unknown flags gracefully.

**PR #156 — Agent Skill Rollup (2026-03-13–2026-03-20):** MCP server, client options surface, monitoring/triage surface, Snort IDS, safe repair workflow, monitoring platform all landed as a single rollup PR.

**MCP server feature branch (2026-03-26):** MCP tools: `phase1`, `phase2`, `list_tools`, `client_options` added as first-class tools (not hidden behind planner paths).

**Client Options Surface (2026-04-07):** `client_options` MCP tool exposes valid enum values for execution/consensus clients without agents having to infer from source.

**Monitoring / Triage Surface (2026-04-08):** `monitoring` MCP tool exposes node health, sync status, and peer counts.

**Snort Default-On Baseline + Optional IDS Profile (2026-04-09–2026-04-13):** Snort IDS baseline enabled by default; optional profile for heavier detection. Fail-closed on missing config.

**Safe Repair Workflow (2026-04-08):** `repair` MCP tool adds non-destructive node repair path (restart, re-sync, JWT refresh).

**Monitoring Platform Pass (2026-04-08):** Shared monitoring helper `install/utils/monitor_common.py`; thin shell dispatcher `stats.sh`; `eth2qs.sh update-check --json`, `debug --json --service <name>`, `monitor export --json`, `monitor snapshot --json`. JSON-based output for bots/dashboards.

**Caddy install-enforced rate-limit + fail2ban defaults (2026-04-21):** Caddy install now enforces rate-limit module at install time; fail2ban jail defaults tightened. E2E: 29/29.

## MCP Meta Learnings

- Composite GitHub actions must not reference `secrets.*` directly in `action.yml`; pass tokens through explicit action inputs from the workflow.
- For agent-facing MCP servers, core repo offerings must be explicit tools, not only indirect planner paths. `phase1` and `phase2` needed to be first-class, not hidden behind `ensure_apply`.
- MCP `list_tools` should remain the authoritative schema surface for agents. A compact info/catalog tool is useful, but it should complement the protocol surface rather than replace it.
- Shared-workspace validation should lint tracked repo files only. Untracked neighboring directories can otherwise create false CI/pre-commit failures unrelated to the repo.
- For agent install flows, add a read-only client-options tool when the underlying CLI supports non-interactive flags. Agents should not have to infer valid enum values from prose or source.
