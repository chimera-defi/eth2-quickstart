# Script Testing Framework

This directory contains tests for the Ethereum node setup scripts.

## Testing Approaches

### 1. Docker-Based Testing (Recommended)

Run tests inside an isolated Docker container with **real system calls** - no mocks needed.

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
├── Dockerfile           # Container definition for isolated testing
├── docker-compose.yml   # Easy container management
├── docker_test.sh       # Test runner for Docker (real system calls)
├── run_tests.sh         # Test runner for local (supports mocks)
├── lib/
│   └── mock_functions.sh  # Mock implementations for safe local testing
├── results/             # Test output (gitignored)
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

## CI Integration

GitHub Actions (`.github/workflows/ci.yml`) runs:

1. **Shellcheck** - Lints all shell scripts
2. **Docker Lint Tests** - Runs `run_tests.sh --lint-only` in container
3. **Docker Unit Tests** - Runs `docker_test.sh` with real system calls
4. **run_1.sh Test** - Tests Phase 1 (system setup) end-to-end
5. **run_2.sh Test** - Tests Phase 2 (validates structure, skips long downloads)

### CI Test Scripts

| Script | Purpose | User |
|--------|---------|------|
| `ci_test_run_1.sh` | Tests run_1.sh (SSH, user setup, security) | root |
| `ci_test_run_2.sh` | Tests run_2.sh (validates structure, dependencies) | testuser |

### Running CI Tests Locally

```bash
# Build and run all CI tests
docker build -t eth-node-test -f test/Dockerfile .

# Test run_1.sh (as root)
docker run --rm --privileged --user root eth-node-test /workspace/test/ci_test_run_1.sh

# Test run_2.sh (as testuser)
docker run --rm --privileged eth-node-test /workspace/test/ci_test_run_2.sh
```

### Full End-to-End Testing

The CI runs full E2E testing which takes ~5-7 minutes total:
- Dependencies: ~1-2 min
- Geth (apt install): ~30s  
- Prysm (download): ~1-2 min
- MEV-Boost (build): ~2-3 min

To run the full E2E test locally:

```bash
# Build and run full E2E test
docker build -t eth-node-test -f test/Dockerfile .

# Test run_1.sh (system setup) + run_2.sh (client installation)
docker run --rm --privileged --user root eth-node-test bash -c "
  /workspace/test/ci_test_run_1.sh && \
  /workspace/test/ci_test_run_2.sh
"
```
