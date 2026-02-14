# Run Script E2E - Task List (from PR #77)

This document tracks the implementation of PR #77 "Client script issues" - script-relative path resolution and run_2.sh non-interactive mode for CI/Docker E2E testing.

## Summary of PR Changes

1. **Script-relative path resolution** - Replace `source ../../exports.sh` with `SCRIPT_DIR`/`PROJECT_ROOT` pattern so scripts work when run from any cwd (e.g. CI at `/workspace`)
2. **run_2.sh flag mode** - Add `--execution=`, `--consensus=`, `--mev=`, `--skip-deps` for non-interactive CI
3. **CI_E2E support** - `setup_firewall_rules()` skips UFW when `CI_E2E=true` (Docker lacks kernel modules)
4. **check_system_requirements()** - Never fails, only warns (allows CI with limited resources)
5. **run_install_script()** - New function for run_2.sh flag mode
6. **E2E test infrastructure** - `run_e2e.sh --phase=1|2`, `ci_test_e2e.sh` (full E2E), `ci_test_run_2.sh` (structure validation only)

## Implementation Rules (from user)

- **Preserve comments** - Do NOT delete comments that existed before (e.g. shellcheck source directives, sync notes)
- **Functionality first** - Get the behavior right, iterate on polish later

---

## Task List

### ✅ Completed

- [x] **T1**: Apply script-relative path resolution to all install scripts (consensus, execution, mev, security, ssl, web, utils, examples, templates)
- [x] **T2**: Update `lib/common_functions.sh` - add CI_E2E skip in setup_firewall_rules, run_install_script(), check_system_requirements() never-fail
- [x] **T3**: Add run_2.sh flag mode (--execution, --consensus, --mev, --skip-deps)
- [x] **T4**: Update test/lib/test_utils.sh - CLIENT_SCRIPTS, output_has_path_errors, script_loads_ok, assert_script_loads, log_subheader, TESTS_SKIPPED
- [x] **T5**: Update ci_test_run_2.sh - use CLIENT_SCRIPTS, expand config list, structure validation only
- [x] **T6**: Create run_e2e.sh (consolidated wrapper for phase 1 and 2)
- [x] **T7**: Create ci_test_e2e.sh (consolidated E2E for phase 1 and 2)
- [x] **T8**: Update docker_test.sh - path resolution tests, source pattern
- [x] **T9**: Update .github/workflows/ci.yml - split run_2 test, add E2E step
- [x] **T10**: Add .gitignore for config/user_config.env
- [x] **T11**: Update docs (COMMON_FUNCTIONS_REFERENCE, SCRIPTS)
- [x] **T12**: install_dependencies.sh - uses SCRIPT_DIR/../../ already (no change needed)
- [x] **T13**: Fix install scripts that use $SCRIPT_DIR for config paths - change to $PROJECT_ROOT
- [x] **T14**: configure.sh, doctor.sh, run_manifest.sh - left as-is (no path changes needed)
- [x] **T15**: optional_tools.sh, purge_ethereum_data.sh, refresh.sh, select_clients.sh, start.sh, stats.sh, update.sh, update_all.sh, update_git.sh - add PROJECT_ROOT pattern
- [x] **T16**: install/web - caddy_helpers.sh/nginx_helpers.sh source uses $SCRIPT_DIR
- [x] **T17**: install/security/caddy_harden.sh - sources $PROJECT_ROOT/install/web/caddy_helpers.sh

---

## Verification Checklist

- [ ] All install scripts load when run from /workspace (any cwd)
- [ ] run_2.sh --execution=geth --consensus=prysm --mev=mev-boost --skip-deps completes in Docker
- [ ] CI_E2E=true skips UFW in setup_firewall_rules
- [ ] check_system_requirements never exits non-zero
- [ ] config/user_config.env overrides LOGIN_UNAME for CI
- [ ] run_e2e.sh --phase=2 builds, starts container, runs E2E, cleans up
- [ ] Shellcheck passes on all modified scripts
