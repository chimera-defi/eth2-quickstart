# Ethereum Node Setup Script Testing Framework

This directory contains a comprehensive testing framework for validating the Ethereum node setup scripts safely without making changes to your local system.

## Quick Start

### Local Testing (No Docker Required)

```bash
# Run quick local tests with mocks (safe, no system changes)
./test/quick_test.sh
```

### Docker-Based Testing (Recommended)

```bash
# Lint check only (fastest)
./test/docker_test.sh lint

# Unit tests with mocks
./test/docker_test.sh unit

# Integration tests
./test/docker_test.sh integration

# Full test suite in isolated container
./test/docker_test.sh full

# Interactive debugging shell
./test/docker_test.sh debug
```

## Test Architecture

### Directory Structure

```
test/
├── Dockerfile.test          # Ubuntu-based test container
├── docker-compose.test.yml  # Multi-service test orchestration
├── docker_test.sh           # Docker test runner script
├── quick_test.sh            # Local test runner (no Docker)
├── run_tests.sh             # Main test harness
├── lib/
│   └── mock_functions.sh    # Mock functions for safe testing
├── results/                 # Test results (auto-created)
└── README.md                # This file
```

### Test Modes

| Mode | Description | Speed | Safety | Coverage |
|------|-------------|-------|--------|----------|
| `lint` | Shellcheck + syntax validation | ⚡ Fast | ✅ Safe | Basic |
| `unit` | Lint + function unit tests | ⚡ Fast | ✅ Safe | Functions |
| `integration` | Unit + script flow tests | 🔵 Medium | ✅ Safe (mocked) | Flows |
| `full` | All tests, real operations | 🔴 Slow | ⚠️ Isolated | Complete |

### Mock Functions

The mock function library (`lib/mock_functions.sh`) intercepts dangerous system calls:

- **Systemd operations**: `systemctl`, service creation
- **Package management**: `apt-get`, `apt`, repository additions
- **Firewall**: `ufw` commands
- **User management**: `useradd`, `usermod`, `chpasswd`
- **Network operations**: `wget`, `curl` (selective)
- **Security setup**: `fail2ban`, `aide`, SSH configuration

Mock calls are logged to `/tmp/mock_calls.log` for verification.

## Test Phases

### Phase 1: Lint and Static Analysis
- Shellcheck on all `.sh` files
- Bash syntax validation (`bash -n`)
- Shebang presence check

### Phase 2: Source File Verification
- `exports.sh` loads successfully
- All required variables are set
- `lib/common_functions.sh` loads successfully
- All 35+ functions are defined
- `lib/utils.sh` loads without conflicts

### Phase 3: Source Path Verification
- Relative paths resolve correctly from each script
- `../../exports.sh` and `../../lib/` patterns work

### Phase 4: Configuration Verification
- All client config files exist
- JSON configs are valid
- YAML configs pass basic checks

### Phase 5: Unit Tests
- Individual function tests
- `test_common_functions.sh` suite
- Validation functions
- Directory operations

### Phase 6: Integration Tests
- Script structure validation
- Flow testing with mocks
- Mock call verification

## Writing New Tests

### Adding Unit Tests

Add tests to `install/test/test_common_functions.sh`:

```bash
test_my_function() {
    local result
    result=$(my_function "arg1" "arg2")
    
    if [[ "$result" == "expected" ]]; then
        echo "  Test passed"
        return 0
    else
        echo "  ERROR: Expected 'expected', got '$result'"
        return 1
    fi
}
```

### Using Mocks in Tests

```bash
# Enable mocks
export USE_MOCKS=true
source test/lib/mock_functions.sh
apply_mocks

# Run your code (system calls are intercepted)
install_dependencies curl wget git

# Verify mock was called
if was_function_called "install_dependencies"; then
    echo "install_dependencies was called"
fi

# Get call count
echo "Called $(count_function_calls "install_dependencies") times"

# Print summary
print_mock_summary
```

## CI/CD Integration

The tests integrate with GitHub Actions via `.github/workflows/shellcheck.yml`:

```yaml
- name: Run tests
  run: |
    chmod +x test/run_tests.sh
    ./test/run_tests.sh --unit
```

## Troubleshooting

### Docker Issues

```bash
# Rebuild image from scratch
./test/docker_test.sh full --rebuild --no-cache

# Clean up Docker resources
./test/docker_test.sh clean
```

### Test Failures

1. Check `test/results/test_results_*.txt` for detailed output
2. Use debug mode: `./test/docker_test.sh debug`
3. Review mock calls: `cat /tmp/mock_calls.log`

### Common Issues

| Issue | Solution |
|-------|----------|
| `exports.sh not found` | Run from project root |
| `Permission denied` | `chmod +x test/*.sh` |
| `Docker not found` | Install Docker or use `quick_test.sh` |
| `shellcheck not found` | `apt-get install shellcheck` |

## Test Coverage Goals

- [ ] All 35+ common functions tested
- [ ] All execution client scripts validated
- [ ] All consensus client scripts validated
- [ ] All MEV scripts validated
- [ ] All security scripts validated
- [ ] All web server scripts validated
- [ ] Configuration merging tested
- [ ] Error handling paths verified
- [ ] Source path resolution verified

## Contributing

When adding new scripts or functions:

1. Add corresponding unit tests
2. Update mock functions if new system calls added
3. Run full test suite before committing
4. Ensure shellcheck compliance
