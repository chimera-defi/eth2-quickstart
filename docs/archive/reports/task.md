# Task: New User Authorised Keys Access

**Branch:** `cursor/new-user-authorised-keys-access-3e3b`

## Scope

1. **SSH key management**: run_1.sh works with sudo user, collects keys from root + SUDO_USER, migrates to new user
2. **Lockout prevention**: Backup authorized keys, copy to new user home
3. **Postfix/apt prompts**: Non-interactive install, debconf preseed, no postfix config screen
4. **AIDE**: Update DB before handoff
5. **Whiptail**: OK button works when run via curl | bash
6. **New user repo access**: Copy eth2-quickstart to new user home
7. **E2E test**: run_1 E2E passes (authorized_keys present)
8. **Idempotency**: JWT generation, client install order (consensus before execution)
9. **NTP/tzdata**: No prompts, use defaults (UTC)
10. **Logging**: run_1/run_2 log to disk, security validation debug output
11. **view_logs.sh**: Helper to view logs

## Success Criteria

- run_1.sh runs as root or sudo, migrates keys, no lockout
- run_2.sh non-interactive, no NTP prompts
- Prysm generates JWT; consensus before execution
- E2E tests pass
- Lint/shellcheck pass
