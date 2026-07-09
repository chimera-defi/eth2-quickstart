# CLAUDE.md - AI Assistant Guide for eth2-quickstart

Read this before editing the repo.

## Project

`eth2-quickstart` installs and hardens an Ethereum node stack on Linux: execution client, consensus client, validator tooling, MEV, and optional reverse proxy/SSL. The repo also contains a Next.js marketing site in `frontend/` and CI in GitHub Actions.

## Non-Negotiables

### 1. Two-Phase Security Model

Installation is split into two phases with a reboot in between.

| Phase | Script | User | Purpose |
| --- | --- | --- | --- |
| 1 | `run_1.sh` | `root` | OS hardening, SSH, user creation |
| 2 | `run_2.sh` | non-root user | Client install and config |

Never combine phases or skip the reboot.

### 2. Frontend Uses Bun

- Use `bun install`, `bun run`, and `bunx`
- Never use `npm`, `npx`, or `package-lock.json`

### 3. Conventional Commits

Use `type(scope): description` with `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, or `perf`.

### 4. Minimum 3-Pass Review Before Push

- Pass 1: functionality
- Pass 2: architecture and context boundaries
- Pass 3: quality, duplication, and shellcheck cleanliness

## Repository Shape

- `exports.sh` is the single source of truth for config variables
- `lib/common_functions.sh` holds shared shell helpers
- `install/consensus/` and `install/execution/` hold client installers
- `install/mev/`, `install/web/`, `install/security/`, `install/ssl/`, and `install/utils/` hold feature-specific helpers
- `test/` contains Docker and shell integration tests
- `docs/` holds reference and workflow docs
- `scripts/` contains user-facing wrapper utilities such as `pre-commit.sh`

## Configuration Rules

- Source `exports.sh` and `lib/common_functions.sh` from install scripts
- Use `$PROJECT_ROOT`-anchored absolute paths for `source`
- Keep user overrides in `config/user_config.env`
- Merge client templates from `configs/<client>/` with `exports.sh`

## Common Functions

Install scripts should follow the standard pattern:

```bash
#!/bin/bash
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

get_script_directories
require_root   # only when needed
log_installation_start "ComponentName"
```

Use `common_functions.sh` for logging, config merging, service setup, downloads, security checks, and network rules.

## Supported Clients

Execution clients: Geth, Erigon, Reth, Nethermind, Besu, Nimbus-eth1, Ethrex.
Consensus clients: Prysm, Lighthouse, Teku, Nimbus, Lodestar, Grandine.

MEV solutions are mutually exclusive: choose either MEV-Boost or Commit-Boost, with ETHGas as an add-on only where supported.

## Development Workflow

- Run `./scripts/pre-commit.sh` before every push
- Local shell checks: `./test/run_tests.sh --lint-only`
- Integration tests: `docker build -t eth-node-test -f test/Dockerfile .`
- E2E: `E2E_EXECUTION=geth E2E_CONSENSUS=prysm E2E_MEV=mev-boost ./test/run_e2e.sh --phase=2`
- Frontend: use `bun install`, `bun run test`, `bun run build`, and `bunx tsc --noEmit`

## Shell Standards

- Scripts that source `exports.sh` already inherit `set -Eeuo pipefail` and `IFS=$'\n\t'`
- Keep `grep` in pipelines safe with `|| true`
- Do not rely on `shift` inside `for` loops
- Check whiptail exit status separately after command substitution
- Escape runtime `$()` in generated heredocs
- Pass all required positional arguments when `set -u` is enabled

## Testing Hierarchy

1. Docker-based integration tests
2. Local mocked tests
3. Lint-only shell validation

Tests should be self-contained and source their own dependencies.

## Security Model

- Firewall: UFW
- SSH: key-only auth, non-standard port, root login disabled
- Services: non-root, minimal privileges
- Secrets: JWT and sensitive data live under `$HOME/secrets/`
- Config permissions: `600` for files, `700` for directories
- Default bindings: `127.0.0.1`
- AIDE is enabled for integrity monitoring

Never weaken the security model.

## MEV Rules

- Install MEV solutions as native binaries, not Docker
- Respect the documented port assignments and client config defaults
- Use `ensure_jwt_secret()` before starting services
- Commit-Boost binary mode uses `CB_CONFIG`
- Insert `Environment=` lines into the correct systemd section

## Bootstrap

```bash
curl -sSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/master/install.sh | bash
```

After cloning, `install.sh` launches `install/utils/configure.sh` to generate phase scripts and persist choices in `config/user_config.env`.

## Anti-Patterns

- `npm install` in frontend
- Duplicate logging helpers
- Relative `source` paths
- `./run_1.sh && ./run_2.sh`
- Docker for MEV services
- Both MEV-Boost and Commit-Boost installed together
- Calling functions without required args
- `grep` in `set -e` pipelines without `|| true`

## Key Docs

- `docs/CONFIGURATION_GUIDE.md`
- `docs/COMMON_FUNCTIONS_REFERENCE.md`
- `docs/MEV_GUIDE.md`
- `docs/SECURITY_GUIDE.md`
- `docs/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md`
- `docs/CI_WORKFLOWS.md`
- `docs/CI_TROUBLESHOOTING.md`
- `docs/COMMIT_MESSAGES.md`
- `docs/WORKFLOW.md`
- `docs/GLOSSARY.md`
- `frontend/README.md`

