<!-- central-agent-memory:begin -->
## Central Agent Memory

- Central root: `/home/agents/agent-memory`
- Writer namespace: `agents/codex/`
- Durable notes: `agents/codex/private/curated/`
- Shareable facts: `agents/codex/public/`
- Do not store secrets, keys, tokens, cookies, passwords, or `secrets/`
- Search first, then cite memory with IDs like `brain:agent-codex-private:<slug>`
<!-- central-agent-memory:end -->

## Agent Collaboration Rules

<!-- SHARED_ATTRIBUTION_RULES_START -->
- Commit author should be the active agent model identity.
- Commit trailer must include: `Co-authored-by: Chimera <chimera_defi@protonmail.com>`.
- PR description must include:
  - `**Agent:** <actual model name>`
  - `**Co-authored-by:** Chimera <chimera_defi@protonmail.com>`
- Never use placeholder model names; record the actual model used.
- Never push directly to `main`/`master`; use a feature branch and PR.
- Keep one task per PR for clear review and rollback.
- Verify before claiming complete: run relevant tests/lint/checks or explicitly note what was not run.
<!-- SHARED_ATTRIBUTION_RULES_END -->

<!-- token-reduce:begin -->
## Token-Reduce Routing

- If file location is unknown, first run `./skills/token-reduce/scripts/token-reduce-paths.sh <topic words>`
- Use the user’s literal nouns in that first query
- Use `token-reduce-snippet` only after the path list when one excerpt is needed
- Do not start discovery with `find`, `ls -R`, `grep -R`, `rg --files .`, or broad globs
- After discovery, use scoped `rg -g` and targeted reads only
<!-- token-reduce:end -->

<!-- kimi-delegate:begin -->
## Kimi Delegate Routing

- All Kimi calls must go through `kimi-delegate --task "..."` or `--interactive`
- Always create the envelope first with `./skills/kimi-delegate/scripts/plan_prompt.py --task "..."`
- Bundle related questions into one call and include acceptance criteria
- If Kimi fails, inspect telemetry with `./skills/kimi-delegate/scripts/kimi_delegate_telemetry.py summary --days 14`
<!-- kimi-delegate:end -->

<!-- devin-delegate:begin -->
## Devin Delegate Routing

- All Devin calls must go through `devin-delegate --task "..."` or `--interactive`
- Always create the envelope first with `./skills/devin-delegate/scripts/plan_prompt.py --task "..."`
- Bundle each logical work unit into one call, include workspace path and acceptance criteria, and avoid `&`
- If Devin asks for clarification, use Codex guidance first and Claude second before asking the user
- Check telemetry regularly with `./skills/devin-delegate/scripts/devin_delegate_telemetry.py summary --days 14`
<!-- devin-delegate:end -->

## Completion Quality Gate (Mandatory)

- Run the relevant tests, lint checks, or CI-equivalent validation for changed files
- Run a security audit for deployment, secrets, network exposure, or privilege boundary changes
- Run a regression review for install flows, service behavior, or generated configs
- If something could not run, say exactly what was skipped and why

## Meta Learnings

- New `install/utils` helpers should be wired into `scripts/eth2qs.sh`, documented in `docs/SCRIPTS.md`, and covered by at least one structure or Docker smoke test
- Validator exit helpers should reuse the local validator inventory path and hand off client-specific exit logic to `validator_manage.sh`
- Validator entry helpers should print an explicit command template when the deposit CLI is unavailable locally
- Withdrawal-change helpers should support `--dry-run` and a fixture-backed smoke test path for rehearse-before-production flows
