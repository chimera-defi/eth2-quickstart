# CI Workflow Path Filtering

Workflows run only when relevant files change. Docs-only changes skip most CI.

| Workflow | Triggers on | Skips |
|----------|-------------|-------|
| **ci.yml** | `**/*.sh`, `test/Dockerfile`, `test/docker-compose.yml`, `.github/workflows/ci.yml`, `.github/actions/**` | Docs, config, frontend |
| **shellcheck.yml** | `**/*.sh`, `README.md`, `docs/**`, `.github/workflows/shellcheck.yml` | Frontend, non-security config-only |
| **frontend.yml** | `frontend/**`, `.github/workflows/frontend.yml` | Shell, docs, config |
| **security.yml** | `install/security/**`, `configs/**`, `lib/common_functions.sh`, `docs/*security*`, `docs/validate_security_safe.sh` | Most changes |
| **pr-checks.yml** | `frontend/**`, `**/*.sh`, `test/**`, `install/**`, `lib/**`, `configs/**`, `.github/**` | Docs-only |
| **campaign-constants.yml** | The bake-off corpus only: `docs/CLIENT_BAKEOFF_*.md`, `docs/HOW_WE_TESTED_WITH_CLAUDE.md`, `docs/blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md`, the four `frontend/app/blog/*/page.tsx` bake-off pages, `frontend/public/deck/bakeoff.html` | Everything else |
| **attribution.yml** | Every PR — no path filter | Nothing (deliberately unconditional) |

**Note:** docs changes now trigger `shellcheck.yml`, which also runs `test/ci_test_docs_consistency.sh` for active-doc link/legacy-reference checks. Heavy Docker integration in `ci.yml` still skips docs-only changes. `campaign-constants.yml` exists because no other workflow's paths union docs *and* the frontend blog pages *and* the deck — a docs-only or frontend/deck-only PR would otherwise skip the check that keeps the bake-off campaign's measured constants (restart rate, cutoff date, history-mode caveat) consistent across all of them (see `test/ci_test_campaign_constants.sh`, issue #230). `attribution.yml` has no path filter at all, on purpose: it validates the PR/commit attribution contract (AGENTS.md L6-7 — commit author = agent identity, `Co-authored-by: Chimera` trailer, PR body `**Agent:**`/`**Co-authored-by:**` fields), which is a property of the PR itself, not of which files it touches (see `test/ci_test_pr_attribution.sh`, issue #230). **It does not check the post-merge squash commit on `master`, and this is a known, unresolved gap in issue #230 item 2, not a solved problem.** A pre-merge check structurally can't gate the squash commit (it doesn't exist yet). Worse, checked against this repo's last 6 real merges, the squash commit does *not* end up carrying the Chimera trailer the issue asks for: `gh pr merge --squash` makes the squash commit's author the human who ran the merge, and GitHub then excludes that human from the generated co-author list (you can't co-author with yourself) — so the trailer that lands names the *agent* instead, the inverse of what's required. This reproduced on 5 of the last 6 merges (#247–#251); the one exception (#252) is a 3-commit PR where GitHub's multi-commit squash template concatenates every original commit body as inert text, a formatting artifact rather than a rollup mechanism, and not representative of the common single-commit case. Closing this for real would need the merge itself performed by a bot/agent-owned token rather than a human's — a workflow change, not a CI check.

## Artifact retention

| Artifact        | Workflow   | Retention |
|-----------------|------------|-----------|
| coverage-report | frontend   | 7 days    |
| nextjs-build    | frontend   | 7 days    |
