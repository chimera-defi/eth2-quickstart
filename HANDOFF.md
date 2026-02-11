# Handoff: Hardening Script Fix

## Branch: `claude/fix-hardening-script-4Z4GC`

## What Was Done

Fixed the root cause of admin lockout in the Phase 1 hardening script and refactored
to remove duplicate code. Two commits on this branch.

### Root Cause of Lockout

The old `configure_ssh()` in `lib/common_functions.sh` wrote an inline SSH config with:
- `AllowUsers $LOGIN_UNAME` — restricted SSH to only the new user, blocking root
- `PermitRootLogin no` — completely blocked root (should be `prohibit-password`)
- No SSH key migration from root to the new user
- User creation happened AFTER SSH hardening in `run_1.sh`
- `systemctl restart sshd` — wrong service name on Ubuntu 22.04+ (it's `ssh`)

After reboot: root blocked, new user has no keys, system irrecoverable.

### Files Modified

| File | Changes |
|------|---------|
| `run_1.sh` | Reordered user-before-SSH, removed duplicate AIDE call, consolidated handoff, added `set -Eeuo pipefail` and `SCRIPT_DIR` |
| `lib/common_functions.sh` | Rewrote `configure_ssh()` (template-based, `sshd -t`, reload, ssh/sshd detection, backup/restore), rewrote `setup_secure_user()` (key migration), consolidated `generate_handoff_info()` (port-aware, writes file), fixed idempotency (sysctl.d, crontab grep), added `get_ssh_service_name()`, added sudoers validation |
| `install/security/consolidated_security.sh` | Fixed `127.16.0.0/12` typo, dynamic SSH port in firewall, idempotent fail2ban/AIDE crontab, `SCRIPT_DIR` sourcing instead of `../../` |
| `configs/sshd_config` | Removed deprecated `ChallengeResponseAuthentication` |
| `test/ci_test_run_1.sh` | Added 12 new tests (9-20): lockout prevention, template usage, key migration, ordering, idempotency, no duplicates, path resolution, port handling |

### Code Reduction

- Removed duplicate AIDE setup (`run_1.sh` called both `consolidated_security.sh` which runs `setup_aide()` AND `setup_intrusion_detection()` — same job twice)
- Consolidated handoff: `generate_handoff_info()` now handles both console display and file write (was duplicated inline in `run_1.sh`)
- Removed inline SSH config blob from `configure_ssh()` (replaced with template reference)
- Removed duplicate SSH status display lines from `run_1.sh`

## Security Invariants (MUST be preserved)

These are the safety properties that prevent lockout. Tests 9-20 in `ci_test_run_1.sh` enforce them:

1. **No `AllowUsers` in `configs/sshd_config`** — would lock out root before key migration (Test 10)
2. **`PermitRootLogin prohibit-password`** — root can log in with keys only, never `no` (Test 10)
3. **`configure_ssh()` uses `configs/sshd_config` template** — not an inline config blob (Test 11)
4. **`configure_ssh()` validates with `sshd -t`** — before applying, restores backup on failure (Test 12)
5. **`get_ssh_service_name()` detects `ssh` vs `sshd`** — correct service name (Test 13)
6. **`setup_secure_user()` migrates root SSH keys** — copies `/root/.ssh/authorized_keys` to new user (Test 14)
7. **User created BEFORE SSH hardened** — in `run_1.sh` ordering (Test 15)
8. **No duplicate AIDE setup** — `consolidated_security.sh` handles it, not `run_1.sh` (Test 18)
9. **`consolidated_security.sh` uses `SCRIPT_DIR`** — not fragile `../../` relative paths (Test 19)
10. **`generate_handoff_info` includes SSH port** — correct SSH command in output (Test 20)

## Verification Commands

```bash
# Syntax check
bash -n run_1.sh && bash -n lib/common_functions.sh && bash -n install/security/consolidated_security.sh

# Shellcheck
shellcheck -x --exclude="SC2317,SC1091,SC1090,SC2034,SC2031,SC2181" \
  run_1.sh lib/common_functions.sh install/security/consolidated_security.sh

# Run 20-test CI suite (requires root)
bash test/ci_test_run_1.sh

# Quick invariant check
grep "^AllowUsers" configs/sshd_config        # Should return nothing
grep "^PermitRootLogin" configs/sshd_config    # Should say "prohibit-password"
```

## Known Issues for Next Agent

### 1. `PasswordAuthentication no` vs Password in Handoff (Needs Decision)

`configs/sshd_config:66` disables password auth. But `run_1.sh` generates a password and shows
it in the handoff. Since SSH key migration covers login, the password is only useful for sudo
(which has NOPASSWD) or console access. The handoff text now says "Password is for sudo/console
access only" but the operator may still be confused.

**Options:**
- Keep as-is (secure, text is clear enough)
- Set `PasswordAuthentication yes` in Phase 1, disable in Phase 2 after confirming key access

### 2. `configs/sshd_config` Include Directive (Low Risk)

Line 11: `Include /etc/ssh/sshd_config.d/*.conf` could override hardened settings via drop-in
files. Fine on fresh servers, but on servers with existing drop-ins the hardening could be
silently overridden. Consider auditing/clearing that directory.

### 3. `docker-compose.yml` Missing Root Service (Low Priority)

No compose service runs as root for Phase 1 tests. `ci.yml` handles this with `--user root`,
but `docker compose up` has no equivalent. Could add a `phase1` service.

### 4. `docker-compose.yml` Deprecated Version Key (Cosmetic)

`version: '3.8'` is deprecated in modern Docker Compose. Can be removed.

### 5. `setup_intrusion_detection()` Still Exists in common_functions.sh

The function definition is kept for potential standalone use or backward compatibility with
docs/validation scripts. It's no longer called by `run_1.sh` (AIDE is handled by
`consolidated_security.sh`'s `setup_aide()`). Could be removed if no external callers need it,
but would require updating `test/run_tests.sh:273`, `test/lib/mock_functions.sh`,
`docs/validate_security_safe.sh`, and `docs/COMMON_FUNCTIONS_REFERENCE.md`.

## Multi-Pass Review Checklist

For any future changes to run_1.sh or its dependencies:

### Pass 1: Build/Test/Lint
- [ ] `bash -n` on all modified `.sh` files
- [ ] `shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181` passes
- [ ] `bash test/ci_test_run_1.sh` — all 20 tests pass
- [ ] No syntax errors introduced in any project `.sh` file

### Pass 2: Architecture Compliance
- [ ] run_1.sh runs as root (uses `require_root`)
- [ ] User creation happens BEFORE SSH hardening
- [ ] SSH config uses `configs/sshd_config` template, not inline
- [ ] `set -Eeuo pipefail` at top of script
- [ ] All paths use `$SCRIPT_DIR` or `$PROJECT_ROOT`, not relative `./`
- [ ] No `AllowUsers` directive anywhere in SSH config
- [ ] `PermitRootLogin` is `prohibit-password`, never `no`
- [ ] Root SSH keys are migrated to new user
- [ ] SSH config validated with `sshd -t` before applying
- [ ] SSH service reloaded (not restarted) to preserve sessions

### Pass 3: Code Quality / No Regressions
- [ ] No duplicate functionality (AIDE only in consolidated_security.sh)
- [ ] All sysctl changes in `/etc/sysctl.d/` drop-in, not appending to `sysctl.conf`
- [ ] All crontab additions check for existing entry before adding
- [ ] fail2ban config uses write mode (`>`), not append (`>>`)
- [ ] No unnecessary `sudo` in functions that require root
- [ ] No dead code or unused variables
- [ ] No hallucinated function names or file paths
- [ ] `generate_handoff_info` includes SSH port and writes file
