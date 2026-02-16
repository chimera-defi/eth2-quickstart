# CI Workflow Path Filtering

Workflows run only when relevant files change. Docs-only changes skip most CI.

| Workflow | Triggers on | Skips |
|----------|-------------|-------|
| **ci.yml** | `**/*.sh`, `test/Dockerfile`, `test/docker-compose.yml`, `.github/workflows/ci.yml`, `.github/actions/**` | Docs, config, frontend |
| **shellcheck.yml** | `**/*.sh`, `.github/workflows/shellcheck.yml` | Docs, config, frontend (sole shell validation; ci.yml has no shellcheck job) |
| **frontend.yml** | `frontend/**`, `.github/workflows/frontend.yml` | Shell, docs, config |
| **security.yml** | `install/security/**`, `configs/**`, `lib/common_functions.sh`, `docs/*security*`, `docs/validate_security_safe.sh` | Most changes |
| **pr-checks.yml** | `frontend/**`, `**/*.sh`, `test/**`, `install/**`, `lib/**`, `configs/**`, `.github/**` | Docs-only |

**Note:** security.yml runs on security-related doc changes (`docs/*security*`). Other docs-only changes skip ci, shellcheck, frontend, and pr-checks path filters.

## Artifact retention

| Artifact        | Workflow   | Retention |
|-----------------|------------|-----------|
| coverage-report | frontend   | 7 days    |
| nextjs-build    | frontend   | 7 days    |
