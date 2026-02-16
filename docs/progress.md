# Progress: New User Authorised Keys Access

**Branch:** `cursor/new-user-authorised-keys-access-3e3b`  
**Last updated:** 2026-02-16

## Completed

| Item | Status | Commit |
|------|--------|--------|
| run_1.sh works with sudo, collects keys | Done | fa58659 |
| Postfix/apt non-interactive | Done | 44e2d3a, bf3f3f4 |
| AIDE update before handoff | Done | bf3f3f4 |
| Whiptail OK button (curl \| bash) | Done | 5192486, cfb1c73 |
| Copy eth2-quickstart to new user | Done | e8eaa29 |
| install_phase1.sh works as sudo | Done | b8bbe2a |
| E2E: authorized_keys in run_1 | Done | f3ce05d |
| Shellcheck CI fixes | Done | 0fb46eb |
| Idempotency (JWT, client order) | Done | 0372f0f, 99168b2 |
| NTP/tzdata defaults | Done | e4b14ea, 7750d9d |
| Logging to disk | Done | e0d2bd8 |
| view_logs.sh helper | Done | d879d6a |
| Security validation debug output | Done | e0d2bd8 |
| Naming consistency (run_1.sh/run_2.sh) | Done | 42ecca9 |

## Multi-Pass Review Status (2026-02-16)

| Pass | Status | Notes |
|------|--------|-------|
| Pass 1: Functionality | Done | 258 lint tests pass, syntax valid, shellcheck key files pass |
| Pass 2: Architecture | Done | run_1 require_sudo_or_root→reboot; run_2 check_user non-root; consensus before execution |
| Pass 3: Code quality | Done | JWT: Prysm native + ensure_jwt fallback; no duplicate logic; E2E always writes authorized_keys |

## Regressions to Watch

- JWT: Prysm must generate; consensus before execution
- E2E: /root/.ssh/authorized_keys must exist before run_1 (baked into test/Dockerfile + ci_test_run_1_e2e.sh)
- Phase 2: Must run as non-root (LOGIN_UNAME)

## Verification Commands (run before push)

```bash
./test/run_tests.sh --lint-only
find . -name "*.sh" -type f ! -path "./.git/*" -exec bash -n {} \;
find . -name "*.sh" -type f ! -path "./.git/*" -exec shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 {} \;
./install/utils/verify_client_configs.sh
bash install/test/test_common_functions.sh
```
