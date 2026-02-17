#!/bin/bash
# Debconf pre-seeding - single source for non-interactive apt/dpkg
# Used by: run_1.sh (production), test/Dockerfile (build), test/ci_test_e2e.sh (Phase 1 and 2 E2E)
# Prevents hangs on postfix, cron, tzdata, needrestart during install/upgrade
#
# Note: Postfix is NOT needed for Ethereum nodes. We avoid it via --no-install-recommends
# in install_dependencies. This preseed is a fallback if apt upgrade pulls it in as a
# dependency - "Local only" means no SMTP, no mailbox config, minimal footprint.

set -Eeuo pipefail

# postfix - skip config entirely if pulled in by apt (No configuration = no config screen)
# Use both select and string - package may use either depending on version
echo "postfix postfix/mailname string localhost" | debconf-set-selections 2>/dev/null || true
echo "postfix postfix/main_mailer_type select No configuration" | debconf-set-selections 2>/dev/null || true
echo "postfix postfix/main_mailer_type string No configuration" | debconf-set-selections 2>/dev/null || true

# cron - whether to mail cron output
echo "cron cron/upgrade_available boolean false" | debconf-set-selections 2>/dev/null || true
echo "cron cron/upgrade_available_seen boolean true" | debconf-set-selections 2>/dev/null || true

# tzdata - timezone (chrony depends on this; default UTC)
echo "tzdata tzdata/Areas select Etc" | debconf-set-selections 2>/dev/null || true
echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections 2>/dev/null || true
echo "tzdata tzdata/Areas string Etc" | debconf-set-selections 2>/dev/null || true
echo "tzdata tzdata/Zones/Etc string UTC" | debconf-set-selections 2>/dev/null || true

# needrestart - suppress interactive TUI (Ubuntu 22.04+)
# The debconf setting alone does NOT prevent the TUI; we must also configure needrestart directly
echo "needrestart needrestart/restart-services string" | debconf-set-selections 2>/dev/null || true
# Set automatic restart mode in needrestart config (a=automatic, skips TUI and polkit auth)
mkdir -p /etc/needrestart/conf.d
cat <<'CONF' > /etc/needrestart/conf.d/50-autorestart.conf 2>/dev/null || true
$nrconf{restart} = 'a';
CONF

# dpkg: use defaults, never prompt for config file changes
mkdir -p /etc/apt/apt.conf.d
printf '%s\n' 'DPkg::options { "--force-confdef"; "--force-confold"; };' > /etc/apt/apt.conf.d/99local-noninteractive
