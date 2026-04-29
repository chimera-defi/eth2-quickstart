# CLAUDE.md — AI Assistant Guide for eth2-quickstart

**eth2-quickstart** automates production-ready Ethereum node setup (execution + consensus client pair) on Linux servers. It handles OS hardening, client installation, MEV integration, and optional web-server RPC exposure. It also contains a Next.js marketing site (`frontend/`).

---

## Critical Rules

### 1. Two-Phase Install — Never Combine

| Phase | Script | Runs As | Purpose |
|-------|--------|---------|---------|
| Phase 1 | `run_1.sh` | `root` | OS hardening, user creation, SSH config |
| Phase 2 | `run_2.sh` | new non-root user | Client install, configuration |

A reboot is **mandatory** between phases. Phase 1 changes the SSH port and disables root login. Never chain them: `./run_1.sh && ./run_2.sh` is dangerous.

### 2. Frontend Uses Bun — Never npm

```bash
bun install / bun run / bunx          # always
bun install --frozen-lockfile         # in CI
bun run test                          # runs Jest (not bun test)
```

Commit `bun.lock`, never `package-lock.json`.

### 3. Conventional Commits

`type(scope): description` — types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`

### 4. Default Branch Is `master`

The upstream default branch is `master` (not `main`). Use `master` as the base for PRs.

---

## Architecture

### Config: `exports.sh` is the Single Source of Truth

All variables live in `exports.sh`. Scripts source it at the top. User overrides go in `config/user_config.env` (loaded at the end of `exports.sh`).

Key variable groups: server (`LOGIN_UNAME`, `YourSSHPortNumber`), validator (`FEE_RECIPIENT`, `GRAFITTI`), ports (`ENGINE_PORT`=8551, `MEV_PORT`=18550, `METRICS_PORT`=6060), network hosts (all default to `127.0.0.1`), MEV (`MEV_RELAYS`, `MIN_BID`).

Client config templates live in `configs/<client>/`. Install scripts merge these with `exports.sh` variables to produce final configs.

### Common Functions: `lib/common_functions.sh`

All install scripts **must** source this file. Key categories: logging (`log_info/warn/error`), install lifecycle (`log_installation_start/complete`), directories (`get_script_directories`, `ensure_directory`), config merging (`merge_client_config`), security (`setup_secure_user`, `configure_ssh`, `setup_fail2ban`), services (`create_systemd_service`, `enable_and_start_systemd_service`), file ops (`download_file`, `secure_download`, `ensure_jwt_secret`), checks (`require_root`, `check_system_requirements`), network (`setup_firewall_rules`).

Full reference: `docs/COMMON_FUNCTIONS_REFERENCE.md`.

### Required Script Structure

```bash
#!/bin/bash
# shellcheck source=../../exports.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../exports.sh"
# shellcheck source=../../lib/common_functions.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common_functions.sh"

get_script_directories
require_root  # only for Phase 1 / root-context scripts

log_installation_start "ComponentName"
# ... logic using common functions ...
log_installation_complete "ComponentName" "service_name"
```

Always use `$PROJECT_ROOT`-anchored absolute paths for `source` statements.

---

## Shell Scripting Standards

All scripts that source `exports.sh` inherit `set -Eeuo pipefail` and `IFS=$'\n\t'`. Scripts that don't source it must declare these themselves.

**Key gotchas:**

- **`grep` in pipelines**: append `|| true` — grep exits 1 on no match, killing scripts under `set -e`
- **Source paths**: use `$PROJECT_ROOT/...` absolute paths, never relative
- **`exec` redirect**: `exec > >(tee -a "$LOG_FILE") 2>&1` captures all subsequent stdout — run any `$(...)` command substitutions before it
- **`shift` in `for` loops**: ineffective — use a `while` loop instead
- **Whiptail**: capture output with `$()` and check `$?` separately afterward
- **Heredoc generation**: escape `\$(...)` when you want runtime evaluation inside a generated script
- **`set -u` with functions**: always pass all required positional args — omitting them silently exits

Error handling pattern:
```bash
if ! some_function_call; then
    log_error "Descriptive error message"
    exit 1
fi
```

---

## MEV Implementation

MEV solutions are **mutually exclusive** — install exactly one: MEV-Boost, Commit-Boost, or ETHGas. All install as native binaries (no Docker).

Port allocation: MEV-Boost=18550, Commit-Boost PBS=18550 (drop-in, same port), Commit-Boost Signer=20000.

Specific rules:
- Consensus client configs include a **disabled** builder endpoint by default (`enable-builder: false`) — users enable it manually after MEV is running
- **Commit-Boost**: uses `CB_CONFIG` env var in systemd (not `--config` CLI flag)
- **Commit-Boost signer**: install binary but don't start the service — it needs validator keys configured first
- **Commit-Boost TOML**: `[[relays]]` are top-level array-of-tables; `chain = "Mainnet"` is top-level (not inside a `[chain]` section)
- **Systemd `Environment=`**: `create_systemd_service()` doesn't support it — inject with `sed -i '/^\[Service\]/a Environment="KEY=value"'`
- Verify GitHub release asset URLs via API before hardcoding download patterns

---

## Security Model

This project handles real ETH validator funds. Never weaken the security model.

- Firewall: UFW strict rules (Phase 1)
- SSH: key-only auth, non-standard port, root login disabled
- Services: run as non-root user with minimal privileges
- Secrets: JWT and sensitive data in `$HOME/secrets/`
- Config permissions: 600 for files, 700 for directories
- All services bind to `127.0.0.1` by default
- AIDE file integrity monitoring via `config/aide.conf`

---

## Testing

Run before every push: `./scripts/pre-commit.sh` (shellcheck, shebang checks, dependency validation, unit tests).

Testing hierarchy: Docker-based integration (preferred) → local with mocks (`USE_MOCKS=true`) → lint-only (`./test/run_tests.sh --lint-only`).

Test scripts source `test/lib/test_utils.sh` for shared utilities (`record_test`, `print_test_summary`, `check_shellcheck`, assertions). Each test file must be self-contained; mocks must be sourced before the code under test.

Frontend: `cd frontend && bun run test`
