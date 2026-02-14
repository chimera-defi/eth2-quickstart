# Script Testing Framework

This directory contains tests for the Ethereum node setup scripts.

## Testing Approaches

### 1. Docker-Based Testing (Recommended)

Run tests inside an isolated Docker container with **real system calls** - no mocks needed.

**run_1 structure validation (from repo root):**
```bash
docker build -t eth-node-test -f test/Dockerfile . && docker run --rm --privileged --user root eth-node-test /workspace/test/ci_test_run_1.sh
```

**E2E (actually runs run_1.sh or run_2.sh - from repo root, requires Docker):**
```bash
./test/run_e2e.sh --phase=1   # run_1.sh (system setup)
./test/run_e2e.sh --phase=2   # run_2.sh (client installation)
```
Note: E2E requires Docker. Use `SKIP_BUILD=true` to reuse existing image (e.g. in CI).

```bash
# Build and run all tests in Docker
cd test
docker-compose up --build test

# Run only lint tests (fast, no privileged mode needed)
docker-compose up --build lint

# Run unit tests with real system calls
docker-compose up --build unit

# Or use docker directly
docker build -t eth-node-test -f test/Dockerfile .
docker run --privileged eth-node-test
```

**Benefits:**
- Real system calls (apt, systemctl, ufw) in isolated environment
- No risk to host system
- Tests the actual installation behavior
- Reproducible environment

### 2. Local Testing with Mocks (Quick Checks)

For quick syntax and lint checks without Docker:

```bash
# Lint only (shellcheck + syntax) - safe, no system changes
./test/run_tests.sh --lint-only

# Shellcheck only (run before push to match CI)
./test/run_shellcheck.sh

# Unit tests with mock functions (no real system calls)
USE_MOCKS=true ./test/run_tests.sh --unit
```

## Test Modes

| Mode | Command | System Calls | Use Case |
|------|---------|--------------|----------|
| Docker (full) | `docker-compose up test` | Real | Complete integration testing |
| Docker (lint) | `docker-compose up lint` | None | Quick CI checks |
| Local lint | `./run_tests.sh --lint-only` | None | Quick local checks |
| Local mocked | `USE_MOCKS=true ./run_tests.sh` | Mocked | Safe local testing |

## Directory Structure

```
test/
├── Dockerfile              # Container definition for isolated testing
├── docker-compose.yml      # Easy container management
├── docker_test.sh          # Test runner for Docker (real system calls)
├── run_tests.sh            # Test runner for local (supports mocks)
├── ci_test_run_1.sh        # run_1 structure validation
├── ci_test_run_2.sh        # run_2 structure validation only (Tests 1-7)
├── ci_test_e2e.sh          # E2E: executes run_1 or run_2, verifies results (PHASE=1|2)
├── run_e2e.sh              # Wrapper: Docker + systemd + ci_test_e2e.sh (--phase=1|2)
├── lib/
│   ├── mock_functions.sh   # Mock implementations for safe local testing
│   ├── test_utils.sh       # Shared test helpers (record_test, assert_*, etc.)
│   └── shellcheck_config.sh
├── results/                # Test output (gitignored)
└── README.md
```

## What Gets Tested

1. **Shellcheck** - Static analysis of all shell scripts
2. **Syntax** - Bash syntax validation
3. **Source paths** - Verify relative imports resolve correctly
4. **Function existence** - All required functions are defined
5. **Function behavior** - Unit tests for key functions
6. **System integration** - Real apt, ufw, systemctl calls (Docker only)
7. **Install script structure** - Proper shebang, sources, patterns
8. **E2E** - Executes run_1.sh (phase 1) or run_2.sh (phase 2) and verifies results

## CI Integration

GitHub Actions (`.github/workflows/ci.yml`) runs:

1. **Shellcheck** - Lints all shell scripts
2. **Docker Lint Tests** - Runs `run_tests.sh --lint-only` in container
3. **Docker Unit Tests** - Runs `docker_test.sh` with real system calls
4. **run_1.sh Structure** - Validates syntax, functions, SSH safety (no execution)
5. **run_1.sh E2E** - Runs run_1.sh and verifies results (systemd + openssh)
6. **run_2.sh Structure** - Validates structure, syntax, configs, client scripts
7. **run_2.sh E2E** - Runs run_2.sh and verifies all client installs (execution, consensus, MEV)

### CI Test Scripts

| Script | Purpose | User |
|--------|---------|------|
| `ci_test_run_1.sh` | Validates run_1.sh structure, syntax, functions, SSH safety | root |
| `ci_test_run_2.sh` | Validates run_2.sh structure, syntax, configs (Tests 1-7). Full E2E in ci_test_e2e.sh | testuser |
| `ci_test_e2e.sh` | Executes run_1 or run_2 and verifies results (PHASE=1|2) | root/testuser |

**Note**: Full E2E testing with systemd services and snap packages requires special Docker setup. CI tests validate structure and components that work in standard Docker.

### Running CI Tests Locally

```bash
# Build and run all CI tests
docker build -t eth-node-test -f test/Dockerfile .

# Test run_1.sh structure (as root)
docker run --rm --privileged --user root eth-node-test /workspace/test/ci_test_run_1.sh

# Test run_1.sh E2E
./test/run_e2e.sh --phase=1

# Test run_2.sh structure (as testuser)
docker run --rm --privileged eth-node-test /workspace/test/ci_test_run_2.sh

# Test run_2.sh E2E
./test/run_e2e.sh --phase=2
```

### Full End-to-End Testing

For complete E2E testing on a real server (not Docker):

```bash
# On a fresh Ubuntu 22.04 server:
sudo ./run_1.sh           # Phase 1: System setup (as root)
./run_2.sh                # Phase 2: Client installation (as LOGIN_UNAME user)
```

**Limitations in Docker**:
- `snap` packages (Go, certbot) don't work without special setup
- `systemd` services require privileged mode + systemd init
- Full E2E is best tested on actual VMs or servers

### E2E: Non-Interactive Setup

Phase 1 E2E executes `apt upgrade` which can pull in packages that prompt for configuration. To prevent hangs:

- **Dockerfile**: Pre-seeds debconf (postfix, cron, tzdata, needrestart)
- **ci_test_e2e.sh**: Re-applies debconf pre-seeds before running run_1.sh
- **CI**: 5min timeout for phase 1, 10min for phase 2

If E2E hangs, run locally with `./test/run_e2e.sh --phase=1` to debug.
