# Two-Phase Install: Why and What Goes Where

**Use the pre-existing `run_1.sh` and `run_2.sh` scripts** for the standard two-phase installation.

## Why Two Phases?

**Security.** The project handles real money (ETH validators). The two-phase model prevents lockout and enforces privilege separation.

| Phase | Runs as | Purpose |
|-------|---------|---------|
| **Phase 1** | root | System hardening, user creation, SSH key migration, firewall, fail2ban, AIDE |
| **Phase 2** | eth user | Client installation (geth, prysm, etc.) |

### Critical Flow

1. **Phase 1 hardens SSH** — changes port, disables root login, migrates keys to new user
2. **User MUST reboot** — security changes take effect
3. **User MUST verify** — SSH in as the new user before Phase 2
4. **Phase 2 refuses root** — runs as eth user only

If phases were combined, a failure after SSH hardening could lock the user out. The mandatory reboot forces verification.

### Privilege Separation

- **Phase 1**: Root-only operations (useradd, sshd_config, ufw, /etc/*)
- **Phase 2**: User operations; sudo only for narrow tasks (systemctl, ufw allow, apt for client-specific deps)

---

## What Belongs in run_1 vs run_2?

### run_1 (root) — System-wide, no user choice

- Base packages: curl, wget, git, jq, openssl (needed by many scripts)
- Security: aide, cron, fail2ban, ufw (consolidated_security)
- Build tools: build-essential, python3, etc. (common)
- chrony (NTP)
- nginx (RPC proxy — optional; could move to run_2 when user installs web)

### run_2 / client scripts — Depends on user selection

- **geth** → geth.sh (add PPA + install ethereum)
- **Node** → lodestar.sh (when user selects Lodestar)
- **Rust** → ethrex.sh, install_ethgas.sh (when user selects those)
- **Bazel** → fb_mev_prysm.sh (when user selects Prysm builder)
- **certbot** → install_ssl_certbot.sh (when user runs SSL setup)

---

## Current Architecture (Implemented)

- **run_1** installs system-wide base + production packages (aide, cron, fail2ban, nginx, chrony, etc.) before `consolidated_security.sh` configures them. Client-specific deps (geth, Node, Rust, Bazel, certbot) are **not** in run_1.
- **run_2** verifies dependencies exist; no install. Client scripts install their deps when selected.
- **chrony** only — `timedatectl set-ntp` would enable systemd-timesyncd and conflict; not used.
