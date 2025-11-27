# Script Testing Framework

Run tests locally with mock functions for safe testing (no system changes).

## Quick Start

```bash
# Run all tests with mocks (safe, no system changes)
./test/run_tests.sh --unit

# Lint only (shellcheck + syntax)
./test/run_tests.sh --lint-only
```

## Test Modes

| Mode | Command | Description |
|------|---------|-------------|
| Lint | `--lint-only` | Shellcheck and syntax validation |
| Unit | `--unit` | Lint + function unit tests |

## Mock Functions

The `lib/mock_functions.sh` intercepts system calls for safe testing:
- Systemd operations (service creation, start/stop)
- Package management (apt-get, apt)
- Firewall commands (ufw)
- Network downloads (wget, curl)

Tests run with `USE_MOCKS=true` by default.

## CI Integration

Tests are also run via GitHub Actions (`.github/workflows/shellcheck.yml`).
