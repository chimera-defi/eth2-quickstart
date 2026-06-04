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
