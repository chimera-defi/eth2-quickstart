# Agent Handoff

Use this file to preserve context across sessions.

## Active Defaults
- Start new work from latest `origin/master`.
- Preserve valuable uncommitted work before syncing (stash or branch).
- Use a fresh branch + fresh PR for each new task.

## Latest Update (Batteries-included Caddy guardrails pass, 2026-04-20)

- Upgraded Caddy install behavior to make edge guardrails batteries-included by default:
  - `install/web/caddy_helpers.sh` now bootstraps required Caddy modules during `install_caddy`:
    - `http.handlers.rate_limit`
    - `dns.providers.cloudflare`
  - bootstrap flow:
    - detect missing required modules from `caddy list-modules`
    - download a custom Caddy binary from Caddy download API with required plugin packages
    - install binary to `/usr/bin/caddy` and verify required modules are present
  - install now fails fast if module bootstrap is enabled but cannot be completed (explicit secure-by-default behavior).
- Added explicit module bootstrap knobs:
  - `exports.sh`:
    - `CADDY_ENSURE_MODULES='true'`
    - `CADDY_REQUIRED_MODULES='http.handlers.rate_limit,dns.providers.cloudflare'`
    - `CADDY_REQUIRED_PACKAGES='github.com/mholt/caddy-ratelimit,github.com/caddy-dns/cloudflare'`
  - `config/user_config.env.example` now documents overrides for all three.
- Updated docs to reflect batteries-included defaults:
  - `README.md`
  - `docs/CADDY_INSTALLATION.md`
- Expanded review guardrails to assert module-bootstrap defaults remain wired:
  - `test/validate_review_guardrails.sh`

- Quality gate outcomes:
  - Security audit:
    - `bash install/security/test_security_fixes.sh` (from local dev workspace) -> partial/expected host failures because this host is not a provisioned run_1 target (`/usr/local/bin/security_monitor.sh`, root cron entries, logrotate config absent).
    - Residual risk: local workspace audit cannot validate host-level security artifacts without a provisioned target.
    - Mitigation: full phase-2 E2E (below) validates installer behavior in containerized target context, including Caddy/Nginx hardening path.
  - Code/dead-code review:
    - manual multi-pass review of changed scripts/docs (`install/web/caddy_helpers.sh`, `exports.sh`, docs/tests) to remove incorrect module/package coupling and ensure explicit checks.
  - Regression review:
    - `bash -n install/web/caddy_helpers.sh test/validate_review_guardrails.sh exports.sh`
    - `shellcheck -x -e SC1091 install/web/caddy_helpers.sh test/validate_review_guardrails.sh`
    - `bash test/validate_review_guardrails.sh`
    - `bash test/validate_proxy_policy_toggles.sh`
    - `bash test/validate_caddy_config.sh`
    - `bash test/validate_nginx_config.sh`
    - `./test/run_e2e.sh --phase=2` -> `Total tests: 29, Passed: 29, Failed: 0`

- Bug found/fixed during this pass:
  - initial module bootstrap attempt used module IDs as download API package parameters, causing `curl ... error: 400` in E2E.
  - fixed by separating:
    - required module IDs (`CADDY_REQUIRED_MODULES`) for validation
    - package import paths (`CADDY_REQUIRED_PACKAGES`) for API download.

## Latest Update (Rate-limit dedupe + guardrail hooks pass, 2026-04-20)

- Tightened Nginx/Caddy parity with deeper dedupe in shared renderer:
  - `install/web/proxy_config_renderer.sh` now centralizes shared anti-abuse thresholds:
    - `EDGE_RPC_RATE_LIMIT_RPM`
    - `EDGE_WS_RATE_LIMIT_RPM`
    - `EDGE_GENERAL_RATE_LIMIT_RPM`
    - `EDGE_RPC_BURST`
    - `EDGE_WS_BURST`
    - `EDGE_RPC_CONN_LIMIT_PER_IP`
    - `EDGE_WS_CONN_LIMIT_PER_IP`
  - same shared values now render into both Nginx + Caddy policies.
  - added positive-integer input validation for these fields (fail-fast on invalid overrides).
  - `config/edge_policy.env` now uses `VAR="${VAR:-default}"` semantics so user/config/CI overrides are respected instead of being overwritten.
- Propagated config/docs for new shared policy knobs:
  - `config/edge_policy.env`
  - `exports.sh`
  - `config/user_config.env.example`
  - `README.md`
  - `docs/CADDY_INSTALLATION.md`
- Fixed stale security-audit logic:
  - `install/security/test_security_fixes.sh` network exposure check now excludes intentional SSH binding file (`configs/sshd_config`).
  - rate-limit check now understands shared Nginx edge policy path (`/etc/nginx/conf.d/eth2-edge-policy.conf`) and skips cleanly when policy is not installed on the host.
- Added explicit future guardrails:
  - new `test/validate_review_guardrails.sh` verifies mandatory quality-gate docs + CI wiring for parity/security validators.
  - wired into:
    - `test/ci_test_run_2.sh` (new Test 16),
    - `test/docker_test.sh` (recorded test gate).
  - `test/validate_proxy_policy_toggles.sh` gained a dedicated case to assert shared anti-abuse values render into both Nginx + Caddy outputs.
- Validation run (this pass):
  - `bash -n install/web/proxy_config_renderer.sh install/security/test_security_fixes.sh test/ci_test_run_2.sh test/docker_test.sh test/validate_review_guardrails.sh config/edge_policy.env exports.sh`
  - `shellcheck -x -e SC1091 install/web/proxy_config_renderer.sh install/security/test_security_fixes.sh test/ci_test_run_2.sh test/docker_test.sh test/validate_review_guardrails.sh exports.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_caddy_config.sh`
  - `bash test/validate_nginx_config.sh`
  - `bash test/validate_review_guardrails.sh`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test /workspace/test/ci_test_run_2.sh`
  - `./test/run_e2e.sh --phase=2` -> `Total tests: 29, Passed: 29, Failed: 0`

## Latest Update (Security/regression audit gate + cleanup pass, 2026-04-20)

- Added persistent completion criteria to `AGENTS.md`:
  - every handoff/PR must include security audit, code/dead-code review, and regression review;
  - if anything cannot run locally, document skipped checks + residual risk;
  - always record executed commands and outcomes in this handoff file.
- Multi-pass local audit run completed on current edge-policy changes:
  - `bash -n exports.sh install/web/caddy_helpers.sh install/web/proxy_config_renderer.sh test/ci_test_run_2.sh test/docker_test.sh test/validate_caddy_config.sh test/validate_proxy_policy_toggles.sh test/validate_nginx_config.sh`
  - `shellcheck -x -e SC1091 test/validate_caddy_config.sh install/web/proxy_config_renderer.sh install/web/caddy_helpers.sh test/validate_nginx_config.sh test/validate_proxy_policy_toggles.sh test/ci_test_run_2.sh test/docker_test.sh exports.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_caddy_config.sh`
  - `bash test/validate_nginx_config.sh`
  - `./test/run_e2e.sh --phase=2` -> `Total tests: 29, Passed: 29, Failed: 0`
- Cleanup/refinement:
  - `test/validate_caddy_config.sh` now handles `caddy adapt` / `caddy validate` failures explicitly and returns cleanly for fallback/error handling.
- Status:
  - static checks clean;
  - shared-policy regression checks passing;
  - full `./test/run_e2e.sh --phase=2` rerun passed locally (`29/29`).

## Latest Update (Strict-mode parity pass + local multi-pass revalidation, 2026-04-20)

- Completed another end-to-end parity pass for shared Nginx/Caddy edge config and docs.
- Added explicit strict-mode regression coverage for Caddy optional features:
  - `test/validate_proxy_policy_toggles.sh` now asserts render failure when:
    - `CADDY_REQUIRE_RATE_LIMIT=true` with rate limiting disabled
    - `CADDY_REQUIRE_DNS_CHALLENGE=true` with DNS challenge disabled
- Extended run_2 structure validation:
  - `test/ci_test_run_2.sh` now runs `test/validate_caddy_config.sh` (new Test 15) in addition to Nginx validation.
- Smoothed Caddy validator behavior in non-root CI/container runs:
  - `test/validate_caddy_config.sh` now formats with user-level `caddy fmt --overwrite` and uses sudo only for adapt/validate when available.
  - `install/web/caddy_helpers.sh` avoids forced overwrite-format for `/tmp/*` outputs to reduce temp-file permission edge cases.
- Documentation parity cleanup:
  - `docs/CADDY_INSTALLATION.md`: corrected module-dependent rate-limit behavior, DNS-challenge wording, env var docs, and validation guidance.
  - `README.md`: corrected Caddy vs Nginx rate-limit comparison and capability wording.
- Local validation run (this pass):
  - `shellcheck -e SC1091 install/web/proxy_config_renderer.sh install/web/caddy_helpers.sh test/validate_proxy_policy_toggles.sh test/validate_caddy_config.sh test/validate_nginx_config.sh test/ci_test_run_2.sh exports.sh`
  - `bash -n install/web/proxy_config_renderer.sh install/web/caddy_helpers.sh test/validate_proxy_policy_toggles.sh test/validate_caddy_config.sh test/validate_nginx_config.sh test/ci_test_run_2.sh exports.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_caddy_config.sh`
  - `bash test/validate_nginx_config.sh`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test /workspace/test/validate_caddy_config.sh`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test /workspace/test/ci_test_run_2.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace -e USE_MOCKS=false -e CI=true -e SKIP_SHELLCHECK=true eth-node-test /workspace/test/docker_test.sh`
  - `./test/run_e2e.sh --phase=2` -> `Total tests: 29, Passed: 29, Failed: 0`
- Outcome:
  - Shared policy remains in sync across Nginx/Caddy.
  - Native config validators run locally and in CI paths.
  - Strict fail-fast toggles are now tested, not just implemented.

## Latest Update (Multi-pass Caddy/Nginx validator hardening + non-root run_2 parity, 2026-04-19)

- Completed a full multi-pass review of shared edge policy + validator wiring.
- Found and fixed a production Caddy validity gap:
  - stock Caddy does not include optional `dns.providers.cloudflare`/`http.handlers.rate_limit` modules.
  - `install/web/proxy_config_renderer.sh` now auto-gates those directives based on installed modules and token presence.
  - default render now stays valid on stock Caddy while still enabling optional features when modules exist.
- Strengthened Caddy validation path:
  - `test/validate_caddy_config.sh` now validates both `CI_E2E` and standard render modes.
  - `install/web/caddy_helpers.sh::validate_caddy_config` now runs `caddy fmt` + `caddy adapt` + `caddy validate`.
- Added/iterated Nginx renderer validation:
  - new `test/validate_nginx_config.sh` validates generated config with `nginx -t` (or Docker fallback).
  - hardened for non-root use by remapping cache/log paths, pid path, and listen port in validator-only temp config.
  - wired into `test/ci_test_run_2.sh` (Test 14) and `test/docker_test.sh`.
- CI workflow clarity:
  - `.github/workflows/ci.yml` comments updated to reflect that phase-2 still exercises Caddy/Nginx install+validation.
- Local validation run (this pass):
  - `shellcheck -x --exclude=SC1091,SC2034 install/web/caddy_helpers.sh install/web/proxy_config_renderer.sh test/validate_caddy_config.sh test/validate_nginx_config.sh test/validate_proxy_policy_sync.sh test/validate_proxy_policy_toggles.sh test/ci_test_run_2.sh test/docker_test.sh`
  - `bash test/validate_caddy_config.sh`
  - `bash test/validate_nginx_config.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - non-root parity check in temp writable copy:
    - `sudo -u eth2test ... bash test/ci_test_run_2.sh` -> pass
- Environment note:
  - Installed native Caddy for local validator parity (`caddy v2.11.2`) using repo’s package source path.

## Latest Update (CI run-2 fix: /workspace ownership for testuser, 2026-04-19)

- New CI failures after `c3dc625`:
  - `run-2-e2e` and `run-2-web` failed with:
    - `mkdir: cannot create directory '/workspace/logs': Permission denied`
- Root cause:
  - `COPY --chown=testuser:testuser . /workspace/` set ownership for copied contents,
    but `/workspace` itself (created by `WORKDIR`) remained `root:root`.
  - `run_2.sh` (executed as `testuser`) needs to create `/workspace/logs` in clean CI images.
- Fix:
  - `test/Dockerfile`: add non-recursive top-level ownership correction:
    - `RUN chown testuser:testuser /workspace`
  - keeps prior recursive-`chown -R` removal (performance win) while restoring write safety.
- Local validation after fix:
  - `docker build -f test/Dockerfile -t eth-node-test-local .`
  - `docker run --rm --entrypoint bash eth-node-test-local -lc 'id && stat -c "%U:%G %a %n" /workspace && mkdir -p /workspace/logs && stat -c "%U:%G %a %n" /workspace/logs'`
  - `GITHUB_TOKEN="$(gh auth token)" E2E_IMAGE_NAME=eth-node-test-local SKIP_BUILD=true E2E_EXECUTION=geth E2E_CONSENSUS=prysm E2E_MEV=mev-boost ./test/run_e2e.sh --phase=2` -> `29/29`
  - `GITHUB_TOKEN="$(gh auth token)" E2E_IMAGE_NAME=eth-node-test-local SKIP_BUILD=true ./test/run_e2e.sh --phase=2` -> `29/29`

## Latest Update (CI shellcheck fix + fresh-image multi-pass rerun, 2026-04-19)

- Root cause of new CI failure was non-functional lint-only regression:
  - `shellcheck-extended` flagged `SC2016` in `test/ci_test_run_2.sh` (`Test 13` grep patterns).
- Fix:
  - switched the two backup-path assertions in `Test 13` from single-quoted regex to fixed-string `grep -Fq` checks.
  - behavior preserved: still enforces `/etc/nginx/backups` strategy and rejects legacy wildcard restore patterns.
- Fresh local validation (post-fix):
  - exact CI-style shellcheck sweep over all `.sh` files (pass)
  - `bash test/validate_proxy_policy_sync.sh` (pass)
  - `bash test/validate_proxy_policy_toggles.sh` (pass)
  - `bash test/validate_caddy_config.sh` (pass)
  - `docker run ... eth-node-test-local /workspace/test/ci_test_run_2.sh` (pass, includes new `Test 13`)
  - rebuilt image from current HEAD: `docker build -f test/Dockerfile -t eth-node-test-local .`
  - fresh-image E2E:
    - `... ./test/run_e2e.sh --phase=1` -> `18/18`
    - `... ./test/run_e2e.sh --phase=2` -> `29/29`
- Outcome:
  - Caddy/Nginx shared-policy parity checks remain green.
  - CI-only miss explained by lint rule coverage mismatch in local quick pass, now corrected and revalidated.

## Latest Update (Multi-pass CI/local parity review + Docker E2E image hardening, 2026-04-19)

- Performed a second-pass audit focused on Nginx/Caddy parity + CI/local drift:
  - confirmed shared renderer still drives both stacks:
    - `install/web/proxy_config_renderer.sh`
    - `install/web/nginx_helpers.sh`
    - `install/web/caddy_helpers.sh`
  - confirmed historical CI failures (`run-2-e2e`, `run-2-web`) on old head are now green on current head.
- Found and fixed a local/CI reproducibility bottleneck in test image build:
  - `test/Dockerfile` no longer uses recursive `chown -R /workspace` step.
  - now uses `COPY --chown=testuser:testuser` with early user creation.
  - preserved sudo safety by configuring only `testuser` entries in `/etc/sudoers.d` **after** package install (keeps root sudo policy intact).
- Added regression guard for the Nginx backup/include collision class:
  - `test/ci_test_run_2.sh` new `Test 13` enforces backup paths under `/etc/nginx/backups` and blocks wildcard restore regressions.
- Validation run:
  - `bash -n install/web/proxy_config_renderer.sh install/web/nginx_helpers.sh install/web/caddy_helpers.sh install/security/nginx_harden.sh install/security/caddy_harden.sh install/web/install_caddy.sh install/web/install_nginx.sh test/run_e2e.sh test/ci_test_e2e.sh`
  - `shellcheck -x --exclude=SC1091,SC2034 install/web/proxy_config_renderer.sh install/web/nginx_helpers.sh install/web/caddy_helpers.sh install/security/nginx_harden.sh install/security/caddy_harden.sh install/web/install_caddy.sh install/web/install_nginx.sh test/run_e2e.sh test/ci_test_e2e.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_caddy_config.sh`
  - `E2E_IMAGE_NAME=eth-node-test-local SKIP_BUILD=true E2E_EXECUTION=geth E2E_CONSENSUS=prysm E2E_MEV=mev-boost ./test/run_e2e.sh --phase=2`
  - `E2E_IMAGE_NAME=eth-node-test-local SKIP_BUILD=true ./test/run_e2e.sh --phase=2`
  - `E2E_IMAGE_NAME=eth-node-test-local SKIP_BUILD=true ./test/run_e2e.sh --phase=1`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test-local /workspace/test/ci_test_run_2.sh`
- Follow-up:
  - optional future optimization: add safe `.dockerignore` strategy for local build context size, but only after confirming no tests depend on `.git` presence in-image.

## Latest Update (CI fix: Nginx hardening backup include collision, 2026-04-19)

- Fixed failing PR #170 jobs `run-2-e2e` / `run-2-web` root cause in Nginx hardening:
  - `install/security/nginx_harden.sh` previously wrote backups to `/etc/nginx/sites-enabled/default.backup.*`
  - those files can be glob-included by Nginx config loading, creating duplicate `upstream ws_backend` definitions during `nginx -t`
- Change:
  - moved backup outputs to `/etc/nginx/backups`
  - added explicit backup paths:
    - `sites-enabled-default.<timestamp>.bak`
    - `nginx.conf.<timestamp>.bak`
  - added `restore_nginx_backups()` helper to restore only those explicit files
  - replaced wildcard rollback copies with helper
  - updated final hardening summary log to show backup directory
- Validation run:
  - `bash -n install/security/nginx_harden.sh`
  - `shellcheck -x --exclude=SC1091,SC2034 install/security/nginx_harden.sh`
  - `GITHUB_TOKEN="$(gh auth token)" SKIP_BUILD=true ./test/run_e2e.sh --phase=2` (green, but uses prebuilt image)
  - committed and pushed fix commit: `39a37fc` (`fix(ci): keep nginx hardening backups out of active includes`)
- Follow-up:
  - wait for fresh PR #170 CI on commit `39a37fc` (especially `CI - Docker Integration Tests`) before merge.

## Latest Update (CI fix: Nginx gzip duplicate in run_2 E2E, 2026-04-18)

- Fixed failing CI jobs `run-2-e2e` and `run-2-web` caused by:
  - `nginx: "gzip" directive is duplicate in /etc/nginx/conf.d/eth2-edge-policy.conf`
- Root cause:
  - shared HTTP policy file set `gzip on;` in `http` context, which conflicts with distro defaults that already set gzip in `nginx.conf`.
- Change:
  - moved Nginx compression directives from `render_nginx_http_policy_file` to `render_nginx_site_config` (server context) in `install/web/proxy_config_renderer.sh`.
  - kept `EDGE_ENABLE_COMPRESSION` behavior intact (still toggles compression for both Nginx and Caddy).
- Test updates:
  - `test/validate_proxy_policy_sync.sh` now asserts Nginx compression in rendered site config.
  - `test/validate_proxy_policy_toggles.sh` now asserts compression-off state in rendered Nginx site config.
- Validation run:
  - `bash -n install/web/proxy_config_renderer.sh test/validate_proxy_policy_sync.sh test/validate_proxy_policy_toggles.sh`
  - `shellcheck -x --exclude=SC1091,SC2034 install/web/proxy_config_renderer.sh test/validate_proxy_policy_sync.sh test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_caddy_config.sh`
  - `GITHUB_TOKEN="$(gh auth token)" SKIP_BUILD=true E2E_EXECUTION=geth E2E_CONSENSUS=prysm E2E_MEV=mev-boost ./test/run_e2e.sh --phase=2`
  - `GITHUB_TOKEN="$(gh auth token)" SKIP_BUILD=true ./test/run_e2e.sh --phase=2`
- Follow-up:
  - remaining Caddy `header_up` warnings in E2E are non-fatal; optional cleanup can remove redundant forwarded-header directives.

## Latest Update (Merge-hardening CI flake guard, 2026-04-18)

- Hardened `test/validate_downloads.sh` so transient GitHub API/network jitter is retried before failing CI:
  - bounded retries with linear backoff for both `get_latest_release` and asset URL checks
  - does not fail fast on first miss; aggregates all failures and reports a full failing checklist
- Added optional tuning env vars for CI/local runs:
  - `DOWNLOAD_TEST_RETRIES` (default `3`)
  - `DOWNLOAD_TEST_RETRY_DELAY_SECONDS` (default `2`)
- Validation run:
  - `bash -n test/validate_downloads.sh`
  - `shellcheck -x --exclude=SC1091,SC2034 test/validate_downloads.sh`
  - `bash test/validate_downloads.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace -e USE_MOCKS=false -e CI=true -e SKIP_SHELLCHECK=true eth-node-test /workspace/test/docker_test.sh`
- Follow-up:
  - keep retries bounded (no infinite loop) so persistent upstream/API issues still fail loudly.

## Latest Update (Edge polish loop pass, 2026-04-18)

- Added focused toggle contract test:
  - `test/validate_proxy_policy_toggles.sh`
  - validates metrics/trusted-proxy toggles, resolver + mixed upstream behavior, and compression on/off behavior.
- Wired toggle contract test into run_2 structure CI:
  - `test/ci_test_run_2.sh`
- Tightened Caddy metrics exposure semantics:
  - metrics now render to a local-only site block (`http://127.0.0.1`) when enabled, instead of public site route exposure.
- Added best-effort Caddyfile formatting on render:
  - `install/web/caddy_helpers.sh` now runs `caddy fmt --overwrite` when Caddy binary is available.
  - `test/validate_caddy_config.sh` docker validation path now formats before validate.
- Updated user-facing docs for new shared edge tuning knobs:
  - `README.md`
  - `docs/CADDY_INSTALLATION.md`
- Validation run:
  - `bash -n install/web/proxy_config_renderer.sh install/web/caddy_helpers.sh test/validate_proxy_policy_toggles.sh test/ci_test_run_2.sh test/validate_caddy_config.sh`
  - `shellcheck -x --exclude=SC1091,SC2034 install/web/proxy_config_renderer.sh install/web/caddy_helpers.sh test/validate_proxy_policy_toggles.sh test/ci_test_run_2.sh test/validate_caddy_config.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_toggles.sh`
  - `bash test/validate_caddy_config.sh`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test /workspace/test/ci_test_run_2.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace -e USE_MOCKS=false -e CI=true -e SKIP_SHELLCHECK=true eth-node-test /workspace/test/docker_test.sh`
- Follow-up:
  - CI re-run on latest branch head is still required before merge.

## Latest Update (Edge performance + parity feature bundle, 2026-04-18)

- Expanded shared edge renderer with explicit performance/reliability knobs for both Nginx and Caddy:
  - upstream pool definitions for RPC/WS with selectable LB policy (`least_conn` or `ip_hash`)
  - explicit upstream retry/failover tuning
  - explicit keepalive sizing
  - shared compression enablement
  - optional metrics endpoint wiring
  - optional trusted-proxy handling
- Added Nginx cache enhancements for RPC-read path:
  - `proxy_cache_background_update on`
  - `proxy_cache_revalidate on`
  - configurable `proxy_cache_min_uses` (`EDGE_RPC_CACHE_MIN_USES`)
- Removed redundant Caddy `header_up X-Forwarded-*` overrides to align with Caddy defaults and reduce noisy validation warnings.
- Added new user-facing tuning knobs in:
  - `exports.sh`
  - `config/user_config.env.example`
- Extended parity contract checks:
  - `test/validate_proxy_policy_sync.sh` now asserts upstream blocks, retry/cache tuning, and compression directives.
- Validation run:
  - `bash -n install/web/proxy_config_renderer.sh exports.sh config/user_config.env.example test/validate_proxy_policy_sync.sh`
  - `shellcheck -x --exclude=SC1091,SC2034 install/web/proxy_config_renderer.sh exports.sh test/validate_proxy_policy_sync.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_caddy_config.sh`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test /workspace/test/ci_test_run_2.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace -e USE_MOCKS=false -e CI=true -e SKIP_SHELLCHECK=true eth-node-test /workspace/test/docker_test.sh`
- Follow-up:
  - metrics remain opt-in (`EDGE_ENABLE_METRICS=false` default) to avoid exposing status endpoints by accident.

## Latest Update (Edge-policy refactor pass, 2026-04-18)

- Refactored shared edge policy to be data-driven via:
  - `config/edge_policy.env`
  - loaded by `install/web/proxy_config_renderer.sh` with safe defaults.
- De-duplicated `render_nginx_site_config` in `install/web/proxy_config_renderer.sh`:
  - reduced dual SSL/non-SSL template duplication while preserving behavior.
- Removed unused legacy helper surface:
  - deleted `install/web/web_helpers_common.sh`
  - removed stale sourcing from Nginx/Caddy helpers and Caddy validation test.
- Consolidated fail2ban ownership by phase:
  - `install/security/consolidated_security.sh` now manages baseline SSH fail2ban only (phase 1).
  - `install/security/nginx_harden.sh` remains owner of Nginx-specific fail2ban filters/jails.
- Refactored web hardening E2E assertions for reuse:
  - `test/ci_test_e2e.sh` now uses shared helpers for HTTP-code assertions/listener readiness.
- Expanded structure checks to include new policy config artifact:
  - `test/ci_test_run_2.sh` now requires and syntax-checks `config/edge_policy.env`.
- Validation run:
  - `bash -n install/security/consolidated_security.sh install/web/caddy_helpers.sh install/web/nginx_helpers.sh install/web/proxy_config_renderer.sh test/ci_test_e2e.sh test/ci_test_run_2.sh test/validate_caddy_config.sh config/edge_policy.env`
  - `shellcheck -x --exclude=SC1091,SC2034 install/security/consolidated_security.sh install/web/caddy_helpers.sh install/web/nginx_helpers.sh install/web/proxy_config_renderer.sh test/ci_test_e2e.sh test/ci_test_run_2.sh test/validate_caddy_config.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_caddy_config.sh`
  - `docker run --rm --privileged --user testuser -v "$PWD:/workspace" -w /workspace -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical -e CI=true eth-node-test /workspace/test/ci_test_run_2.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace -e USE_MOCKS=false -e CI=true -e SKIP_SHELLCHECK=true eth-node-test /workspace/test/docker_test.sh`
- Follow-up:
  - Caddy still emits non-fatal warnings about redundant `header_up X-Forwarded-*`; optional cleanup can remove those directives from the renderer.

## Latest Update (PR #170 docker-integration CI fix, 2026-04-18)

- Fixed `docker-integration` failure in `test/validate_caddy_config.sh` where `caddy validate` ran as non-root and failed opening `/var/log/caddy/access.log`.
- Validation strategy is now resilient and ordered:
  - try `sudo -n caddy validate` when non-interactive sudo is available,
  - fallback to plain `caddy validate`,
  - fallback to `docker run caddy validate`.
- Added cleanup trap for generated temporary Caddyfile to avoid stale `/tmp` artifacts.
- Validation run:
  - `bash test/validate_caddy_config.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace eth-node-test /workspace/test/validate_caddy_config.sh`
  - `docker run --rm --privileged -v "$PWD:/workspace" -w /workspace -e USE_MOCKS=false -e CI=true -e SKIP_SHELLCHECK=true eth-node-test /workspace/test/docker_test.sh`
- Follow-up:
  - CI still emits non-fatal Caddy warnings about redundant `header_up X-Forwarded-*`; optional cleanup can remove these directives from the shared renderer for cleaner logs.

## Latest Update (Unified Nginx/Caddy edge policy + RPC cache hardening, 2026-04-18)

- Implemented a single shared edge-policy renderer at:
  - `install/web/proxy_config_renderer.sh`
- Refactored both web stacks to consume the same source-of-truth policy:
  - `install/web/nginx_helpers.sh`
  - `install/web/caddy_helpers.sh`
  - `install/security/caddy_harden.sh`
- Added Nginx RPC read-cache and hardening behavior in shared policy:
  - JSON-RPC method classification via `map` in `http` context
  - cache enabled for read calls (`MISS/HIT` path)
  - write/dynamic calls marked non-cacheable (`proxy_no_cache`)
  - spam path blocks and request-method restrictions retained
- Added fail2ban/jail hardening improvements for Nginx:
  - `install/security/nginx_harden.sh`
- Ensured Caddy apply path always restarts against latest rendered config:
  - `install/web/install_caddy.sh`
  - log path ownership/readiness hardened in helper layer
- Added policy-sync test coverage:
  - `test/validate_proxy_policy_sync.sh`
  - wired into `test/ci_test_run_2.sh`
- Expanded phase-2 E2E assertions:
  - `test/ci_test_e2e.sh`
  - verifies Caddy method/spam hardening
  - verifies Nginx method/spam hardening + RPC cache classification/hit
- Updated docs for shared-policy architecture:
  - `README.md`
  - `docs/CADDY_INSTALLATION.md`
- Validation run:
  - `bash -n install/web/proxy_config_renderer.sh install/web/nginx_helpers.sh install/web/caddy_helpers.sh install/web/install_caddy.sh install/security/caddy_harden.sh install/security/nginx_harden.sh install/security/consolidated_security.sh test/validate_proxy_policy_sync.sh test/ci_test_e2e.sh test/ci_test_run_2.sh`
  - `shellcheck install/web/proxy_config_renderer.sh install/web/nginx_helpers.sh install/web/caddy_helpers.sh install/web/install_caddy.sh install/security/caddy_harden.sh install/security/nginx_harden.sh install/security/consolidated_security.sh test/validate_proxy_policy_sync.sh test/ci_test_e2e.sh test/ci_test_run_2.sh`
  - `bash test/validate_proxy_policy_sync.sh`
  - `bash test/validate_caddy_config.sh`
  - `E2E_MEV=none ./test/run_e2e.sh --phase=2` (pass: 27/27)
- Follow-up:
  - Docker E2E build time remains dominated by `chown -R /workspace` in `test/Dockerfile`; consider Dockerfile layering/ownership optimization to speed CI feedback loops.

## Latest Update (PR watch refinement pass, 2026-04-13)

- Refined watch defaults to local active PR monitoring:
  - default `--repo`: `chimera-defi/eth2-quickstart`
  - default `--pr`: `167`
- Added automatic cron self-disable behavior:
  - `check-cli-anything-pr.sh --disable-cron-on-closed` now removes its cron marker entry when the watched PR is no longer open.
- Added `scripts/uninstall-cli-anything-pr-watch-cron.sh` for explicit manual cleanup by cron marker.
- Added tracked `status/poll_ci.sh`:
  - snapshots open PR CI/review state to `status/open-prs.json` and `status/ci-summary.json`
  - runs one PR-watch check per poll cycle and writes `status/pr-watch-last.json`
  - fixes the previously missing cron target path for `*/5 * * * * .../status/poll_ci.sh`
- Updated `scripts/install-cli-anything-pr-watch-cron.sh`:
  - supports `--disable-on-closed` / `--no-disable-on-closed`
  - passes marker + disable flags to the watch command
  - defaults to self-disable enabled
- Updated `docs/SCRIPTS.md` with new defaults and uninstall command.
- Validation run:
  - `bash -n scripts/check-cli-anything-pr.sh`
  - `bash -n scripts/install-cli-anything-pr-watch-cron.sh`
  - `bash -n scripts/uninstall-cli-anything-pr-watch-cron.sh`
  - `bash -n status/poll_ci.sh`
  - `shellcheck scripts/check-cli-anything-pr.sh scripts/install-cli-anything-pr-watch-cron.sh scripts/uninstall-cli-anything-pr-watch-cron.sh`
  - `./scripts/install-cli-anything-pr-watch-cron.sh --repo chimera-defi/eth2-quickstart --pr 167 --state-dir /tmp/eth2qs-pr-watch-test`
  - `./scripts/check-cli-anything-pr.sh --repo chimera-defi/eth2-quickstart --pr 169 --state-dir /tmp/eth2qs-pr-watch-test --disable-cron-on-closed --cron-marker eth2qs-cli-pr-watch-test`
  - `./scripts/uninstall-cli-anything-pr-watch-cron.sh --cron-marker eth2qs-cli-pr-watch-test`
  - `ETH2QS_STATUS_WATCH_PR=169 ./status/poll_ci.sh`

## Latest Update (CLI-Anything PR watch cron, 2026-04-13)

- Added `scripts/check-cli-anything-pr.sh` to monitor upstream PR feedback daily via GitHub API.
  - Tracks new issue comments, review comments, and review states.
  - Flags actionable feedback from non-self authors (`request changes`, blockers, fix requests).
  - Writes state + alert reports under `~/.eth2qs-pr-watch/`.
  - Supports optional `--autofix-cmd` hook for automated follow-up.
- Added `scripts/install-cli-anything-pr-watch-cron.sh`.
  - Installs/replaces an idempotent cron entry with marker `eth2qs-cli-pr-watch`.
  - Defaults to daily run (`15 9 * * *`) and logs to `~/.eth2qs-pr-watch/cron.log`.
- Added maintenance docs in `docs/SCRIPTS.md` for these commands.
- Validation run:
  - `bash -n scripts/check-cli-anything-pr.sh`
  - `bash -n scripts/install-cli-anything-pr-watch-cron.sh`
  - `./scripts/check-cli-anything-pr.sh --repo HKUDS/CLI-Anything --pr 195 --state-dir /tmp/eth2qs-pr-watch-test`
  - `./scripts/install-cli-anything-pr-watch-cron.sh --repo HKUDS/CLI-Anything --pr 195 --state-dir /tmp/eth2qs-pr-watch-test --schedule "17 9 * * *"`
- Follow-up:
  - PR #195 is already merged (2026-04-13), so this automation is mainly a reusable pattern for future upstream PRs.
  - If fully autonomous patching is desired, wire `--autofix-cmd` to a guarded branch+test+PR workflow.

## Latest Update (PR #168 CI fix, 2026-04-10)

- Fixed `shellcheck-extended` failure in `install/test/test_repair_safe_actions.sh` by quoting a return status variable:
  - `return $status` -> `return "$status"`
- Fixed `tui-whiptail-nonskip-guard` and `docker-integration` failure caused by a brittle/duplicated JSON-mode test in `install/test/test_stats_read_only.sh`:
  - removed duplicate `test_stats_supports_json_mode` definition
  - replaced static `grep '--json' stats.sh` assertion with behavior validation:
    - injects `ETH2QS_STATS_FIXTURE`
    - runs `stats.sh --json`
    - verifies emitted payload is valid JSON with expected summary status
- Why:
  - the wrapper `stats.sh` now delegates to `stats_json.py` and forwards args (`"$@"`), so checking for a literal `--json` string in `stats.sh` was a false negative
  - CI needed to validate real behavior, not implementation detail
- Validation run:
  - `bash install/test/test_stats_read_only.sh`
  - `shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031,SC2181 install/test/test_repair_safe_actions.sh install/test/test_stats_read_only.sh`
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 SKIP_SHELLCHECK=true USE_MOCKS=true ./test/run_tests.sh --unit`
  - full repo shellcheck parity with CI loop over all `*.sh` files
- Follow-up:
  - keep behavior-based assertions for wrapper scripts to avoid future false CI failures when implementation details change but public behavior is unchanged.

## Latest Update (run_2 unknown-option hardening, 2026-04-08)

- `run_2.sh` now fails fast on unknown CLI flags before logging/install side effects:
  - collects unsupported args
  - prints `Unknown option(s): ...` plus usage to stderr
  - exits with code `2`
- Added regression coverage in `test/ci_test_run_2.sh` (`Test 2c`) to enforce:
  - unknown option returns exit `2`
  - error + usage text is present
  - no `logs/run_2_*.log` file is created on this early-exit path
- Why:
  - prevents typoed automation flags from silently falling into interactive flow
  - keeps CLI behavior deterministic for external wrappers/agents
  - preserves the "no side effects on preflight error" contract already used for `--help`
- Validation run:
  - `bash -n run_2.sh`
  - `bash ./run_2.sh --not-a-real-flag` (verified exit `2` + usage)
  - `su -s /bin/bash eth2ci -c "cd /tmp/eth2-quickstart-ci-run2 && bash test/ci_test_run_2.sh"` (full structure suite passed as non-root)
- Follow-up:
  - mirror this unknown-option fast-fail behavior in other top-level scripts with `--help` preflight paths (`run_1.sh`, selected `install/utils/*`) for consistent automation ergonomics.

## Latest Update (PR #156 — Agent Skill Rollup, 2026-03-13 through 2026-03-20)

- Implemented repo-owned agent skill at `skills/eth2-quickstart/` with SKILL.md routing, reference docs, and resolver script
- Added `./scripts/eth2qs.sh` as canonical wrapper entrypoint for humans and agents
- Added planner-driven install routing: `plan --json`, `ensure` preview, `ensure --apply --confirm` execution
- Shared planning logic lives in `lib/install_planner.sh`; `plan.sh` and `ensure.sh` call `planner_prepare_context`
- Chain-aware routing distinguishes Ethereum vs Monad; partial installs fail safe into review
- `doctor --json` provides machine-readable health output including service-unit drift detection
- `clean-data --dry-run` preserves keys/secrets; `cleanup-host` covers root-managed datadirs
- `stats.sh` is read-only (no Prysm bootstrap downloads)
- Hardened `ensure --apply` to require `--confirm` for phase1/phase2/monad_install execution
- Added `llms.txt` and `llms-full.txt` as raw-ingest fallback for agents without ClawHub
- Added frontend `Agents.tsx` homepage section and `docs/AGENT_SKILL_LISTING.md` marketing copy
- Skill distribution CI enforces ClawHub install language, resolver, and llms.txt presence
- Test coverage: structure, command-mapping, safety, distribution, planner, ensure-dispatch, plan-json, doctor-drift, host-cleanup, stats-read-only
- Removed packaging-only surfaces: `agents/openai.yaml`, observation recorder, duplicate install-routes doc
- Deduplicated planner context setup across plan/ensure scripts
- Trimmed README and docs of repeated install/marketing wording
- All validation passing: `pre-commit.sh`, `run_tests.sh`, frontend lint/test/build

## Latest Update (MCP server feature branch, 2026-03-26)

- Added a thin stdio MCP server under `mcp_server/` so Claude Code and Codex can use `eth2-quickstart` as native tools instead of only skill/docs ingestion
- Server wraps the canonical `./scripts/eth2qs.sh` surface; it does not reimplement install or operations logic
- Added guarded MCP tools for `doctor --json`, `plan --json`, `ensure` preview/apply, `stats`, bounded `logs`, `start/stop/restart`, dry-run cleanup, and explicit `monad-install`
- Mutating MCP tools require `confirm=true` and `confirmation_token='apply'`
- Added `skills/eth2-quickstart/references/mcp.md` plus README wiring for Claude Code / Codex setup via `./mcp_server/run_eth2qs_mcp.sh`
- Added Python/unit/contract coverage in `test/test_mcp_tools.py` and `test/ci_test_mcp_server.sh`
- Wired MCP checks into CI, `test/run_tests.sh`, and `scripts/pre-commit.sh`
- Tightened lint scope in `test/run_tests.sh` and `scripts/pre-commit.sh` to tracked repo shell files only so unrelated workspace content does not break validation
- Validation run: `bash test/ci_test_mcp_server.sh`, `bash test/ci_test_skill_distribution.sh`, `bash test/ci_test_docs_consistency.sh`, `./scripts/pre-commit.sh`
- Follow-up: publish/test the skill separately in ClawHub once auth exists; MCP server itself is local-stdio ready now
- Follow-up on 2026-03-26: fixed `.github/actions/docker-prep` to take `github_token` as an input instead of referencing `secrets` directly, which was breaking all Docker-based CI jobs on PR #157
- Local runtime proof on 2026-03-26: the MCP server initialized successfully through the Python MCP SDK, `codex exec` invoked `eth2qs_info` and returned the wrapper path, and Claude Code reached MCP connection state locally but non-interactive tool invocation was blocked by local usage quota rather than by the server
- Discoverability pass on 2026-03-26: added a compact MCP quickstart to `README.md`, added an MCP pointer to `llms.txt`, and added a native MCP tools callout/snippet to `frontend/components/sections/Agents.tsx`; validated with docs consistency, frontend lint/test/build
- MCP lifecycle pass on 2026-03-26: added explicit `eth2qs_phase1` and `eth2qs_phase2` tools so server hardening and Ethereum client install are first-class MCP actions instead of only planner-driven behavior; validated in unit tests and via live MCP `list_tools`

## Latest Update (Client Options Surface, 2026-04-07)

- Added `config/client_options.json` as the shared machine-readable source of truth for supported execution clients, consensus clients, MEV options, ETHGas constraints, and tested presets
- Added `./scripts/eth2qs.sh client-options --json` via `install/utils/client_options.sh` so external wrappers can discover valid flags without re-encoding repo knowledge
- Updated MCP `eth2qs_client_options` to read the same JSON file instead of maintaining a separate hardcoded copy
- Updated README, `docs/SCRIPTS.md`, and agent reference docs to point at the new command
- Validation run: `./scripts/eth2qs.sh client-options --json`, `python3 -m unittest discover -s test -p 'test_mcp_tools.py'`, `bash test/ci_test_mcp_server.sh`
- Follow-up: external harnesses like CLI-Anything can switch from embedded client enums to the repo-native `client-options --json` surface

## Latest Update (Monitoring / Triage Surface, 2026-04-08)

- Added `install/utils/stats_json.py` and `./scripts/eth2qs.sh stats --json` as the machine-readable monitoring surface for service states, recent errors, planner/doctor context, and bounded repair previews
- Added MCP `eth2qs_stats_json` so Claude/Codex can inspect current host state without scraping human-oriented `stats.sh` output
- `stats --json` now classifies several common failure modes from recent journal evidence:
  - missing validator wallet / keys
  - service flag mismatch after binary/config drift
  - config parse failures
  - peer connectivity degradation
  - MEV endpoint refusal
  - locked database / duplicate process symptoms
- Monitoring output now includes planner/doctor context instead of showing a false `pass` on partially installed or warning-state hosts
- Added tests:
  - `install/test/test_stats_json_contract.sh`
  - `test/test_stats_json.py`
  - existing MCP/skill contract tests updated to require `stats --json`
- Updated `README.md`, `docs/SCRIPTS.md`, and skill references to advertise `stats --json` as the preferred monitoring/triage surface
- Validation run:
  - `bash install/test/test_stats_json_contract.sh`
  - `bash install/test/test_stats_read_only.sh`
  - `python3 -m unittest discover -s test -p 'test_*.py'`
  - `bash test/ci_test_mcp_server.sh`
  - `bash test/ci_test_skill_command_mapping.sh`
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 SKIP_SHELLCHECK=true USE_MOCKS=true ./test/run_tests.sh --unit`
- Follow-up:
  - add a guarded `repair --apply` path for clearly safe actions only
  - add explicit software release freshness checks before offering updater automation

## Latest Update (Snort Default-On Baseline, 2026-04-13)

- Switched Snort IDS from opt-in to enabled-by-default baseline:
  - `exports.sh` now defaults `ENABLE_SNORT='true'`
  - `install/security/consolidated_security.sh` now treats missing `ENABLE_SNORT` as enabled (`${ENABLE_SNORT:-true}`)
- Kept explicit disable path for constrained hosts:
  - set `ENABLE_SNORT=false` in `config/user_config.env`
- Updated user-facing docs to match runtime behavior:
  - `README.md`
  - `config/user_config.env.example`
  - `docs/SCRIPTS.md`
  - `docs/SECURITY_GUIDE.md`
  - `docs/SECURITY_STATUS.md`
- Updated CI guardrails in `test/ci_test_run_1.sh` so defaults and gating checks assert default-on behavior.
- Validation run:
  - `bash -n exports.sh`
  - `bash -n install/security/consolidated_security.sh`
  - `bash -n test/ci_test_run_1.sh`
  - `bash test/ci_test_run_1.sh`
  - `bash test/ci_test_docs_consistency.sh`

## Latest Update (Optional Snort IDS Profile, 2026-04-09)

- Added optional Snort IDS integration to Phase 1 security hardening with `ENABLE_SNORT=false` default in `exports.sh`
- Added Snort config knobs:
  - `SNORT_INTERFACE` (default `auto`)
  - `SNORT_HOME_NET` (default empty; auto-detect)
  - `SNORT_STARTUP` (`boot|manual`, default `boot`)
  - `SNORT_DISABLE_PROMISCUOUS` (default `true`)
- `install/security/consolidated_security.sh` now includes:
  - truthy parser + interface/CIDR auto-detection helpers
  - gated `setup_snort()` path with debconf preseeding for non-interactive installs
  - package install + config patching + `snort -T` self-test + optional service enable/start
  - verification checks when Snort is enabled
- Updated docs/user config examples to document optional Snort profile:
  - `README.md`
  - `config/user_config.env.example`
  - `docs/SCRIPTS.md`
  - `docs/SECURITY_GUIDE.md`
  - `docs/SECURITY_STATUS.md`
- Added CI structure checks in `test/ci_test_run_1.sh` to ensure Snort remains off-by-default and gated
- Validation run:
  - `bash -n install/security/consolidated_security.sh`
  - `bash -n test/ci_test_run_1.sh`
  - `bash -n exports.sh`
  - `bash test/ci_test_run_1.sh`
  - `bash test/ci_test_docs_consistency.sh`

## Latest Update (Safe Repair Workflow, 2026-04-08)

- Added `install/utils/repair.sh` and wrapper command `./scripts/eth2qs.sh repair`
- `repair` previews allowlisted safe restart actions derived from `stats --json` and requires `--apply --confirm` before making changes
- Smart refresh now exists via `./scripts/eth2qs.sh restart --smart`, which delegates to the same bounded repair logic instead of restarting the full stack blindly
- Added MCP tools:
  - `eth2qs_repair_preview`
  - `eth2qs_repair_apply`
- Tightened `stats --json` repair previews so some warnings now map to targeted restarts instead of broad full-stack restarts:
  - peer connectivity degradation -> restart consensus client
  - MEV endpoint refusal -> restart the active builder sidecar when one is present
- Added tests:
  - `install/test/test_repair_safe_actions.sh`
  - unit coverage in `test/test_stats_json.py`
  - MCP contract updates in `test/test_mcp_tools.py` and `test/ci_test_mcp_server.sh`
- Updated README, `docs/SCRIPTS.md`, SKILL docs, and MCP docs to point agents toward `repair` and `restart --smart`
- Validation run:
  - `bash install/test/test_repair_safe_actions.sh`
  - `python3 -m unittest discover -s test -p 'test_*.py'`
  - `bash test/ci_test_mcp_server.sh`
  - `bash test/ci_test_skill_command_mapping.sh`
  - `bash test/ci_test_docs_consistency.sh`
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 SKIP_SHELLCHECK=true USE_MOCKS=true ./test/run_tests.sh --unit`
- Follow-up:
  - compare installed client versions to upstream releases before suggesting software updates
  - collapse more of the human `stats.sh` flow onto the JSON triage core to reduce duplicated monitoring logic

## Latest Update (Monitoring Platform Pass, 2026-04-08)

- Added a shared monitoring helper module at `install/utils/monitor_common.py` so repo drift, service state, journal, version, and systemd metadata are no longer reimplemented across multiple scripts
- Reduced shell duplication by turning `install/utils/stats.sh` into a thin dispatcher to the Python monitoring core
- Added `./scripts/eth2qs.sh update-check --json` via `install/utils/update_check.py` / `update_check.sh`
  - compares local repo drift and installed `geth`, `mev-boost`, and `prysm` versions against the latest known upstream release tags
- Added `./scripts/eth2qs.sh debug --json --service <name>` via `install/utils/debug_json.py` / `debug.sh`
  - returns structured per-service RCA data: unit metadata, recent log tail, recent error sample, main PID, and listen socket hints
- Added `./scripts/eth2qs.sh monitor ...` via `install/utils/monitor_report.py` / `monitor.sh`
  - `monitor export --json`: compact status for bots/dashboards/cron
  - `monitor snapshot --json`: writes a local history entry under `~/.eth2qs-monitor/snapshots/`
  - `monitor history --json --limit N`: shows recent summaries and deltas
- Added new MCP read-only tools:
  - `eth2qs_update_check_json`
  - `eth2qs_debug_json`
  - `eth2qs_monitor_export_json`
  - `eth2qs_monitor_history_json`
- Updated README, `docs/SCRIPTS.md`, and skill references so the new monitoring/update/debug surfaces are part of the documented contract
- Added tests:
  - `install/test/test_monitor_contracts.sh`
  - `test/test_update_check.py`
  - `test/test_debug_json.py`
  - `test/test_monitor_report.py`
  - expanded `test/test_mcp_tools.py`, `test/ci_test_mcp_server.sh`, `test/ci_test_skill_command_mapping.sh`
- Validation run:
  - `python3 -m py_compile install/utils/monitor_common.py install/utils/stats_json.py install/utils/update_check.py install/utils/debug_json.py install/utils/monitor_report.py mcp_server/eth2qs_mcp_tools.py mcp_server/eth2qs_mcp_server.py`
  - `python3 -m unittest discover -s test -p 'test_*.py'`
  - `bash install/test/test_stats_json_contract.sh`
  - `bash install/test/test_monitor_contracts.sh`
  - `bash install/test/test_stats_read_only.sh`
  - `bash test/ci_test_mcp_server.sh`
  - `bash test/ci_test_skill_command_mapping.sh`
  - `bash test/ci_test_docs_consistency.sh`
  - `REQUIRE_WHIPTAIL_PIPE_TEST=1 SKIP_SHELLCHECK=true USE_MOCKS=true ./test/run_tests.sh --unit`
- Live host timing notes from `/usr/bin/time`:
  - `./scripts/eth2qs.sh update-check --json` ≈ `0.88s`
  - `./scripts/eth2qs.sh monitor export --json` ≈ `6.09s`
  - `./scripts/eth2qs.sh stats --json` ≈ `17.24s`
  - `./scripts/eth2qs.sh debug --json --service cl` improved from ≈ `29.78s` to ≈ `5.41s` after making filtered debug requests avoid a full-host stats pass
- Follow-up:
  - `stats --json` is still the latency bottleneck because it walks recent journals for every known service; next pass should add an explicit fast mode or incremental cache instead of re-scanning the full fleet on every call
  - `repair --apply` is still intentionally bounded to allowlisted restart actions; do not widen it into unattended software upgrades without explicit freshness + safety gates

## Latest Update (Caddy install-enforced rate-limit + fail2ban defaults, 2026-04-21)

- Implemented batteries-included defaults for edge hardening:
  - metrics default-on in shared edge policy (`EDGE_ENABLE_METRICS=true`)
  - install-time Caddy rate-limit enforcement default (`CADDY_INSTALL_ENFORCE_RATE_LIMIT=true`)
  - Caddy fail2ban jails for spam-path probes and repeated 429 abuse (`caddy-rpc-spam`, `caddy-rate-limit`)
- Fixed CI regression root cause:
  - previous generated Caddyfile used invalid `rate_limit zone <name>` route-level syntax
  - renderer now emits valid `rate_limit { zone ... { match { ... } ... } }` blocks with request matchers for `/rpc*` and `/ws*`
  - `test/validate_proxy_policy_toggles.sh` now explicitly asserts matcher-based zone blocks and rejects `rate_limit zone (api|ws)` output
- Files changed:
  - `install/web/proxy_config_renderer.sh`
  - `install/web/install_caddy.sh`
  - `install/security/caddy_harden.sh`
  - `exports.sh`
  - `config/user_config.env.example`
  - `README.md`
  - `docs/CADDY_INSTALLATION.md`
  - `test/validate_review_guardrails.sh`
- Completion quality gate:
  - Security audit:
    - `bash install/security/test_security_fixes.sh` -> **partial/expected host-level failures** (`Security monitoring script not found`, root crontab/logrotate checks missing) because this dev host is not a provisioned run_1 target.
    - Residual risk: host-level security monitoring wiring cannot be fully asserted outside a provisioned target host.
  - Code/dead-code review:
    - manual multi-pass review over all changed files; removed invalid Caddy rate-limit invocation pattern; verified no leftover `rate_limit zone` usage.
  - Regression review:
    - `bash -n install/web/proxy_config_renderer.sh install/web/install_caddy.sh install/security/caddy_harden.sh test/validate_review_guardrails.sh` -> pass
    - `shellcheck -x -e SC1091 install/web/proxy_config_renderer.sh install/web/install_caddy.sh install/security/caddy_harden.sh test/validate_review_guardrails.sh` -> pass
    - `bash test/validate_caddy_config.sh` -> pass
    - `bash test/validate_proxy_policy_toggles.sh` -> pass
    - `bash test/validate_review_guardrails.sh` -> pass
    - `bash test/validate_nginx_config.sh` -> pass
    - `bash test/validate_proxy_policy_sync.sh` -> pass
    - `./test/run_e2e.sh --phase=2` -> pass (`29/29`)
    - `bash test/ci_test_run_2.sh` -> not runnable in this shell because it requires non-root execution.
## MCP Meta Learnings

- Composite GitHub actions must not reference `secrets.*` directly in `action.yml`; pass tokens through explicit action inputs from the workflow.
- For agent-facing MCP servers, core repo offerings must be explicit tools, not only indirect planner paths. `phase1` and `phase2` needed to be first-class, not hidden behind `ensure_apply`.
- MCP `list_tools` should remain the authoritative schema surface for agents. A compact info/catalog tool is useful, but it should complement the protocol surface rather than replace it.
- Shared-workspace validation should lint tracked repo files only. Untracked neighboring directories can otherwise create false CI/pre-commit failures unrelated to the repo.
- For agent install flows, add a read-only client-options tool when the underlying CLI supports non-interactive flags. Agents should not have to infer valid enum values from prose or source.
