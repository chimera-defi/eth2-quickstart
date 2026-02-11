# Progress: run_1.sh Hardening Script Tuneup

## Branch: `claude/fix-run-one-script-ES0Sq`

## Changes Made

### 1. Restored `127.16.0.0/12` in firewall blocked networks (consolidated_security.sh)
- **Issue**: Previous agent removed `127.16.0.0/12` from the `private_networks` array, claiming it was a typo for `172.16.0.0/12`
- **Fix**: Restored `127.16.0.0/12` alongside `127.0.0.0/8` and `172.16.0.0/12` — all three are intentional per the original Erigon reference list
- **Removed**: Misleading comment "Note: 172.16.0.0/12 is already listed below; this was a typo"
- **Why**: The human author confirmed this was NOT a typo. The overlap with `127.0.0.0/8` is intentional defense-in-depth from the Erigon docs

### 2. Added sshd_config.d drop-in directory audit (lib/common_functions.sh)
- **Issue**: `configs/sshd_config` line 11 includes `/etc/ssh/sshd_config.d/*.conf` which can silently override hardened settings (HANDOFF Known Issue #2)
- **Fix**: Added audit step in `configure_ssh()` that warns if drop-in configs exist, listing each file by name
- **Why**: On Ubuntu 22.04+, distribution updates can place files in this directory that weaken hardening

### 3. Narrowed `secure_config_files()` scope (lib/common_functions.sh)
- **Issue**: Function did `find /etc -name "*.conf" -exec chmod 644` which set world-readable permissions on ALL config files in /etc, potentially weakening sensitive file permissions (shadow, DB configs, API keys)
- **Fix**: Removed the broad `find` sweep. Function now only sets permissions on known sensitive files (sshd_config: 600, sudoers: 440)
- **Why**: chmod 644 on arbitrary /etc configs is a security anti-pattern

### 4. Added deprecation comment on `setup_intrusion_detection()` (lib/common_functions.sh)
- **Issue**: Function is dead code — never called by `run_1.sh` (AIDE is handled by `consolidated_security.sh`'s `setup_aide()`)
- **Fix**: Added deprecation comment explaining it's superseded, retained for test/validation compatibility
- **Why**: Documents intent for future agents; prevents accidental re-introduction of duplicate AIDE setup

### 5. Added regression tests (test/ci_test_run_1.sh)
- **Test 21**: Verifies ALL three private network blocks are present: `127.0.0.0/8`, `127.16.0.0/12`, `172.16.0.0/12`
- **Test 22**: Verifies `secure_config_files()` does NOT do a broad `find /etc` permission sweep
- **Why**: Prevents future regressions on these specific issues

## Verification Results

### Pass 1: Build/Lint
- [x] `bash -n run_1.sh` — passes
- [x] `bash -n lib/common_functions.sh` — passes
- [x] `bash -n install/security/consolidated_security.sh` — passes
- [x] `bash -n test/ci_test_run_1.sh` — passes
- [x] `bash -n exports.sh` — passes
- [ ] `shellcheck` — not available in this environment (CI will run it)

### Pass 2: Architecture Compliance
- [x] `run_1.sh` uses `require_root`
- [x] User creation (line 38) happens BEFORE SSH hardening (line 44)
- [x] SSH config uses `configs/sshd_config` template, not inline
- [x] `set -Eeuo pipefail` at top of script (via exports.sh sourcing)
- [x] All paths use `$SCRIPT_DIR` or `$PROJECT_ROOT`, not relative
- [x] No `AllowUsers` directive in SSH config
- [x] `PermitRootLogin` is `prohibit-password`, not `no`
- [x] Root SSH keys are migrated to new user in `setup_secure_user()`
- [x] SSH config validated with `sshd -t` before applying
- [x] SSH service reloaded (not restarted) to preserve sessions
- [x] Both `127.0.0.0/8`, `127.16.0.0/12`, and `172.16.0.0/12` blocked in firewall

### Pass 3: Code Quality / No Regressions
- [x] No duplicate AIDE setup (only in `consolidated_security.sh`)
- [x] Sysctl changes use `/etc/sysctl.d/` drop-in file
- [x] Crontab additions check for existing entry before adding
- [x] fail2ban config uses write mode (`>`), not append (`>>`)
- [x] No unnecessary `sudo` in functions that require root
- [x] Dead code documented with deprecation comments
- [x] `generate_handoff_info` includes SSH port and writes file
- [x] `secure_config_files` no longer does broad /etc permission sweep
- [x] sshd_config.d drop-in directory audited during SSH configuration

## Additional Issues Flagged (Not Fixed — Out of Scope)

| Issue | Severity | Location | Notes |
|-------|----------|----------|-------|
| `safe_command_execution()` uses `eval` | Medium | common_functions.sh:965 | Dead code, not called by run_1.sh |
| `configure_sudo_nopasswd` grants ALL | Low | common_functions.sh:700 | Design decision, matches staking use case |
| Password in handoff_info.txt | Low | common_functions.sh:770 | Documented as sudo/console-only |
| sshd_config.d drop-ins could override | Medium | configs/sshd_config:11 | Now WARNED, not blocked (operator decision) |
| apt commands not idempotent on re-run | Low | run_1.sh:27-30 | Script designed for single Phase 1 run |

## Test Suite: 22 Tests

Tests 1-20: Unchanged from previous agent's work
Test 21: Verify 127 + 172 private network blocking (NEW)
Test 22: Verify secure_config_files scope (NEW)
