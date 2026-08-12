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

**Note:** docs changes now trigger `shellcheck.yml`, which also runs `test/ci_test_docs_consistency.sh` for active-doc link/legacy-reference checks. Heavy Docker integration in `ci.yml` still skips docs-only changes. `campaign-constants.yml` exists because no other workflow's paths union docs *and* the frontend blog pages *and* the deck — a docs-only or frontend/deck-only PR would otherwise skip the check that keeps the bake-off campaign's measured constants (restart rate, cutoff date, history-mode caveat) consistent across all of them (see `test/ci_test_campaign_constants.sh`, issue #230).

## Artifact retention

| Artifact        | Workflow   | Retention |
|-----------------|------------|-----------|
| coverage-report | frontend   | 7 days    |
| nextjs-build    | frontend   | 7 days    |
