# Multi-Pass Code Review Checklist

## Pass 1: Functionality ✓

### Build/Test/Lint
- [x] `./test/run_tests.sh --lint-only` - passes (254 tests)
- [x] `./test/validate_caddy_config.sh` - passes
- [x] `./test/validate_downloads.sh` - passes
- [x] `./install/utils/verify_client_configs.sh` - passes
- [x] CI: docker-integration, run-1-structure, run-1-e2e, run-2-structure, run-2-e2e, e2e-client-matrix, shellcheck

### Tests Not Stubbed
- [ ] run_2.sh E2E: Runs real install scripts (--execution, --consensus, --mev flags)
- [ ] Client matrix: 7 combos each install real clients
- [ ] Caddy/Nginx: Installed and verified in run-2-e2e main job (skipped in matrix to save time)

### Broken References
- [x] Source uses $SCRIPT_DIR or $PROJECT_ROOT
- [x] Function calls exist in common_functions.sh

## Pass 2: Architecture Compliance ✓

### Phase 1 / Phase 2 Boundary
- [x] run_1.sh: require_root, ends with reboot
- [x] run_2.sh: check_user $LOGIN_UNAME (non-root)
- [x] E2E: Phase 1 as root, Phase 2 as testuser

### Common Functions
- [x] Install scripts source lib/common_functions.sh
- [x] Uses run_install_script, ensure_jwt_secret, get_github_release_asset_url, etc.

### Frontend
- [x] N/A (shell/install focus)

## Pass 3: Code Quality ✓

### Duplication
- [x] run_1 E2E: exec ci_test_run_1_e2e.sh (single source)
- [x] test/lib/test_utils.sh for shared utilities

### Dead Code
- [x] No stubbed verification - all verify_installed use real checks
- [x] ci_test_run_1 validates run_1 must NOT call setup_intrusion_detection (consolidated handles it)

### Line Count Audit
- **Branch vs master: +3107 -1272 = +1835 net lines** (branch has MORE code)
- run_2.sh: 411 lines (master: 309) - added flag parsing, SCRIPT_DIR, --skip-deps
- run_1.sh: 61 lines (master: 93) - refactored: lockout check, reorder user/SSH, consolidated handles append_once/secure_config/setup_intrusion
- Files with net deletions: docs/validate_security_safe.sh (-43), run_1.sh (-32), install_dependencies.sh restructure
- **Note:** run_1.sh changes came from prior refactoring (consolidated_security, ci_test_run_1 expects no setup_intrusion_detection). Reverting run_1 to master would break ci_test_run_1.

## Co-Author Attribution

When AI-assisted changes are committed, include co-author in commit body:
```
Co-authored-by: Human Name <human@example.com>
```
Add via: `git commit -m "..." -m "Co-authored-by: Name <email>"`
