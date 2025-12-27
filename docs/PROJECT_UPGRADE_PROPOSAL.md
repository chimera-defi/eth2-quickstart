# Eth2 Quick Start Upgrade Proposal: "The Ethereum Validator Flywheel"

## 1. High-Level Overview
We propose transforming the "Eth2 Quick Start" from a repository of scripts into a **polished, product-like experience** inspired by the "Agentic Coding Flywheel". The goal is to make setting up an Ethereum node as simple as running a single command, while retaining the flexibility and security of the underlying shell scripts.

**The Core Promise:** "From zero to a fully-secured, high-performance Ethereum Validator in 15 minutes."

**Key Features of the Upgrade:**
*   **One-Liner Installation:** `curl -sL https://eth2-quickstart.com/install.sh | bash`
*   **Interactive "Wizard" (TUI):** A terminal-based guide that configures everything for you—no manual file editing required.
*   **"Vibe Mode" (Quick Start):** A one-click path for users who want the "best practices" defaults (e.g., Geth + Lighthouse + MEV-Boost) without getting bogged down in details.
*   **Idempotency & Robustness:** Scripts that can be re-run safely to fix issues or update components.
*   **Marketing-Ready Website:** A clean, professional landing page that instills confidence.

## 2. Architecture Upgrade

### Current Flow
1.  Git Clone.
2.  Manual `nano exports.sh` editing.
3.  Run `run_1.sh` (System Setup).
4.  Reboot.
5.  Run `run_2.sh` (Client Setup) - but user often has to manually select scripts.

### New "Flywheel" Flow
1.  **Bootstrap:** User runs `curl | bash`.
    *   This script verifies requirements (RAM, Disk, OS).
    *   Installs minimal dependencies (`git`, `whiptail`/`dialog`).
    *   Clones the repo to `~/.eth2-quickstart`.
2.  **Configuration Wizard (The "Manifest" Generator):**
    *   Runs immediately after clone.
    *   Asks high-level questions:
        *   Network? (Mainnet/Holesky)
        *   Hardware Level? (Low/Mid/High) -> Auto-selects clients or prompts for choice.
        *   MEV? (Yes/No/Commit-Boost)
        *   External Access? (Nginx/Caddy/None)
    *   **Generates:** `config/user_config.env` (persisted state) and `install_manifest.sh`.
3.  **Execution (The "Installer"):**
    *   Reads `install_manifest.sh`.
    *   Executes `run_1.sh` (System Hardening) non-interactively.
    *   Executes selected Client Installers (e.g., `install/execution/geth.sh`) non-interactively using variables from `user_config.env`.
    *   Sets up Systemd services.
4.  **Verification:**
    *   Runs a `doctor` script to verify ports, services, and sync status.
    *   Prints a "Success Summary" with next steps (e.g., "Deposit 32 ETH here...").

## 3. Website & Marketing Copy

**Domain:** `eth2-quickstart.io` (example)
**Theme:** Minimalist, Dark Mode, Terminal-aesthetic (Green/Purple).

### Hero Section
**Headline:** Deploy Your Ethereum Validator. Fast. Secure. Sovereign.
**Subheadline:** Transform any fresh Ubuntu VPS into a production-grade Ethereum node with one command.
**CTA:**
```bash
curl -fsSL https://eth2-quickstart.io/install.sh | bash
```

### "Why Use This?" (Value Props)
1.  **Zero to Hero:** Don't spend 2 days reading documentation. Get running in 15 minutes.
2.  **Security First:** Hardened firewall, fail2ban, non-root users, and secure permissions by default.
3.  **Client Diversity:** Easy access to minority clients (Nimbus, Teku, Besu) to support network health.
4.  **MEV Ready:** Pre-configured for MEV-Boost or Commit-Boost to maximize your rewards.
5.  **Agentic Architecture:** Built with modularity and automation in mind.

### "How It Works" (Visual Flow)
`[Fresh VPS]` -> `[One-Liner]` -> `[Wizard]` -> `[Validator Running]`

### Testimonials / Trust
*   "Saved me 48 hours of configuration."
*   "The easiest way to run a minority client."
*   (Include GitHub Stars/Forks badges)

## 4. Task List

### Phase 1: The Configurator (The "Brain")
- [ ] Create `install/utils/configure.sh`.
    - [ ] Implement TUI using `whiptail` (pre-installed on Ubuntu) or pure bash `read`.
    - [ ] Map user answers to `exports.sh` variables.
    - [ ] Logic to recommend clients based on hardware.
- [ ] Create `install/utils/generate_manifest.sh`.
    - [ ] Creates a list of scripts to run based on configuration.

### Phase 2: The One-Liner (The "Entry Point")
- [ ] Create `install.sh` (root of repo, or strictly for web hosting).
    - [ ] Checks OS/RAM/Disk.
    - [ ] `git clone` if not present.
    - [ ] Hands off to `configure.sh`.
- [ ] Update `run_1.sh` and `run_2.sh` to accept non-interactive flags or read from `user_config.env` without prompting.

### Phase 3: Refinement & "Vibe Mode"
- [ ] Implement `--quick` or `--vibe` flag for `install.sh` to skip questions and use sensible defaults (Geth/Lighthouse/MEV-Boost).
- [ ] Add `doctor.sh` for post-install verification.
- [ ] Polish status outputs (colors, progress bars).

### Phase 4: Documentation & Web
- [ ] Build the static website (GitHub Pages).
- [ ] Update README to point to the One-Liner.
- [ ] Create "Cheat Sheet" for post-install management (updating, checking logs).

