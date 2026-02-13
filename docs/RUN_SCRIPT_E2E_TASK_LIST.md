# Run Script E2E - Task List (from PR #77)

This document tracks the implementation of PR #77 "Client script issues" - script-relative path resolution and run_2.sh non-interactive mode for CI/Docker E2E testing.

## Summary of PR Changes

1. **Script-relative path resolution** - Replace `source ../../exports.sh` with `SCRIPT_DIR`/`PROJECT_ROOT` pattern so scripts work when run from any cwd (e.g. CI at `/workspace`)
2. **run_2.sh flag mode** - Add `--execution=`, `--consensus=`, `--mev=`, `--skip-deps` for non-interactive CI
3. **CI_E2E support** - `setup_firewall_rules()` skips UFW when `CI_E2E=true` (Docker lacks kernel modules)
4. **check_system_requirements()** - Never fails, only warns (allows CI with limited resources)
5. **run_install_script()** - New function for run_2.sh flag mode
6. **E2E test infrastructure** - `run_run_2_e2e.sh`, `ci_test_run_2_e2e.sh`, expanded `ci_test_run_2.sh`

## Implementation Rules (from user)

- **Preserve comments** - Do NOT delete comments that existed before (e.g. shellcheck source directives, sync notes)
- **Functionality first** - Get the behavior right, iterate on polish later

---

## Task List

### ✅ Completed / In Progress

- [x] **T1**: Apply script-relative path resolution to all install scripts (consensus, execution, mev, security, ssl, web, utils, examples, templates)
- [x] **T2**: Update `lib/common_functions.sh` - add CI_E2E skip in setup_firewall_rules, run_install_script(), check_system_requirements() never-fail
- [x] **T3**: Add run_2.sh flag mode (--execution, --consensus, --mev, --skip-deps) - **preserve sync comments**
- [x] **T4**: Update test/lib/test_utils.sh - CLIENT_SCRIPTS, output_has_path_errors, script_loads_ok, assert_script_loads, log_subheader, TESTS_SKIPPED - **preserve shellcheck comments**
- [x] **T5**: Update ci_test_run_2.sh - use CLIENT_SCRIPTS, expand config list, add Tests 8-11 - **preserve shellcheck comment**
- [x] **T6**: Create run_run_2_e2e.sh wrapper
- [x] **T7**: Create ci_test_run_2_e2e.sh E2E test
- [x] **T8**: Update docker_test.sh - path resolution tests, source pattern - **preserve shellcheck comment**
- [x] **T9**: Update .github/workflows/ci.yml - split run_2 test, add E2E step
- [x] **T10**: Add .gitignore for config/user_config.env
- [x] **T11**: Update docs (COMMON_FUNCTIONS_REFERENCE, SCRIPTS)
- [x] **T12**: install_dependencies.sh - uses SCRIPT_DIR/../../ already (no change needed)
- [x] **T13**: Fix install scripts that use $SCRIPT_DIR for config paths - change to $PROJECT_ROOT
- [x] **T14**: configure.sh, doctor.sh, run_manifest.sh - left as-is (no path changes needed)
- [x] **T15**: optional_tools.sh, purge_ethereum_data.sh, refresh.sh, select_clients.sh, start.sh, stats.sh, update.sh, update_all.sh, update_git.sh - add PROJECT_ROOT pattern
- [x] **T16**: install/web - caddy_helpers.sh/nginx_helpers.sh source uses $SCRIPT_DIR (fixed)
- [x] **T17**: install/security/caddy_harden.sh - sources $PROJECT_ROOT/install/web/caddy_helpers.sh

### Potential Issues Identified

1. **run_install_script path** - Uses `./"$script"` - requires run_2.sh to be invoked from project root. run_2.sh doesn't cd to PROJECT_ROOT. If user runs from elsewhere, it may fail. **Mitigation**: run_2.sh could add `cd "$(dirname "$0")/.."` or similar at start. Current run_2.sh uses `source ./exports.sh` so it already assumes cwd. Document this.

2. **install_dependencies.sh** - Uses `source "$SCRIPT_DIR/../../lib/common_functions.sh"` - SCRIPT_DIR is script's dir, so ../../ goes to project root. This is already script-relative. PR only changed comment. **No change needed** for path.

3. **Docker testuser vs LOGIN_UNAME** - Default LOGIN_UNAME=eth, Docker creates testuser. ci_test_run_2.sh creates config/user_config.env with `LOGIN_UNAME=$(whoami)`. exports.sh loads user_config.env. **Verified**: works.

4. **ci_test_run_2_e2e.sh** - Runs as testuser. Needs config/user_config.env. run_run_2_e2e.sh passes -e CI_E2E=true. ci_test_run_2_e2e.sh creates config/user_config.env before running run_2.sh. **Verified**: flow correct.

5. **eth1.service** - ci_test_run_2_e2e.sh checks for eth1.service. Geth install creates "eth1" service. **Verified**: matches.

6. **install/web scripts** - They source `./caddy_helpers.sh` or `./nginx_helpers.sh`. With `cd "$PROJECT_ROOT"` at start, ./ is project root. But caddy_helpers.sh is in install/web/. So ./caddy_helpers.sh would need to be from install/web/. The scripts are IN install/web/, so when they run, their dir is install/web. After `cd "$PROJECT_ROOT"`, cwd is project root. So ./caddy_helpers.sh would look for project_root/caddy_helpers.sh - WRONG. It should be install/web/caddy_helpers.sh. Let me check - install_caddy.sh has `source ./caddy_helpers.sh`. After cd PROJECT_ROOT, ./ is project root. So we need `source "$SCRIPT_DIR/caddy_helpers.sh"` or `source "$PROJECT_ROOT/install/web/caddy_helpers.sh"`. The PR doesn't change this - it only adds the SCRIPT_DIR/PROJECT_ROOT at top. So the scripts would do:
   ```
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
   cd "$PROJECT_ROOT" || exit 1
   source "$PROJECT_ROOT/exports.sh"
   source "$PROJECT_ROOT/lib/common_functions.sh"
   source ./caddy_helpers.sh   # BUG - ./ is PROJECT_ROOT, caddy_helpers is in install/web/
   ```
   So we need to fix: `source "$SCRIPT_DIR/caddy_helpers.sh"` or `source "$PROJECT_ROOT/install/web/caddy_helpers.sh"`. The PR has `source ./caddy_helpers.sh` - so the PR might have a bug. Let me check the PR diff again... The PR for install_caddy.sh shows:
   ```
   source ./caddy_helpers.sh
   ```
   So the PR keeps it. That would be wrong after cd PROJECT_ROOT. **Issue**: Need to fix caddy_helpers/nginx_helpers source to use SCRIPT_DIR or PROJECT_ROOT path.

7. **install/security/caddy_harden.sh** - sources `../web/caddy_helpers.sh`. From install/security/, ../web is install/web. After cd PROJECT_ROOT, ../web would be wrong. So we need `source "$PROJECT_ROOT/install/web/caddy_helpers.sh"` or similar.

8. **configs/ethrex** - PR adds configs/ethrex/ethrex_base.toml to ci_test_run_2. **Verified**: exists.

9. **run_2.sh run_install_script** - The function does `./"$script"`. So for "install/execution/geth.sh", it runs ./install/execution/geth.sh. That requires cwd to be project root. run_2.sh is typically run as `./run_2.sh` from project root. So we're good. But we should ensure run_2.sh does `cd` to its directory at start for robustness. Current run_2.sh: `source ./exports.sh` - if you're in /tmp and run /workspace/run_2.sh, ./exports.sh would be /tmp/exports.sh. So run_2.sh DOES require being run from project root. The configure.sh generated scripts cd to SCRIPT_DIR first. So we're OK for normal use. For CI, we run from /workspace. Good.

10. **install/utils/install_dependencies.sh** - It doesn't have PROJECT_ROOT. It uses SCRIPT_DIR/../../lib/common_functions.sh. SCRIPT_DIR=install/utils, so ../../ = project root. Good. But it doesn't source exports.sh - does it need to? It's for install deps. Let me check - it might need exports for something. Looking at the script... it just installs packages. Probably doesn't need exports. OK.

---

## Files to Modify (from PR)

| File | Changes |
|------|---------|
| install/consensus/*.sh | Path resolution, PROJECT_ROOT for configs |
| install/execution/*.sh | Path resolution, PROJECT_ROOT for configs |
| install/mev/*.sh | Path resolution |
| install/security/*.sh | Path resolution |
| install/ssl/*.sh | Path resolution |
| install/web/*.sh | Path resolution, fix caddy_helpers/nginx_helpers source |
| install/utils/*.sh | Path resolution |
| install/examples/*.sh | Path resolution |
| install/templates/*.sh | Path resolution |
| lib/common_functions.sh | CI_E2E, run_install_script, check_system_requirements |
| run_2.sh | Flag mode, preserve comments |
| test/*.sh | test_utils, ci_test_run_2, docker_test, new e2e scripts |
| .github/workflows/ci.yml | Split run_2, add E2E |
| .gitignore | config/user_config.env |
| docs/*.md | Reference updates |

---

## Verification Checklist

- [ ] All install scripts load when run from /workspace (any cwd)
- [ ] run_2.sh --execution=geth --consensus=prysm --mev=mev-boost --skip-deps completes in Docker
- [ ] CI_E2E=true skips UFW in setup_firewall_rules
- [ ] check_system_requirements never exits non-zero
- [ ] config/user_config.env overrides LOGIN_UNAME for CI
- [ ] run_run_2_e2e.sh builds, starts container, runs E2E, cleans up
- [ ] Shellcheck passes on all modified scripts
- [ ] No comment deletions (shellcheck, sync notes preserved)
