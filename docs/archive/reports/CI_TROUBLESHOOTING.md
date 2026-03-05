# CI Troubleshooting

Common CI failures and how to fix them.

## Docker / build-docker

### 401 Unauthorized: access token has insufficient scopes (Docker Hub)

**Symptom:** `failed to fetch oauth token: ... 401 Unauthorized: access token has insufficient scopes`

**Cause:** The build tried to push to Docker Hub (`docker.io`) instead of GHCR. This happened when the workflow used a bare tag like `eth-node-test` (resolves to `docker.io/library/eth-node-test`).

**Fix:** Use only GHCR tags when pushing. The workflow now uses conditional tags: `ghcr.io/owner/repo/eth-node-test:sha` for push, `eth-node-test` only when loading locally (fork PRs).

### Fork PRs: build-docker pushes fail

**Symptom:** Fork PRs show "Permission denied" or "Resource not accessible" when pushing to GHCR.

**Cause:** `GITHUB_TOKEN` for fork PRs has restricted permissions; it cannot push packages to the base repository.

**Expected:** Fork PRs fall back to building the image locally in each job. The `docker-prep` action detects empty `image` and runs the build step. CI is slower but works.

### Can't find action.yml under .github/actions/docker-prep

**Symptom:** `Error: Can't find 'action.yml' ... Did you forget to run actions/checkout before running your local action?`

**Cause:** Local composite actions are loaded from the workspace. The workspace is empty until checkout runs. Jobs that use `./.github/actions/docker-prep` must run `actions/checkout@v4` **before** the docker-prep step so GitHub can find the action definition. The docker-prep action no longer runs checkout itself (avoids double checkout).

## Path filters

### CI didn't run on my PR

**Symptom:** Pushing a PR but ci.yml or shellcheck.yml didn't run.

**Cause:** Path filters. CI runs only when these paths change:
- `**/*.sh`
- `test/Dockerfile`, `test/docker-compose.yml`
- `.github/workflows/ci.yml`
- `.github/actions/**`

**Fix:** Ensure your changes touch one of these. Docs-only or frontend-only changes skip CI. Use `workflow_dispatch` to manually trigger if needed.

## Shellcheck

### SC1091, SC1090, etc. excluded

**Symptom:** Wondering why some shellcheck rules are disabled.

**Cause:** Documented exclusions for known patterns:
- SC2317: Unreachable code (test scripts)
- SC1091: Not following source (relative paths)
- SC1090: Non-constant source (variable paths)
- SC2034: Unused variables (templates)
- SC2031: Subshell variable modification
- SC2181: Check exit code directly (whiptail)

See `.cursorrules` for full rationale.

## Local verification

Run before pushing to catch issues:

```bash
./scripts/pre-commit.sh
```

Or manually: `./test/run_tests.sh --lint-only && bash install/test/test_common_functions.sh`

## Workflow structure

- **build-docker** → (docker-integration + run-* in parallel) → **e2e-client-matrix**
- Shellcheck: run in shellcheck.yml only (ci.yml has no shellcheck job)
- `docker-prep` composite action: setup buildx, pull or build (jobs run checkout first)
- Matrix: 6 client combos (geth+prysm+mev-boost in run-2-e2e), fail-fast

## Artifact retention

| Artifact        | Workflow   | Retention |
|-----------------|------------|-----------|
| coverage-report | frontend   | 7 days    |
| nextjs-build    | frontend   | 7 days    |

CI (ci.yml) does not upload artifacts; the Docker image is pushed to GHCR. To change retention, edit `retention-days` on the `upload-artifact` step.
