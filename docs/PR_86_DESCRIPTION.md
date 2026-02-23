# PR #86 Description

Copy the content below into the PR description at https://github.com/chimera-defi/eth2-quickstart/pull/86

---

Allow `run_1.sh` to be executed by sudo users and prevent SSH lockout by backing up and migrating all existing authorized keys to newly created users.

## Summary

- **run_1.sh** works with root or sudo; collects SSH keys from `/root/.ssh/authorized_keys` and `$SUDO_USER`'s `~/.ssh/authorized_keys`; migrates to new user
- **Lockout prevention**: Backup authorized keys, copy to new user home before hardening SSH
- **Non-interactive install**: debconf preseed, `DEBIAN_FRONTEND=noninteractive`, no postfix/tzdata prompts
- **AIDE**: Update DB before handoff
- **Whiptail**: OK button works when run via `curl | bash` (PR 85)
- **New user repo access**: Copy eth2-quickstart to new user home so handoff commands work
- **Logging**: run_1/run_2 log to disk; `view_logs.sh` helper; clearer security validation failure output
- **Idempotency**: Prysm generates JWT; consensus before execution; NTP/tzdata defaults
- **E2E**: Bake authorized_keys into test Dockerfile so run_1 E2E passes in CI

## Key Changes

| Area | Change |
|------|--------|
| `lib/common_functions.sh` | `require_sudo_or_root()`, `collect_and_backup_authorized_keys()`, `setup_secure_user()` accepts ssh_key_file |
| `run_1.sh` | sudo support, key collection, debconf, AIDE update, copy repo to new user |
| `run_2.sh` | Logging, consensus→execution order, JWT fallback, security validation debug |
| `test/Dockerfile` | Root authorized_keys for E2E |
| `install/utils/view_logs.sh` | New helper to view logs |

## Attribution

**AI-assisted by:** Composer (Cursor's AI coding assistant)
