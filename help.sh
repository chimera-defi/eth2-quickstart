#!/bin/bash

# Eth2 Quick Start - Help & Tool Discovery
# Reads scripts.manifest and outputs human or Markdown format
# Usage: ./help.sh [--help|-h] [--markdown]
#
# --markdown   Output in Markdown (for agents, docs, LLM consumption)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
MANIFEST="$SCRIPT_DIR/scripts.manifest"

# Source colors
if [[ -f "$SCRIPT_DIR/lib/common_functions.sh" ]]; then
    # shellcheck source=lib/common_functions.sh
    source "$SCRIPT_DIR/lib/common_functions.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
fi

MARKDOWN=false
for arg in "$@"; do
    case "$arg" in
        --markdown|-m)
            MARKDOWN=true
            ;;
        --help|-h)
            echo ""
            echo "Usage: ./help.sh [--help|-h] [--markdown|-m]"
            echo ""
            echo "  --help, -h     Show this usage"
            echo "  --markdown, -m Output in Markdown (for agents, docs)"
            echo ""
            echo "Run without args for human-readable output."
            echo ""
            exit 0
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Parse manifest into arrays: PATHS, CATEGORIES, DESCS, USAGES, FLAGS, REQUIRES
# Format: path :: category :: description :: usage :: flags :: requires
# -----------------------------------------------------------------------------
declare -a PATHS CATEGORIES DESCS USAGES FLAGS REQUIRES

parse_manifest() {
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^\[ ]] && continue
        # Parse with :: delimiter (exactly 6 fields)
        path=$(echo "$line" | awk -F' :: ' '{print $1}')
        category=$(echo "$line" | awk -F' :: ' '{print $2}')
        desc=$(echo "$line" | awk -F' :: ' '{print $3}')
        usage=$(echo "$line" | awk -F' :: ' '{print $4}')
        flags=$(echo "$line" | awk -F' :: ' '{print $5}')
        requires=$(echo "$line" | awk -F' :: ' '{print $6}')
        [[ -z "$path" ]] && continue
        PATHS+=("$path")
        CATEGORIES+=("${category:-}")
        DESCS+=("${desc:-}")
        USAGES+=("${usage:-}")
        FLAGS+=("${flags:-}")
        REQUIRES+=("${requires:-}")
    done < "$MANIFEST"
}

# Category display order and labels
CAT_ORDER=(core maintenance diagnostics configuration optional ssl_web mev security examples)
declare -A CAT_LABELS
CAT_LABELS[core]="CORE INSTALLATION"
CAT_LABELS[maintenance]="MAINTENANCE"
CAT_LABELS[diagnostics]="DIAGNOSTICS"
CAT_LABELS[configuration]="CONFIGURATION"
CAT_LABELS[optional]="OPTIONAL & ADVANCED"
CAT_LABELS[ssl_web]="SSL & WEB"
CAT_LABELS[mev]="MEV"
CAT_LABELS[security]="SECURITY VERIFICATION"
CAT_LABELS[examples]="EXAMPLES"

# -----------------------------------------------------------------------------
# Markdown output (for agents)
# -----------------------------------------------------------------------------
output_markdown() {
    echo "# Eth2 Quick Start - Tools & Scripts Reference"
    echo ""
    echo "## Two-Phase Installation"
    echo ""
    echo "This project uses a secure **two-phase model**. You MUST reboot between phases."
    echo ""
    echo "| Phase | Script | User | Action |"
    echo "|-------|--------|------|--------|"
    echo "| 1 | \`run_1.sh\` or \`install_phase1.sh\` | root | System hardening, create user, **then reboot** |"
    echo "| 2 | \`run_2.sh\` or \`install_phase2.sh\` | non-root | Client installation |"
    echo ""
    echo "**Paths:** One-liner: \`install.sh\` → \`install_phase1.sh\` → reboot → \`install_phase2.sh\`. Direct: \`run_1.sh\` → reboot → \`run_2.sh\`."
    echo ""
    echo "## Post-Install: Keep Your Node Healthy"
    echo ""
    echo "These are the scripts you'll use most after install:"
    echo ""
    echo "| Script | Purpose |"
    echo "|--------|---------|"
    echo "| \`./install/utils/doctor.sh\` | Health check: is everything OK? |"
    echo "| \`./install/utils/stats.sh\` | Client versions, service status, errors |"
    echo "| \`./install/utils/view_logs.sh\` | Inspect logs (\`--run2 -f\` to follow) |"
    echo "| \`./install/utils/refresh.sh\` | Restart all services |"
    echo "| \`./install/utils/start.sh\` | Start services after reboot |"
    echo "| \`./install/utils/update.sh\` | Update Ethereum clients |"
    echo ""
    echo "---"
    echo ""

    parse_manifest

    for cat in "${CAT_ORDER[@]}"; do
        [[ -z "${CAT_LABELS[$cat]:-}" ]] && continue
        echo "## ${CAT_LABELS[$cat]}"
        echo ""
        for i in "${!PATHS[@]}"; do
            [[ "${CATEGORIES[$i]}" != "$cat" ]] && continue
            echo "### \`${PATHS[$i]}\`"
            echo ""
            echo "- **Description:** ${DESCS[$i]}"
            echo "- **Usage:** \`${USAGES[$i]}\`"
            [[ -n "${FLAGS[$i]}" ]] && echo "- **Flags:** \`${FLAGS[$i]}\`"
            [[ -n "${REQUIRES[$i]}" ]] && echo "- **Requires:** ${REQUIRES[$i]}"
            echo ""
        done
    done

    echo "---"
    echo ""
    echo "## System Commands (not scripts)"
    echo ""
    echo "| Command | Purpose |"
    echo "|---------|---------|"
    echo "| \`sudo systemctl start eth1 cl validator mev\` | Start all node services |"
    echo "| \`sudo systemctl stop eth1 cl validator mev\` | Stop all node services |"
    echo "| \`sudo systemctl status eth1 cl validator mev\` | Check service status |"
    echo "| \`sudo journalctl -fu eth1\` | Follow execution client logs |"
    echo "| \`sudo journalctl -fu cl\` | Follow consensus client logs |"
    echo ""
    echo "## Configuration"
    echo ""
    echo "- **exports.sh** - Main config (email, domain, fee recipient, graffiti, relays)"
    echo "- **config/user_config.env** - User overrides (after configure.sh)"
    echo ""
    echo "## Best Practices"
    echo ""
    echo "1. **Always add SSH key before Phase 1:** \`ssh-copy-id root@<server>\` - prevents lockout"
    echo "2. **Never skip the reboot** between Phase 1 and Phase 2 - verifies SSH access"
    echo "3. **Run doctor after install:** \`./install/utils/doctor.sh\` - validates setup"
    echo "4. **Use --backup when updating:** \`./install/utils/update_all.sh --backup\`"
    echo "5. **Non-interactive run_2:** \`./run_2.sh --execution=geth --consensus=prysm --mev=mev-boost\`"
    echo "6. **Check logs on issues:** \`./install/utils/view_logs.sh --run2 -f\`"
    echo "7. **Purge is destructive:** Use \`--dry-run\` first with purge_ethereum_data.sh"
    echo ""
}

# -----------------------------------------------------------------------------
# Human-readable output
# -----------------------------------------------------------------------------
output_human() {
    echo ""
    echo -e "${BOLD}${GREEN}====================================================${NC}"
    echo -e "${BOLD}${GREEN}  Eth2 Quick Start - Tools & Scripts Reference${NC}"
    echo -e "${BOLD}${GREEN}====================================================${NC}"
    echo ""

    echo -e "${BOLD}${YELLOW}▼ TWO-PHASE INSTALLATION${NC}"
    echo -e "${YELLOW}This project uses a secure two-phase model. You MUST reboot between phases.${NC}"
    echo ""
    echo "  Phase 1 (as root):"
    echo "    • System hardening (SSH, firewall, fail2ban, AIDE)"
    echo "    • Creates secure non-root user"
    echo "    • Copies repo to user's home"
    echo -e "    • ${RED}Ends with mandatory reboot${NC}"
    echo ""
    echo "  Phase 2 (as new user, after reboot):"
    echo "    • Installs execution + consensus clients"
    echo "    • Optional MEV (MEV-Boost or Commit-Boost)"
    echo "    • Health check"
    echo ""
    echo "  Two ways to run:"
    echo "    A) One-liner:  curl ... | sudo bash  →  install_phase1.sh  →  reboot  →  install_phase2.sh"
    echo "    B) Direct:     git clone  →  run_1.sh  →  reboot  →  run_2.sh"
    echo ""

    echo -e "${BOLD}${GREEN}▼ POST-INSTALL: KEEP YOUR NODE HEALTHY${NC}"
    echo ""
    echo "  These are the scripts you'll use most after install:"
    echo ""
    echo "    ./install/utils/doctor.sh     Is everything OK? (health check)"
    echo "    ./install/utils/stats.sh     What's the status? (versions, errors)"
    echo "    ./install/utils/view_logs.sh Something wrong? Show me logs (--run2 -f)"
    echo "    ./install/utils/refresh.sh   Restart all services"
    echo "    ./install/utils/start.sh     Start services after reboot"
    echo "    ./install/utils/update.sh    Update clients"
    echo ""

    parse_manifest

    for cat in "${CAT_ORDER[@]}"; do
        [[ -z "${CAT_LABELS[$cat]:-}" ]] && continue
        echo -e "${BOLD}${BLUE}▼ ${CAT_LABELS[$cat]}${NC}"
        echo ""
        for i in "${!PATHS[@]}"; do
            [[ "${CATEGORIES[$i]}" != "$cat" ]] && continue
            printf "  %-40s %s\n" "${PATHS[$i]}" "${DESCS[$i]}"
        done
        echo ""
    done

    echo -e "${BOLD}${GREEN}▼ QUICK REFERENCE${NC}"
    echo ""
    echo "  Service control:  sudo systemctl [start|stop|restart|status] eth1 cl validator mev"
    echo "  Config file:      exports.sh (and config/user_config.env after configure)"
    echo "  Docs:             docs/README.md, docs/SCRIPTS.md, docs/WORKFLOW.md"
    echo ""
    echo -e "${BOLD}${YELLOW}▼ BEST PRACTICES${NC}"
    echo ""
    echo "  1. Add SSH key before Phase 1: ssh-copy-id root@<server> (prevents lockout)"
    echo "  2. Never skip the reboot between phases"
    echo "  3. Run doctor after install: ./install/utils/doctor.sh"
    echo "  4. Use --backup when updating: ./install/utils/update_all.sh --backup"
    echo "  5. Non-interactive: ./run_2.sh --execution=geth --consensus=prysm --mev=mev-boost"
    echo "  6. View logs: ./install/utils/view_logs.sh --run2 -f"
    echo ""
    echo -e "  Run ${BOLD}./help.sh${NC} anytime. Use ${BOLD}./help.sh --markdown${NC} for agent-friendly output."
    echo ""
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: scripts.manifest not found at $MANIFEST" >&2
    exit 1
fi

if [[ "$MARKDOWN" == "true" ]]; then
    output_markdown
else
    output_human
fi
