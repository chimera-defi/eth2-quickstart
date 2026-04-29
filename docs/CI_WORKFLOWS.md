# CI Workflow Path Filtering

Workflows run only when relevant files change. Docs-only changes skip most CI.

| Workflow | Triggers on | Skips |
|----------|-------------|-------|
| **ci.yml** | `**/*.sh`, `test/Dockerfile`, `test/docker-compose.yml`, `.github/workflows/ci.yml`, `.github/actions/**` | Docs, config, frontend |
| **shellcheck.yml** | `**/*.sh`, `README.md`, `docs/**`, `.github/workflows/shellcheck.yml` | Frontend, non-security config-only |
| **frontend.yml** | `frontend/**`, `.github/workflows/frontend.yml` | Shell, docs, config |
| **security.yml** | `install/security/**`, `configs/**`, `lib/common_functions.sh`, `docs/*security*`, `docs/validate_security_safe.sh` | Most changes |
| **pr-checks.yml** | `frontend/**`, `**/*.sh`, `test/**`, `install/**`, `lib/**`, `configs/**`, `.github/**` | Docs-only |

**Note:** docs changes now trigger `shellcheck.yml`, which also runs `test/ci_test_docs_consistency.sh` for active-doc link/legacy-reference checks. Heavy Docker integration in `ci.yml` still skips docs-only changes.

## Artifact retention

| Artifact        | Workflow   | Retention |
|-----------------|------------|-----------|
| coverage-report | frontend   | 7 days    |
| nextjs-build    | frontend   | 7 days    |
