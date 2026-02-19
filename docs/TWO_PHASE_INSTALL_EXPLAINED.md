# Two-Phase Install: Why and What Goes Where

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

## Current Mistakes (to fix)

1. **geth in run_1** — Only needed when user selects geth. Should be in geth.sh.
2. **Rust in run_1** — Only needed for ethrex/ethgas. Should be in those scripts (rustup, no sudo).
3. **Bazel in run_1** — Only needed for fb_mev_prysm. Should be in that script.
4. **Node in run_1** — Only needed for Lodestar. Should be in lodestar.sh.
5. **certbot in run_1** — Only needed when user runs SSL script. Should be in install_ssl_certbot.sh.
6. **timedatectl** — We install chrony; timedatectl set-ntp enables systemd-timesyncd. Can conflict. Use chrony only.
