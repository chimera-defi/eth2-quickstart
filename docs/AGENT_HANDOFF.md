# Agent Handoff: Eth2 Quick Start Upgrade

## Overview
This document outlines the plan and implementation to transform "Eth2 Quick Start" from a collection of scripts into a cohesive, product-like experience (The "Flywheel").

---

## ⚠️ CRITICAL SECURITY REQUIREMENTS ⚠️

**READ THIS FIRST - DO NOT SKIP**

This project handles **real money** (ETH validators). Security is paramount.

### The Two-Phase Security Model

Installation MUST happen in TWO separate phases with a MANDATORY REBOOT between them:

| Phase | User | Script | Purpose |
|-------|------|--------|---------|
| **Phase 1** | root | `run_1.sh` / `install_phase1.sh` | System hardening, SSH config, new user creation |
| **REBOOT** | - | `sudo reboot` | **MANDATORY** - Security changes require reboot |
| **Phase 2** | new user | `run_2.sh` / `install_phase2.sh` | Ethereum client installation |

### Why This Matters

1. **SSH Hardening**: Phase 1 changes SSH port and disables root login. User MUST verify they can login with new credentials before proceeding.

2. **Privilege Separation**: Phase 1 runs as root for system changes. Phase 2 runs as the new non-root user for application installation.

3. **Security Verification**: The reboot ensures all security changes (firewall, intrusion detection, SSH) are properly applied.

4. **No Rollback Point**: Once Phase 2 starts, the user has committed to the new security model. The reboot forces them to verify access first.

### NEVER Do This

```bash
# ❌ WRONG - Running both phases in one script
./run_1.sh && ./run_2.sh  # DANGEROUS - skips reboot and verification

# ❌ WRONG - Single manifest that chains everything
./install_manifest.sh  # If this runs both phases, it's BROKEN
```

### Always Do This

```bash
# ✅ CORRECT - Two separate phases with reboot
sudo ./install_phase1.sh   # As root
sudo reboot                # MANDATORY
# SSH back in as new user
./install_phase2.sh        # As new user (NOT root)
```

---

## Lessons Learned (Add to this section!)

### 2025-12-28: Two-Phase Model Regression

**Problem**: Initial flywheel implementation generated a single `install_manifest.sh` that ran `run_1.sh` followed immediately by client installation. This BROKE the security model.

**Root Cause**: The reference implementation in this document was flawed - it didn't account for the required reboot between phases.

**Fix**: Configure.sh now generates TWO scripts:
- `install_phase1.sh` - Runs run_1.sh, then STOPS and requires reboot
- `install_phase2.sh` - Runs client installation, refuses to run as root

**Lesson**: Always check existing `run_1.sh` and `run_2.sh` to understand the security flow before creating new installation methods.

### Port Checking Fallback

**Problem**: `doctor.sh` used `ss` command which isn't available in all environments.

**Fix**: Implemented fallback chain: `ss` → `netstat` → `/proc/net/tcp`

---

## The Strategy

We are moving from manual configuration (`nano exports.sh`) to an automated "One-Liner" experience (`curl | bash`), while PRESERVING the two-phase security model.

### Core Components

1. **The One-Liner (`install.sh`)**: Bootstraps environment, runs wizard, generates phase scripts
2. **The Wizard (`configure.sh`)**: Interactive TUI, generates TWO phase scripts
3. **Phase 1 Script (`install_phase1.sh`)**: Generated script for system hardening
4. **Phase 2 Script (`install_phase2.sh`)**: Generated script for client installation
5. **The Runner (`run_manifest.sh`)**: Phase-aware executor with logging
6. **The Doctor (`doctor.sh`)**: Health verification

---

## Correct Reference Implementation

### Phase Script Generation (configure.sh)

The wizard MUST generate TWO separate scripts:

```bash
# Phase 1 - System Hardening (run as root)
PHASE1_MANIFEST="$ROOT_DIR/install_phase1.sh"

# Phase 2 - Client Installation (run as new user)
PHASE2_MANIFEST="$ROOT_DIR/install_phase2.sh"
```

### Phase 1 Script Template

```bash
#!/bin/bash
# PHASE 1: System Hardening - MUST run as root
# After completion: REBOOT REQUIRED

set -e

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Phase 1 must be run as root"
    exit 1
fi

# Run system hardening
./run_1.sh

echo "=================================================="
echo "  Phase 1 Complete - REBOOT REQUIRED"
echo "=================================================="
echo ""
echo "1. Save credentials from /root/handoff_info.txt"
echo "2. Reboot: sudo reboot"
echo "3. SSH as NEW user (not root)"
echo "4. Run Phase 2: ./install_phase2.sh"
```

### Phase 2 Script Template

```bash
#!/bin/bash
# PHASE 2: Client Installation - MUST run as new user (NOT root)

set -e

# Verify NOT running as root
if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Phase 2 should NOT be run as root"
    echo "SSH in as the new user created in Phase 1"
    exit 1
fi

# Install clients
./install/utils/install_dependencies.sh
./install/execution/${EXEC_CLIENT}.sh
./install/consensus/${CONS_CLIENT}.sh
./install/mev/install_${MEV_CHOICE}.sh  # if applicable
```

---

## Modifications to `exports.sh`

Add this block to load user configuration:

```bash
# ----------------------------------------------------------------------------
# User Configuration Override
# ----------------------------------------------------------------------------
USER_CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/config/user_config.env"
if [[ -f "$USER_CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$USER_CONFIG_FILE"
fi
```

---

## Pre-Implementation Checklist for Future Agents

Before implementing ANY changes to the installation flow:

- [ ] Read `run_1.sh` - understand what it does (root operations)
- [ ] Read `run_2.sh` - understand what it does (user operations)
- [ ] Verify changes preserve the Phase 1 → REBOOT → Phase 2 flow
- [ ] Test that Phase 1 scripts refuse to continue to Phase 2
- [ ] Test that Phase 2 scripts refuse to run as root
- [ ] Check that generated scripts have clear reboot instructions
- [ ] Run shellcheck on all modified scripts
- [ ] Verify no stubbed code or TODOs remain

---

## Files Reference

| File | Purpose | Run As |
|------|---------|--------|
| `run_1.sh` | Original Phase 1 - system hardening | root |
| `run_2.sh` | Original Phase 2 - client installation | new user |
| `install.sh` | One-liner entry point | root |
| `install/utils/configure.sh` | Configuration wizard | root |
| `install_phase1.sh` | Generated Phase 1 wrapper | root |
| `install_phase2.sh` | Generated Phase 2 wrapper | new user |
| `install/utils/run_manifest.sh` | Phase-aware runner | auto-detect |
| `install/utils/doctor.sh` | Health verification | any |

---

## Adding Future Lessons Learned

When you encounter an issue or make a significant fix, ADD IT to the "Lessons Learned" section above with:

1. **Date**: When it happened
2. **Problem**: What went wrong
3. **Root Cause**: Why it happened
4. **Fix**: How you fixed it
5. **Lesson**: What future agents should remember

This ensures institutional knowledge is preserved across agent handoffs.
