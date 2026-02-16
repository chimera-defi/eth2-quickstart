# Local Verification Checklist (pre-CI push)

Run before pushing to catch regressions.

## Quick: single command
```bash
./scripts/pre-commit.sh
```
Runs shellcheck, syntax, shebang, dependency validation, run_1/run_2 structure, and common_functions unit tests. Matches shellcheck.yml (shell validation) and ci docker-integration (lint).

## Optional: Docker E2E (if Docker available)
```bash
docker build -t eth-node-test -f test/Dockerfile .
SKIP_BUILD=true ./test/run_e2e.sh --phase=1
SKIP_BUILD=true ./test/run_e2e.sh --phase=2
```

## CI path filtering
See [docs/CI_WORKFLOWS.md](CI_WORKFLOWS.md) for when each workflow runs.
