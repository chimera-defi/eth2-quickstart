# Agent Collaboration Rules

<!-- SHARED_ATTRIBUTION_RULES_START -->
## Shared Attribution & Meta Learnings

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

- If file location is unknown, your first discovery command MUST be `./skills/token-reduce/scripts/token-reduce-paths.sh topic words`.
- Use the user's literal nouns from the prompt in that first query (feature name, file stem, hook name, symbol).
- Use `./skills/token-reduce/scripts/token-reduce-snippet.sh topic words` only if one ranked excerpt is needed after the path list.
- Do not start repo discovery with `find .`, `ls -R`, `grep -R`, `rg --files .`, or broad `Glob` patterns.
- Use scoped `rg -g` and targeted reads only after helper output.
<!-- token-reduce:end -->

<!-- kimi-delegate:begin -->
## Kimi Delegate Routing — MANDATORY

All Kimi subagent calls MUST route through the skill wrapper. Direct `pi --provider kimi-coding` calls are **prohibited** — they bypass telemetry, fallback, auth detection, and timeout scaling.

- **One-liner:** `kimi-delegate --task "..."`
- **Interactive:** `kimi-delegate --interactive`
- **Long path (fallback):** `./skills/kimi-delegate/scripts/delegate.py --task "..."`

**Why this matters:**
- Structured envelopes prevent vague handoffs
- Auto-scaling timeouts prevent hangs on large repos
- Auth error detection gives explicit resume steps instead of silent failures
- Codex fallback ensures tasks always complete
- Telemetry enables continuous improvement

**Bypassing the wrapper will be detected and reported.**

- Always produce an envelope first with `./skills/kimi-delegate/scripts/plan_prompt.py --task "..."`.
- Keep delegation scoped and include acceptance criteria.
- If Kimi fails, keep fallback enabled and inspect telemetry (`./skills/kimi-delegate/scripts/kimi_delegate_telemetry.py summary --days 14`).
<!-- kimi-delegate:end -->

<!-- devin-delegate:begin -->
## Devin Delegate Routing — MANDATORY

All Devin calls MUST route through the skill wrapper. Direct `devin --print` and `devin --task` calls are **prohibited** — they bypass envelope checks, fallback routing, clarification handling, and telemetry.

- **One-liner:** `devin-delegate --task "..."`
- **Interactive:** `devin-delegate --interactive`
- **Long path (fallback):** `./skills/devin-delegate/scripts/delegate.py --task "..."`

**Why this matters:**
- Structured envelopes prevent vague handoffs
- Codex then Claude guidance resolves many clarification loops before human escalation
- Provider fallback keeps execution moving when Devin fails
- Telemetry enables continuous improvement

**Bypassing the wrapper will be detected and reported.**

- Always produce an envelope first with `./skills/devin-delegate/scripts/plan_prompt.py --task "..."`.
- Keep delegation scoped and include acceptance criteria.
- If Devin asks for clarification, use Codex guidance first and Claude second before asking a human.
- Inspect telemetry regularly (`./skills/devin-delegate/scripts/devin_delegate_telemetry.py summary --days 14`).
<!-- devin-delegate:end -->

## Completion Quality Gate (Mandatory)

Before marking any task complete, verify the change set against the repository's review and release standards.

- Run the relevant tests, lint checks, or CI-equivalent validation for the files you changed.
- Perform a security audit for any change that touches deployment, secrets, network exposure, or privilege boundaries.
- Perform a regression review for any change that can alter install flows, service behavior, or generated configs.
- If a required check could not run, say exactly what was skipped and why.

## Meta Learnings

- New `install/utils` helpers should be wired into `scripts/eth2qs.sh`, documented in `docs/SCRIPTS.md`, and covered by at least one structure or Docker smoke test.
- Validator exit helpers should reuse the local validator inventory path and delegate client-specific exit logic to `validator_manage.sh`.
- Validator entry helpers should prefer an explicit command template when the deposit CLI is not installed locally so operators still get a usable offline checklist.
- Withdrawal-change helpers should support a no-side-effect `--dry-run` preview and a fixture-backed smoke test path so agents can rehearse the workflow in the live geth + Prysm container before touching production keys.
- Treat PR descriptions as live metadata: update scope, dependencies, verification, and supersession notes whenever the head changes materially.
- Before closing a PR as superseded, prove coverage with ancestry for stacked commits and blob or semantic comparisons for copied work; record both head SHAs.
- Link review evidence with immutable commit-SHA URLs, and keep screenshots out of the merge tree unless durable documentation references them.
- Validate agent identity, required trailers, and PR attribution fields before the first push; late attribution repair rewrites downstream SHAs and checks.
- Re-read the live PR head before final review conclusions; cached review refs can become stale while a PR is still active.
- Never publish a disk/footprint figure without the lifecycle phase it was measured at (at snap-sync, steady-state, or partial @cap). A bare number caused both bake-off disk corrections: nethermind's ~251 GiB was pre-backfill, ethrex's ~467 GiB was mid-climb, and an EL can move ~4x between reporting synced and settling. If only one phase was captured, say which one.
- A green CI run does not mean the site published: the deploy pipeline lives outside this repo, and a failed publish keeps serving the previous build at 200. The Post-deploy smoke job in frontend.yml checks the live commit SHA and the route list after a merge to master; if it fails, the pipeline's own logs are the place to look.
