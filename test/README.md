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

GitHub Actions runs `./test/run_tests.sh --lint-only` for pull requests.

For full integration testing, use Docker locally or in CI with privileged mode.
