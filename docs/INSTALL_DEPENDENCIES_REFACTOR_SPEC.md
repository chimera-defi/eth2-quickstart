# Install Dependencies Refactor Spec

**Status: IMPLEMENTED.** This spec describes the refactor that was completed.

## Quick Reference

| Path | Script | Mode | Sudo for apt? |
|------|--------|------|---------------|
| Root | run_1.sh | `install_dependencies.sh --production-root` | No |
| User | run_2.sh | `install_dependencies.sh --verify` | No |

## Goal

Split dependency installation into two security-conscious paths:
1. **Root path (run_1)**: Install all system packages as root—no sudo needed.
2. **User path (run_2)**: Verify dependencies exist only—no package installation, no sudo for apt.

This removes the security risk of the eth user needing sudo for package installation.

---

## Current State (Implemented)

### Call Sites

| Caller | What | User | Sudo? |
|--------|------|------|-------|
| **run_1.sh** | `install_dependencies.sh --production-root` (before consolidated_security) | root | No |
| **run_2.sh** | `install_dependencies.sh --verify` | eth user | No |
| **test/Dockerfile** | `install_dependencies.sh --test` | root | No |

### run_1 Flow (implemented)

```
apt update/upgrade → debconf_preseed → setup_secure_user → 99-noninteractive sudoers →
install_dependencies.sh --production-root (installs aide, cron, fail2ban, nginx, chrony, etc.) →
configure_ssh → consolidated_security (configures only; packages already installed) →
apply_network_security → setup_security_monitoring → copy repo → handoff
```

### run_2 Flow (implemented)

```
verify_dependencies (install_dependencies.sh --verify) → verify_client_configs →
client install (client scripts use sudo for systemd, ufw, PPA when needed)
```

### What Needs Root vs User-Space

| Component | Needs root? | Notes |
|-----------|-------------|-------|
| apt packages | Yes | BASE, TEST, PRODUCTION |
| Ethereum PPA + ethereum pkg | Yes | add-apt-repository |
| Node.js (nodesource) | Yes | curl \| bash, apt install |
| Go (snap) | Yes | snap install |
| certbot (snap) | Yes | snap install |
| **Rust** | **No** | rustup installs to ~/.cargo |
| timedatectl set-ntp | Yes | systemd |
| debconf preseed | Yes | writes /var/cache/debconf |

### Client Scripts Still Need Sudo For

- `create_systemd_service`: `sudo mv` to /etc/systemd
- `enable_and_start_systemd_service`: `sudo systemctl`
- `setup_firewall_rules`: `sudo ufw`
- `add_ppa_repository`: `sudo add-apt-repository` (geth.sh, etc.)

These are narrower than full package installation. Future work could restrict sudo to specific commands.

---

## Proposed Architecture

### New Modes in install_dependencies.sh

| Mode | Flag | Runs as | Behavior |
|------|------|---------|----------|
| **production-root** | `--production-root` | root only | Install all production packages. No sudo. Install Rust for $LOGIN_UNAME. |
| **verify** | `--verify` | any | Check required tools exist. Exit 1 if missing. No sudo. |
| test | `--test` | any | Unchanged (used by Dockerfile) |
| base | `--base` | any | Unchanged |

### Shared Logic (No Duplication)

- **Package arrays**: BASE_PACKAGES, TEST_PACKAGES, PRODUCTION_PACKAGES — single source
- **install_packages()**: Used by install_base, install_test, install_production_root
- **install_production_root()**: New. Requires root. Uses apt-get directly (no sudo). Installs Rust for $LOGIN_UNAME via `sudo -u $LOGIN_UNAME`.
- **verify_dependencies()**: New. Checks: required apt packages, node, go, cargo (optional for ethrex/ethgas). No install.

### run_1 Changes

1. After `setup_secure_user`, before `configure_ssh`:
   - Call `install_dependencies.sh --production-root`
   - Requires LOGIN_UNAME (from exports.sh)
2. **consolidated_security.sh**: Remove `install_dependencies aide cron fail2ban` — packages already installed by run_1.

### run_2 Changes

1. Replace `install_dependencies.sh` with `install_dependencies.sh --verify`
2. Remove debconf_preseed from run_2 (root ran it in run_1; Dockerfile has it for Phase 2 standalone)
3. `--skip-deps`: skip verify (for CI when deps known present). Default: run verify.

### Rust Handling

- **install_production_root**: After installing apt/snap/node, run:
  ```bash
  sudo -u "$LOGIN_UNAME" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
  ```
  And ensure `~/.cargo/bin` is in PATH for that user (add to ~/.bashrc or similar).
- **install_verify**: Check `command -v cargo` in the current user's PATH. If missing and ethrex/ethgas might be used, we could run rustup (no sudo) — or leave it to ethrex/ethgas to fail with clear message.

Simpler: Rust installed in run_1 for LOGIN_UNAME. run_2 verify checks for cargo. If missing, error: "Run Phase 1 (run_1.sh) first."

### Docker / CI

| Context | Current | After Refactor |
|---------|---------|-----------------|
| **Dockerfile** | `install_dependencies.sh --test` | Keep --test. Add `install_dependencies.sh --production-root` so Phase 2 E2E has deps. (LOGIN_UNAME=testuser for Rust) |
| **Phase 1 E2E** | run_1.sh | run_1.sh (now includes --production-root) |
| **Phase 2 E2E** | install_dependencies --production, run_2 --skip-deps | run_2 (verify only, no --skip-deps) — deps from Dockerfile |
| **Phase 2 standalone** | Needs install_deps | Dockerfile has production deps; verify passes |

For Dockerfile: we need LOGIN_UNAME when running --production-root. Dockerfile creates testuser. So we run:
```dockerfile
RUN bash /workspace/install/utils/install_dependencies.sh --production-root
```
But the script needs LOGIN_UNAME. In Dockerfile we don't have exports.sh loaded with LOGIN_UNAME. Options:
- Export in Dockerfile: `ENV LOGIN_UNAME=testuser` before the RUN
- Or have --production-root accept optional env LOGIN_UNAME; if unset, skip Rust (Rust not needed for Dockerfile — Phase 2 runs as testuser, and we install production before testuser exists in Dockerfile... actually testuser IS created in Dockerfile before we switch USER testuser). So we create testuser, then run install_dependencies --production-root. At that point LOGIN_UNAME=testuser. We need to set it: `ENV LOGIN_UNAME=testuser` in Dockerfile.

---

## Verify Mode — What to Check

```bash
verify_dependencies() {
  # Required commands (from PRODUCTION_PACKAGES + BASE)
  local required_commands=(curl wget git jq openssl geth 2>/dev/null || true)  # geth optional
  # Actually: we need to check packages are installed, not just commands.
  # dpkg -l <pkg> or command -v
  # Required: build-essential, python3, chrony, nginx, node (for lodestar), go (for most clients)
  # Optional: cargo (for ethrex, ethgas), bazel (for prysm builder)
}
```

**Required for run_2 client install:**
- Base: curl, wget, git, jq, openssl
- Production: unzip, build-essential, python3, chrony, nginx, cmake, etc.
- Node (lodestar), Go (geth, prysm, lighthouse, etc.), Java (teku, besu)
- Optional: cargo (ethrex, ethgas), bazel (prysm builder)

**Verify logic**: For each required tool, `command -v X` or `dpkg -l X`. If any missing, log_error and exit 1 with message: "Run Phase 1 (run_1.sh) first to install dependencies."

**Verify checklist (minimal set):**
- Commands: `curl`, `wget`, `git`, `jq`, `openssl`, `node` (lodestar), `go` (geth/prysm/lighthouse)
- Packages: `build-essential`, `chrony`, `nginx` (dpkg -l or command -v)
- Optional: `cargo` (ethrex/ethgas), `java` (teku/besu)

---

## Task List

### Phase 1: install_dependencies.sh

1. [ ] Add `install_production_root()` — requires root, uses apt-get (no sudo), installs Rust for LOGIN_UNAME
2. [ ] Add `verify_dependencies()` — checks packages/tools, no install
3. [ ] Add `--production-root` and `--verify` to main() case
4. [ ] Update install_packages() to support root path (no sudo when EUID=0)
5. [ ] Fix timedatectl: use `timedatectl` when root (no sudo needed)

### Phase 2: consolidated_security.sh

6. [ ] Remove `install_dependencies aide cron fail2ban` from main()
7. [ ] Document that run_1 must run install_dependencies --production-root before consolidated_security

### Phase 3: run_1.sh

8. [ ] Add call to `install_dependencies.sh --production-root` after setup_secure_user and 99-noninteractive, before configure_ssh (exact spot: after line 88, before line 90)
9. [ ] LOGIN_UNAME already available from exports.sh

### Phase 4: run_2.sh

10. [ ] Replace `install_dependencies.sh` with `install_dependencies.sh --verify`
11. [ ] Remove debconf_preseed from run_2 (handled in run_1; Dockerfile for Phase 2 standalone)
12. [ ] Update --skip-deps to skip verify (optional)
12b. [ ] Add `PATH="$HOME/.cargo/bin:$PATH"` near top of run_2 so verify and client scripts find cargo

### Phase 5: Dockerfile

13. [ ] Add `ENV LOGIN_UNAME=testuser` and `ENV CI_E2E=true` before production install (so Node/Rust get installed)
14. [ ] Add `RUN install_dependencies.sh --production-root` after --test (so image has production deps for Phase 2 E2E)
15. [ ] Ensure Go fallback: when snap skipped in Docker, install golang-go from apt in install_production_root

### Phase 6: ci_test_e2e.sh (Phase 2)

16. [ ] Remove `install_dependencies.sh --production` call (deps from Dockerfile)
17. [ ] Remove debconf_preseed call (Dockerfile has it)
18. [ ] Run run_2 without --skip-deps (verify runs, then client install)

### Phase 7: Testing

**Docker CI (maximize coverage):**
19. [ ] `./test/run_tests.sh --lint-only` — lint/syntax
20. [ ] `docker build -t eth-node-test -f test/Dockerfile .` — build succeeds
21. [ ] `./test/run_e2e.sh --phase=1` — Phase 1 E2E (run_1 with production-root)
22. [ ] `./test/run_e2e.sh --phase=2` — Phase 2 E2E (run_2 verify only)
23. [ ] `./test/docker_test.sh` (via `docker run eth-node-test`) — structure, shellcheck, function tests
24. [ ] `./test/ci_test_run_2.sh` — structure validation (no change expected)

**Local (manual):**
25. [ ] Clean Ubuntu VM: run Phase 1, reboot, run Phase 2 — full flow
26. [ ] Confirm run_2 does NOT call `sudo apt-get` (grep for it in run_2 flow)
27. [ ] Standalone run_2: run without run_1 first — verify fails with clear message

### Phase 8: Documentation

28. [ ] Update .cursorrules install_dependencies section
29. [ ] Update docs/COMMON_FUNCTIONS_REFERENCE.md if install_dependencies() function changes
30. [ ] Update docs/SCRIPTS.md or relevant docs

**Note:** The eth user still has sudo (from setup_secure_user) for systemd, ufw, add-apt-repository used by client scripts. We only remove the need for `sudo apt-get install` from run_2.

---

## Critical Review — Gaps and Fixes

### 1. Snap doesn't work in Docker → No Go

**Problem:** `install_production` skips snap in Docker. Go and certbot come from snap. Phase 2 E2E needs Go for some clients (or at least verify might check for it).

**Fix:** In `install_production_root`, when `is_docker` and snap is skipped, install Go from apt: `apt-get install -y golang-go` (or `golang-1.21` etc.). Certbot can stay skipped in Docker (not needed for E2E).

### 2. Node and Rust in Docker require CI_E2E

**Problem:** Current logic: `if ! is_docker || [[ "${CI_E2E:-}" == "true" ]]; then` for Node and Rust. Dockerfile build does NOT set CI_E2E. So we'd skip Node and Rust in the image.

**Fix:** For `install_production_root`, always install Node and Rust (no is_docker/CI_E2E gate). That path is only used when we want full production deps (run_1, Dockerfile). Alternatively: set `ENV CI_E2E=true` in Dockerfile before the `--production-root` RUN.

### 3. Rust PATH in verify

**Problem:** Rust installs to `~/.cargo/bin`. rustup adds to `~/.bashrc`. When `run_2` runs as a script, it may not source `.bashrc`, so `command -v cargo` can fail even when Rust is installed.

**Fix:** Either (a) add `PATH="$HOME/.cargo/bin:$PATH"` at the start of run_2, or (b) have verify also check `[[ -x "$HOME/.cargo/bin/cargo" ]]`. Prefer (a) so client scripts (ethrex, ethgas) also see cargo.

### 4. install_production_root must not use sudo

**Problem:** Current `install_production` uses `sudo -E bash -` for nodesource and `sudo snap install` for Go. When running as root, sudo is redundant but works. However, for consistency and to avoid any sudo-related edge cases, `install_production_root` should use direct commands: `curl ... | bash -` (no sudo), `snap install` (no sudo when root). `add_ppa_repository` uses sudo—when root runs it, sudo is effectively a no-op, so it works.

### 5. add_ppa_repository assumes sudo

**Problem:** `add_ppa_repository` does `sudo add-apt-repository`. When run from root, sudo is redundant but works. No change needed for root.

### 6. Verify scope — required vs optional

**Problem:** Go is required for some clients (e.g. building) but not for geth/prysm (pre-built). Java for Teku/Besu. Making everything required could cause false failures.

**Fix:** Split verify into:
- **Required (all):** curl, wget, git, jq, openssl, build-essential, chrony, nginx
- **Required for default clients:** ethereum package (geth), node (lodestar), go (prysm script, lighthouse)
- **Optional (warn only):** cargo, java, bazel — fail only if user selects a client that needs them

Simpler: require the minimal set that `install_production_root` always installs. If any is missing, run_1 was not run. Optional tools can be checked by the client install scripts.

### 7. Dockerfile build time and size

**Problem:** Adding `--production-root` (Node, Go, Rust, full PRODUCTION_PACKAGES) will increase build time and image size.

**Mitigation:** Document the tradeoff. Consider multi-stage build later if needed.

### 8. run_1 duration

**Problem:** run_1 will take longer (production packages, Node, Go, Rust, snap).

**Mitigation:** Document. Users expect Phase 1 to be heavier.

### 9. Task numbering

**Problem:** Phase 5 tasks jump from 12 to 14.

**Fix:** Renumber tasks 14–18 → 13–17, etc.

### 10. debconf_preseed in run_2

**Problem:** Client scripts (e.g. geth.sh) run `add_ppa_repository` and `apt-get install geth`. That can trigger tzdata prompts.

**Resolution:** run_1 runs debconf_preseed. The 99-noninteractive sudoers preserves DEBIAN_FRONTEND for the eth user. run_2 exports DEBIAN_FRONTEND. Child processes inherit it. debconf is system-wide, so run_1's preseed applies. No need to run debconf again in run_2. ✓

---

## Audit Results (Pre-Implementation)

### Client Dependency Audit

| Client | Install method | Needs |
|--------|----------------|-------|
| **geth** | ethereum PPA + apt | add_ppa, ethereum pkg (run_1 installs; geth.sh only adds PPA, expects /usr/bin/geth) |
| **prysm** | download prysm.sh + binaries | curl, download_file |
| **lighthouse** | download pre-built | curl, tar |
| **lodestar** | npm install | Node, npm |
| **teku** | download pre-built | curl, tar, **Java** |
| **besu** | download pre-built | curl, tar, **Java** |
| **nimbus** | download pre-built | curl, tar |
| **grandine** | download pre-built | curl |
| **ethrex** | cargo build | **Rust/cargo** |
| **ethgas** | cargo build | **Rust/cargo** |
| **fb_mev_prysm** | bazel build | **Bazel** |

**Default E2E (geth+prysm+mev-boost):** Needs base + ethereum pkg. No Go, Node, Rust, Java.

**Verify minimal set:** curl, wget, git, jq, openssl, build-essential, chrony, nginx, ethereum (geth). Optional: node, go, cargo, java — only fail if install_production_root would have installed them but didn't.

### Docker Build Walkthrough

**Current sequence:** debconf → --test → Caddy → SSH → useradd testuser → chown → USER testuser

**New sequence:** Same, but after useradd and before chown:
```
ENV LOGIN_UNAME=testuser
ENV CI_E2E=true
RUN apt-get update && \
    bash /workspace/install/utils/install_dependencies.sh --production-root && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
```
Then chown, USER testuser.

**Phase 2 E2E flow:** Container starts from image (has production deps). docker exec --user testuser ci_test_e2e.sh. ci_test_e2e: remove debconf, remove install_deps, run run_2 (verify + client install). run_2 verify checks tools; they exist. ✓

---

## Edge Cases

1. **Standalone run_2** (user runs run_2 without run_1): Verify fails. Clear error: "Missing dependencies. Run run_1.sh first."
2. **Docker Phase 2 only**: Dockerfile has production deps. Verify passes.
3. **Rust for ethrex/ethgas**: Installed in run_1 for LOGIN_UNAME. If user skips run_1 and runs run_2, verify fails on cargo. ethrex/ethgas scripts already check and error.
4. **CI_E2E**: Phase 2 runs as testuser. Dockerfile installed production as root. Verify runs as testuser—checks command -v node, go, etc. Those are system-wide, so testuser sees them. Good.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| run_1 takes much longer | Document; users expect Phase 1 to be heavier |
| Docker image larger/slower to build | Accept for now; multi-stage build later if needed |
| Verify too strict (optional deps) | Require only what install_production_root always installs; client scripts check their own deps |
| Verify too loose (missing deps) | Require minimal set; fail with clear "Run run_1 first" message |
| Regression for standalone run_2 | Verify fails fast with clear error; user must run run_1 first |
| Phase 2 E2E in fresh container | Dockerfile pre-installs production deps; verify passes |

## Rollback

If issues arise: revert run_1/run_2/consolidated_security changes. install_dependencies.sh can keep both --production (legacy) and --production-root. run_2 could fall back to --production with a flag.

---

## Summary

| Before | After |
|--------|-------|
| run_1: no install_dependencies.sh | run_1: install_dependencies.sh --production-root |
| run_2: install_dependencies.sh (sudo apt) | run_2: install_dependencies.sh --verify (no sudo) |
| consolidated_security: install_dependencies aide cron fail2ban | consolidated_security: no install (already in run_1) |
| Phase 2 E2E: install_deps then run_2 --skip-deps | Phase 2 E2E: run_2 verify only |
| Dockerfile: --test only | Dockerfile: --test + --production-root |
