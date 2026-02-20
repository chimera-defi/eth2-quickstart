# CLAUDE.md — AI Assistant Guide for eth2-quickstart

This file provides essential context for AI assistants working in this repository. Read it in full before making any changes.

---

## Project Overview

**eth2-quickstart** is a collection of shell scripts for quickly setting up a production-ready Ethereum node (execution + consensus client pair) on a Linux VPS or bare metal server. It handles security hardening, client installation, MEV integration, and optional web-server setup (Nginx/Caddy) for exposing an RPC endpoint.

The project also includes a **Next.js marketing website** (`frontend/`) and comprehensive **CI pipelines** via GitHub Actions.

---

## Critical Rules — Read First

### 1. TWO-PHASE SECURITY MODEL (Non-Negotiable)

The installation is split into two mandatory phases with a reboot in between:

| Phase | Script | User Context | Purpose |
|-------|--------|-------------|---------|
| **Phase 1** | `run_1.sh` | `root` | OS hardening, user creation, SSH config |
| **Phase 2** | `run_2.sh` | new non-root user | Client install, configuration |

**NEVER combine phases or skip the reboot.** Phase 1 changes SSH port and disables root login; the user must verify SSH access with new credentials before proceeding.

```bash
# ❌ DANGEROUS
./run_1.sh && ./run_2.sh

# ✅ CORRECT
sudo ./run_1.sh
sudo reboot
# SSH back as new user (default: eth@<ip>)
./run_2.sh
```

### 2. Frontend Uses Bun — NEVER npm

```bash
# ❌ NEVER
npm install / npm run / npx

# ✅ ALWAYS
bun install / bun run / bunx
bun install --frozen-lockfile   # in CI
bun run test                    # runs Jest (not bun test)
```

Lock file: commit `bun.lock` (or `bun.lockb`), never `package-lock.json`.

### 3. Conventional Commits Required

Format: `type(scope): description`

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`

Examples:
- `feat(consensus): add grandine client support`
- `fix(security): correct SSH port hardening in run_1`
- `docs(frontend): update bun migration guide`

### 4. Minimum 3-Pass Code Review Before Push

- **Pass 1**: Functionality — all function calls resolve, no broken references
- **Pass 2**: Architecture compliance — correct user context (root vs. non-root), common functions used
- **Pass 3**: Code quality — no duplication, shellcheck clean, consistent error handling

---

## Repository Structure

```
eth2-quickstart/
├── exports.sh                     # SINGLE SOURCE OF TRUTH for all config variables
├── run_1.sh                       # Phase 1: root-level OS setup
├── run_2.sh                       # Phase 2: non-root client install
├── install.sh                     # Bootstrap one-liner (curl | bash entry point)
│
├── lib/
│   └── common_functions.sh        # 35 shared functions (logging, services, security)
│
├── install/
│   ├── consensus/                 # Consensus client installers
│   │   ├── prysm.sh
│   │   ├── lighthouse.sh
│   │   ├── teku.sh
│   │   ├── nimbus.sh
│   │   ├── lodestar.sh
│   │   └── grandine.sh
│   ├── execution/                 # Execution client installers
│   │   ├── geth.sh
│   │   ├── erigon.sh
│   │   ├── reth.sh
│   │   ├── nethermind.sh
│   │   ├── besu.sh
│   │   ├── nimbus_eth1.sh
│   │   └── ethrex.sh
│   ├── mev/                       # MEV solution installers
│   │   ├── install_mev_boost.sh
│   │   ├── install_commit_boost.sh
│   │   └── install_ethgas.sh
│   ├── web/                       # Web server installers
│   │   ├── install_nginx.sh / install_nginx_ssl.sh
│   │   └── install_caddy.sh / install_caddy_ssl.sh
│   ├── security/                  # Security hardening scripts
│   ├── ssl/                       # SSL certificate setup
│   ├── utils/                     # Utility scripts
│   │   ├── configure.sh           # TUI wizard (whiptail)
│   │   ├── install_dependencies.sh # Centralized package management
│   │   ├── doctor.sh              # Health diagnostics
│   │   └── select_clients.sh      # Interactive client selector
│   └── test/
│       └── test_common_functions.sh
│
├── configs/                       # Base config templates per client
│   ├── prysm/
│   ├── teku/
│   ├── nimbus/
│   ├── lodestar/
│   ├── grandine/
│   ├── besu/
│   ├── nethermind/
│   └── AGENT_REFERENCE.md
│
├── config/
│   ├── aide.conf                  # AIDE integrity monitoring config
│   └── user_config.env.example   # User override template
│
├── test/                          # Docker-based integration tests
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── run_tests.sh               # Local test runner
│   ├── docker_test.sh             # Real system calls inside Docker
│   ├── run_e2e.sh                 # E2E test runner
│   ├── ci_test_run_1.sh
│   ├── ci_test_run_2.sh
│   └── lib/
│       └── test_utils.sh          # Shared test utilities (colors, assertions, shellcheck)
│
├── frontend/                      # Next.js marketing website
│   ├── app/                       # Next.js App Router pages
│   ├── components/                # React components
│   ├── lib/                       # Utility functions and constants
│   ├── __tests__/                 # Jest tests
│   ├── package.json               # packageManager: bun@latest
│   └── bun.lock
│
├── scripts/
│   └── pre-commit.sh              # Local CI simulation — run before pushing
│
├── docs/                          # Extended documentation
│   ├── CONFIGURATION_GUIDE.md
│   ├── MEV_GUIDE.md / MEV_QUICK_REFERENCE.md
│   ├── SECURITY_GUIDE.md
│   ├── SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md
│   ├── COMMON_FUNCTIONS_REFERENCE.md
│   ├── CI_WORKFLOWS.md / CI_TROUBLESHOOTING.md
│   ├── COMMIT_MESSAGES.md
│   ├── WORKFLOW.md
│   └── GLOSSARY.md
│
└── .github/
    ├── workflows/
    │   ├── ci.yml           # Docker integration tests (shell changes)
    │   ├── shellcheck.yml   # Shellcheck + shebang + dependency validation
    │   ├── frontend.yml     # Bun-based frontend CI
    │   ├── security.yml     # Security validation
    │   └── pr-checks.yml
    └── actions/docker-prep/ # Reusable Docker setup action
```

---

## Configuration Architecture

### Single Source of Truth: `exports.sh`

All configuration variables live in `exports.sh`. Scripts source it at the top. Users edit it to customize their setup. User overrides go in `config/user_config.env` (loaded at end of `exports.sh`).

```
exports.sh → Base Template + User Variables → Final Client Config
```

Key variable categories:
- **Server**: `LOGIN_UNAME`, `YourSSHPortNumber`, `SERVER_NAME`
- **Validator**: `FEE_RECIPIENT`, `GRAFITTI`, `MAX_PEERS`, `PRYSM_CPURL`
- **Client caches**: `GETH_CACHE`, `TEKU_CACHE`, `NIMBUS_CACHE`, etc.
- **Ports**: `ENGINE_PORT` (8551), `MEV_PORT` (18550), `METRICS_PORT` (6060), client REST ports
- **Network**: `LH`, `CONSENSUS_HOST`, `MEV_HOST` (all default to `127.0.0.1`)
- **MEV**: `MEV_RELAYS`, `MIN_BID`, timeout settings

### Config Templates in `configs/`

Each client has base YAML/TOML/JSON templates in `configs/<client>/`. Install scripts merge these with variables from `exports.sh` to produce final configs. See `docs/CONFIGURATION_GUIDE.md`.

---

## Common Functions Library (`lib/common_functions.sh`)

All install scripts MUST source this file. It provides 35 functions:

| Category | Functions |
|----------|-----------|
| **Logging** | `log_info()`, `log_warn()`, `log_error()` |
| **Install lifecycle** | `log_installation_start()`, `log_installation_complete()` |
| **Directories** | `get_script_directories()`, `ensure_directory()`, `create_temp_config_dir()` |
| **Config merging** | `merge_client_config()` (JSON, YAML, TOML) |
| **Security** | `setup_secure_user()`, `configure_ssh()`, `setup_fail2ban()`, `secure_config_files()` |
| **Services** | `create_systemd_service()`, `enable_and_start_systemd_service()` |
| **File ops** | `download_file()`, `secure_download()`, `extract_archive()`, `ensure_jwt_secret()` |
| **Checks** | `check_system_requirements()`, `check_system_compatibility()`, `require_root()` |
| **Network** | `setup_firewall_rules()`, `apply_network_security()` |

Full reference: `docs/COMMON_FUNCTIONS_REFERENCE.md`.

### Required Script Structure

Every install script must follow this pattern:

```bash
#!/bin/bash
# shellcheck source=../../exports.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../exports.sh"
# shellcheck source=../../lib/common_functions.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common_functions.sh"

get_script_directories
require_root  # Only for scripts that need root (Phase 1 scripts)

log_installation_start "ComponentName"

# ... script logic using common functions ...

log_installation_complete "ComponentName" "service_name"
```

**Important**: Always use `$PROJECT_ROOT` for source statements (absolute paths), never relative paths, to avoid CI resolution issues.

---

## Supported Ethereum Clients

### Execution Clients

| Client | Script | Language | Notes |
|--------|--------|----------|-------|
| Geth | `geth.sh` | Go | Default/most stable |
| Erigon | `erigon.sh` | Go | Fast sync, low memory |
| Reth | `reth.sh` | Rust | High performance |
| Nethermind | `nethermind.sh` | C# | Enterprise |
| Besu | `besu.sh` | Java | Enterprise/compliance |
| Nimbus-eth1 | `nimbus_eth1.sh` | Nim | Lightweight |
| Ethrex | `ethrex.sh` | Rust | Minimalist (Lambda Class) |

### Consensus Clients

| Client | Script | Language | Notes |
|--------|--------|----------|-------|
| Prysm | `prysm.sh` | Go | Default, well-documented |
| Lighthouse | `lighthouse.sh` | Rust | Security-focused |
| Teku | `teku.sh` | Java | Enterprise/monitoring |
| Nimbus | `nimbus.sh` | Nim | Lightweight |
| Lodestar | `lodestar.sh` | TypeScript | Developer-friendly |
| Grandine | `grandine.sh` | Rust | High-performance |

### MEV Solutions (Mutually Exclusive — choose ONE)

| Solution | Scripts | Port | Notes |
|----------|---------|------|-------|
| MEV-Boost | `install_mev_boost.sh` | 18550 | Recommended, stable |
| Commit-Boost | `install_commit_boost.sh` | 18550 (PBS, same port), 20000 (Signer) | Drop-in MEV-Boost replacement |
| ETHGas | `install_ethgas.sh` | 18552 | Add-on, requires Commit-Boost |

**Never install both MEV-Boost and Commit-Boost.** All MEV solutions install as native binaries — no Docker.

MEV integration in consensus clients: each client config includes a commented-out builder endpoint pointing to `http://$MEV_HOST:$MEV_PORT`. Users must explicitly enable the builder flag after MEV is running.

---

## Development Workflows

### Pre-Commit Checks (Run Before Every Push)

```bash
./scripts/pre-commit.sh
```

This runs locally: shellcheck validation, shebang checks, dependency validation, `run_1`/`run_2` structure checks, and common functions unit tests.

Manual equivalent:
```bash
# Shellcheck with project exclusions
find . -name "*.sh" -type f ! -path "./.git/*" \
    -exec shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 {} \;

# Syntax validation
find . -name "*.sh" -type f ! -path "./.git/*" -exec bash -n {} \;

# Lint-only tests
./test/run_tests.sh --lint-only

# Common functions unit tests
bash install/test/test_common_functions.sh
```

### CI/CD Pipelines

| Workflow | Triggers On | What It Does |
|----------|-------------|-------------|
| `ci.yml` | `*.sh`, Dockerfile, action changes | Docker integration tests, E2E matrix for all client combos |
| `shellcheck.yml` | `*.sh` changes | Shellcheck, shebang, executable, dependency, structure validation |
| `frontend.yml` | `frontend/**` changes | Bun install, TypeScript check, Jest tests, Next.js build |
| `security.yml` | Security-related changes | Security validation |
| `pr-checks.yml` | All PRs | General PR quality checks |

**Path filtering**: CI only runs on relevant file changes. Shell-only changes skip frontend CI; frontend-only changes skip Docker CI.

### Docker Testing

```bash
# Build test image locally
docker build -t eth-node-test -f test/Dockerfile .

# Run integration tests
docker run --rm eth-node-test /workspace/test/run_tests.sh --lint-only
docker run --rm -e USE_MOCKS=true eth-node-test bash /workspace/install/test/test_common_functions.sh

# E2E test (specific client combo)
E2E_EXECUTION=geth E2E_CONSENSUS=prysm E2E_MEV=mev-boost ./test/run_e2e.sh --phase=2
```

Always run `docker build` locally before pushing to catch build failures early.

### Frontend Development

```bash
cd frontend
bun install                # Install dependencies
bun run dev                # Start dev server
bun run build              # Production build
bun run test               # Run Jest tests (NOT bun test)
bun run test:coverage      # Coverage report
bunx tsc --noEmit          # TypeScript type check
```

Frontend CI uses `oven-sh/setup-bun@v2` action (not `setup-node`).

Stack: Next.js 14 (App Router), TypeScript, Tailwind CSS, Framer Motion, Jest + React Testing Library.

---

## Shell Scripting Standards

### Safety Settings

All scripts that source `exports.sh` inherit:
```bash
set -Eeuo pipefail
IFS=$'\n\t'
```

Scripts that don't source `exports.sh` must declare these themselves.

### Shellcheck Exclusions (with rationale)

| Code | Reason |
|------|--------|
| SC2317 | False positive unreachable code in test scripts |
| SC1091 | Not following source (relative paths) |
| SC1090 | Non-constant source (variable paths) |
| SC2034 | Unused variables in template scripts |
| SC2031 | Subshell variable modification (testing pattern) |
| SC2181 | `$?` check required for whiptail exit code capture |

### Key Gotchas

1. **`grep` in pipelines with `set -Eeuo pipefail`**: Always append `|| true` since `grep` exits 1 on no match, which kills the script.

   ```bash
   grep "pattern" file | process || true  # ✅
   ```

2. **Source paths**: Use `$PROJECT_ROOT`-anchored absolute paths, not relative paths, for `source` statements.

3. **`exec` redirect vs. command substitution**: `exec > >(tee -a "$LOG_FILE") 2>&1` captures ALL subsequent stdout. If you need `$(collect_something)`, do it BEFORE the `exec` redirect.

4. **`shift` in `for` loops**: Ineffective. Use a `while` loop or omit `shift` in `for arg in "$@"` loops.

5. **Whiptail pattern**: Must check `$?` separately after capturing output with `$()`.

6. **Generated scripts**: Escape `$()` in heredocs when you want runtime evaluation (`\$(pwd)`, not `$(pwd)`).

7. **Function arguments with `set -u`**: Always pass all required positional parameters; omitting them causes unbound variable errors that silently exit.

8. **Test output format**: Verify actual function output format before writing assertions. E.g., `ensure_jwt_secret` produces 64 hex chars with NO `0x` prefix.

### Error Handling Pattern

```bash
if ! some_function_call; then
    log_error "Descriptive error message"
    exit 1
fi
```

---

## Testing Framework

### Testing Hierarchy (preference order)

1. **Docker-based** (preferred for integration): Real system calls, isolated, no host risk
2. **Local with mocks**: Quick unit tests — `USE_MOCKS=true ./test/run_tests.sh`
3. **Lint-only**: CI/CD syntax and shellcheck — `./test/run_tests.sh --lint-only`

### Test Utilities (`test/lib/test_utils.sh`)

All test scripts should source this file:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test_utils.sh"
```

Provides: `record_test`, `print_test_summary`, `check_shellcheck`, `assert_file_exists`, `assert_command_exists`, `is_docker`, `is_root`, logging functions.

### Critical Testing Rules

- Each test file must be **self-contained** (source its own dependencies)
- Mocks must be sourced **before** code under test
- Separate bash processes don't inherit mocks — use `USE_MOCKS` env var
- Always verify actual exit codes, not just output

---

## Security Model

- **Firewall**: UFW with strict rules (configured in Phase 1)
- **Fail2ban**: Brute-force protection
- **SSH**: Key-only auth, non-standard port, root login disabled
- **Services**: Run as non-root user with minimal privileges
- **Secrets**: JWT secrets and sensitive data stored in `$HOME/secrets/`
- **Config permissions**: 600 for files, 700 for directories
- **Local binding**: All services bind to `127.0.0.1` by default
- **AIDE**: File integrity monitoring via `config/aide.conf`

This project handles **real ETH validator funds**. Never weaken the security model or skip privilege separation.

---

## MEV Implementation Rules

- All MEV solutions install as **native binaries** (git clone → build, or download → extract)
- **No Docker** for MEV solutions — the project doesn't use Docker for clients
- Port allocation: MEV-Boost=18550, Commit-Boost PBS=18550 (same, drop-in), Signer=20000, Metrics=10000+
- All MEV variables centralized in `exports.sh`
- Builder endpoints in consensus client configs default to **disabled** (`enable-builder: false`)
- Use `setup_firewall_rules()` for all MEV port rules
- Use `ensure_jwt_secret()` to verify JWT secrets exist before starting services
- **Commit-Boost binary mode**: requires `CB_CONFIG` env var in systemd service (not `--config` CLI flag)
- **Commit-Boost signer**: needs `[signer.local.loader]` config with validator keys before starting — install binary but don't start service by default
- **Commit-Boost TOML**: `[[relays]]` are top-level array-of-tables, `chain = "Mainnet"` at top level (not inside `[chain]` section)
- Always verify actual release asset URLs from GitHub API before hardcoding download patterns
- **Systemd `Environment=` placement**: `create_systemd_service()` doesn't support it — use `sudo sed -i '/^\[Service\]/a Environment="KEY=value"'` to insert into the correct section (not `tee -a` which appends after `[Install]`)
- **Drop-in replacement pattern**: mutually exclusive solutions that speak the same protocol should use the same port (e.g. Commit-Boost PBS uses `$MEV_PORT`) so client configs work unchanged

---

## One-Liner / Bootstrap Flow

```bash
curl -sSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/master/install.sh | bash
```

`install.sh` bootstraps before the repo exists (define colors locally, then clone, then source `common_functions.sh`). After cloning, it launches the TUI wizard (`install/utils/configure.sh` using whiptail) which generates phase scripts and saves user choices to `config/user_config.env`.

---

## Common Anti-Patterns to Avoid

| Anti-Pattern | Correct Approach |
|-------------|-----------------|
| `npm install` in frontend | `bun install` |
| Duplicate logging functions | Source `common_functions.sh` or `test_utils.sh` |
| Hardcoded colors in every script | Colors exported from `common_functions.sh` |
| Relative source paths | Use `$PROJECT_ROOT/...` absolute paths |
| `./run_1.sh && ./run_2.sh` | Mandatory reboot between phases |
| Docker for MEV services | Native binary installation |
| MEV-Boost + Commit-Boost both installed | Choose exactly ONE |
| Calling functions without required args | Check signature in `lib/common_functions.sh` first |
| `grep` without `|| true` in `set -e` scripts | Always add `|| true` to grep in pipelines |
| Duplicating `SHELLCHECK_EXCLUDES` | Use `check_shellcheck()` from `test_utils.sh` |

---

## Key Documentation Files

| File | Purpose |
|------|---------|
| `configs/AGENT_REFERENCE.md` | Config architecture quick reference |
| `docs/CONFIGURATION_GUIDE.md` | Full configuration architecture |
| `docs/COMMON_FUNCTIONS_REFERENCE.md` | All 35 functions with examples |
| `docs/MEV_GUIDE.md` | Complete MEV setup guide |
| `docs/SECURITY_GUIDE.md` | Security hardening details |
| `docs/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md` | Shell script standards |
| `docs/CI_WORKFLOWS.md` | When each CI workflow runs |
| `docs/CI_TROUBLESHOOTING.md` | CI debugging guide |
| `docs/COMMIT_MESSAGES.md` | Commit message examples |
| `docs/WORKFLOW.md` | End-to-end setup workflow |
| `docs/GLOSSARY.md` | Terminology definitions |
| `frontend/README.md` | Frontend quick-start with Bun |
| `.cursorrules` | Detailed agent rules (superset of this file) |
