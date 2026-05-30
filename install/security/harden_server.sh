#!/bin/bash

# Standalone Server Hardening Script
# This script can run independently on any server without requiring Phase 1 setup
# It modularizes all hardening components with safety features and skip options
#
# Usage:
#   ./harden_server.sh                    # Interactive mode with all hardening
#   ./harden_server.sh --dry-run          # Preview changes without applying
#   ./harden_server.sh --preserve-port    # Keep current SSH port
#   ./harden_server.sh --skip-ssh         # Skip SSH hardening
#   ./harden_server.sh --non-interactive  # Run without prompts

set -Eeuo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source required files
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Load hardening-specific configuration
if [[ -f "$SCRIPT_DIR/harden_config.env" ]]; then
    source "$SCRIPT_DIR/harden_config.env"
fi

# Default values (can be overridden by flags or environment)
HARDEN_SSH="${HARDEN_SSH:-true}"
PRESERVE_SSH_PORT="${PRESERVE_SSH_PORT:-false}"
SSH_PORT="${SSH_PORT:-$YourSSHPortNumber}"
HARDEN_FIREWALL="${HARDEN_FIREWALL:-true}"
HARDEN_FAIL2BAN="${HARDEN_FAIL2BAN:-true}"
HARDEN_SNORT="${HARDEN_SNORT:-$ENABLE_SNORT}"
HARDEN_AIDE="${HARDEN_AIDE:-true}"
HARDEN_NETWORK="${HARDEN_NETWORK:-true}"
HARDEN_MONITORING="${HARDEN_MONITORING:-true}"
DRY_RUN="${DRY_RUN:-false}"
INTERACTIVE="${INTERACTIVE:-true}"
BACKUP_CONFIGS="${BACKUP_CONFIGS:-true}"
VALIDATE_AFTER="${VALIDATE_AFTER:-true}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --preserve-port)
            PRESERVE_SSH_PORT=true
            shift
            ;;
        --skip-ssh)
            HARDEN_SSH=false
            shift
            ;;
        --skip-firewall)
            HARDEN_FIREWALL=false
            shift
            ;;
        --skip-fail2ban)
            HARDEN_FAIL2BAN=false
            shift
            ;;
        --skip-snort)
            HARDEN_SNORT=false
            shift
            ;;
        --skip-aide)
            HARDEN_AIDE=false
            shift
            ;;
        --skip-network)
            HARDEN_NETWORK=false
            shift
            ;;
        --skip-monitoring)
            HARDEN_MONITORING=false
            shift
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        --help|-h)
            cat << EOF
Standalone Server Hardening Script

Usage: $0 [OPTIONS]

Options:
  --dry-run              Preview changes without applying them
  --preserve-port        Keep current SSH port (don't change it)
  --skip-ssh             Skip SSH hardening
  --skip-firewall        Skip firewall hardening
  --skip-fail2ban        Skip fail2ban hardening
  --skip-snort           Skip Snort IDS installation
  --skip-aide            Skip AIDE file integrity monitoring
  --skip-network         Skip network security hardening
  --skip-monitoring      Skip security monitoring setup
  --non-interactive      Run without confirmation prompts
  --help, -h             Show this help message

Environment Variables:
  HARDEN_SSH             Enable/disable SSH hardening (default: true)
  PRESERVE_SSH_PORT      Keep current SSH port (default: false)
  SSH_PORT               Target SSH port (default: from exports.sh)
  HARDEN_FIREWALL        Enable/disable firewall (default: true)
  DRY_RUN                Preview mode (default: false)
  INTERACTIVE            Interactive prompts (default: true)

Examples:
  # Interactive mode with all hardening
  sudo $0

  # Preview changes without applying
  sudo $0 --dry-run

  # Harden everything except SSH port change
  sudo $0 --preserve-port

  # Skip SSH hardening entirely
  sudo $0 --skip-ssh

  # Non-interactive mode (automated)
  sudo $0 --non-interactive --preserve-port

EOF
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Require root for security operations
require_root

# Detect current SSH port if preserving
detect_current_ssh_port() {
    local current_port
    current_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
    echo "$current_port"
}

# Backup configuration file
backup_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        return 0
    fi
    
    local backup_dir="/root/backups/hardening_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    local backup_file="$backup_dir/$(basename "$config_file").backup"
    cp "$config_file" "$backup_file"
    log_info "Backed up $config_file to $backup_file"
}

# Restore configuration from backup
restore_config() {
    local config_file="$1"
    local backup_file="$2"
    
    if [[ -f "$backup_file" ]]; then
        cp "$backup_file" "$config_file"
        log_info "Restored $config_file from $backup_file"
        return 0
    else
        log_error "Backup file not found: $backup_file"
        return 1
    fi
}

# SSH Hardening Module
harden_ssh() {
    if [[ "$HARDEN_SSH" != "true" ]]; then
        log_info "Skipping SSH hardening (disabled)"
        return 0
    fi

    log_info "=== SSH Hardening Module ==="
    
    local current_ssh_port
    current_ssh_port=$(detect_current_ssh_port)
    log_info "Current SSH port: $current_ssh_port"
    
    if [[ "$PRESERVE_SSH_PORT" == "true" ]]; then
        SSH_PORT="$current_ssh_port"
        log_info "Preserving current SSH port: $SSH_PORT"
    else
        log_info "Target SSH port: $SSH_PORT"
        if [[ "$SSH_PORT" != "$current_ssh_port" ]]; then
            log_warn "WARNING: Changing SSH port from $current_ssh_port to $SSH_PORT"
            log_warn "Ensure you can connect on port $SSH_PORT before running this"
        fi
    fi
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "SSH Hardening" "Configure SSH hardening on port $SSH_PORT?\n\nThis will:\n- Deploy hardened SSH configuration\n- Set SSH banner\n- Change port to $SSH_PORT (unless preserved)\n\nContinue?" 12 70; then
            log_info "SSH hardening skipped by user"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure SSH hardening on port $SSH_PORT"
        return 0
    fi
    
    if [[ "$BACKUP_CONFIGS" == "true" ]]; then
        backup_config /etc/ssh/sshd_config
    fi
    
    # Use existing configure_ssh function
    if configure_ssh "$SSH_PORT" "$PROJECT_ROOT"; then
        log_info "✓ SSH hardening completed"
        
        if [[ "$VALIDATE_AFTER" == "true" ]]; then
            if sshd -t 2>/dev/null; then
                log_info "✓ SSH configuration validated"
            else
                log_error "✗ SSH configuration validation failed"
                return 1
            fi
        fi
    else
        log_error "✗ SSH hardening failed"
        return 1
    fi
}

# Firewall Hardening Module
harden_firewall() {
    if [[ "$HARDEN_FIREWALL" != "true" ]]; then
        log_info "Skipping firewall hardening (disabled)"
        return 0
    fi

    log_info "=== Firewall Hardening Module ==="
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "Firewall Hardening" "Configure UFW firewall with security rules?\n\nThis will:\n- Set default deny incoming, allow outgoing\n- Open SSH port $SSH_PORT\n- Configure chain-specific ports\n- Block outbound to private networks\n\nContinue?" 12 70; then
            log_info "Firewall hardening skipped by user"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure UFW firewall"
        return 0
    fi
    
    # Use existing consolidated_security.sh for firewall
    # We'll call just the firewall function if we extract it, or call the whole script
    log_info "Running consolidated security setup (includes firewall)..."
    chmod +x "$SCRIPT_DIR/consolidated_security.sh"
    "$SCRIPT_DIR/consolidated_security.sh"
}

# Fail2ban Hardening Module
harden_fail2ban() {
    if [[ "$HARDEN_FAIL2BAN" != "true" ]]; then
        log_info "Skipping fail2ban hardening (disabled)"
        return 0
    fi

    log_info "=== Fail2ban Hardening Module ==="
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would configure fail2ban"
        return 0
    fi
    
    # Fail2ban is included in consolidated_security.sh
    # This is a placeholder for if we extract it separately
    log_info "Fail2ban hardening included in consolidated security"
}

# Snort IDS Module
harden_snort() {
    if [[ "$HARDEN_SNORT" != "true" ]]; then
        log_info "Skipping Snort IDS (disabled)"
        return 0
    fi

    log_info "=== Snort IDS Module ==="
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "Snort IDS" "Install and configure Snort intrusion detection?\n\nThis will:\n- Install Snort and rules\n- Configure network interface\n- Set up IDS monitoring\n\nContinue?" 12 70; then
            log_info "Snort IDS skipped by user"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would install and configure Snort IDS"
        return 0
    fi
    
    # Snort is included in consolidated_security.sh
    log_info "Snort IDS included in consolidated security"
}

# AIDE Module
harden_aide() {
    if [[ "$HARDEN_AIDE" != "true" ]]; then
        log_info "Skipping AIDE file integrity monitoring (disabled)"
        return 0
    fi

    log_info "=== AIDE File Integrity Monitoring Module ==="
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "AIDE Monitoring" "Install and configure AIDE file integrity monitoring?\n\nThis will:\n- Install AIDE package\n- Initialize integrity database\n- Schedule daily checks\n\nContinue?" 12 70; then
            log_info "AIDE monitoring skipped by user"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would install and configure AIDE"
        return 0
    fi
    
    # AIDE is included in consolidated_security.sh
    log_info "AIDE monitoring included in consolidated security"
}

# Network Security Module
harden_network() {
    if [[ "$HARDEN_NETWORK" != "true" ]]; then
        log_info "Skipping network security hardening (disabled)"
        return 0
    fi

    log_info "=== Network Security Hardening Module ==="
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "Network Security" "Apply network security hardening?\n\nThis will:\n- Restrict shared memory\n- Disable unnecessary services\n- Configure kernel security parameters\n- Apply sysctl hardening\n\nContinue?" 12 70; then
            log_info "Network security hardening skipped by user"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would apply network security hardening"
        return 0
    fi
    
    # Use existing apply_network_security function
    if apply_network_security; then
        log_info "✓ Network security hardening completed"
    else
        log_error "✗ Network security hardening failed"
        return 1
    fi
}

# Security Monitoring Module
harden_monitoring() {
    if [[ "$HARDEN_MONITORING" != "true" ]]; then
        log_info "Skipping security monitoring setup (disabled)"
        return 0
    fi

    log_info "=== Security Monitoring Module ==="
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "Security Monitoring" "Set up security monitoring?\n\nThis will:\n- Install security monitoring script\n- Configure cron job for periodic checks\n- Set up log rotation\n\nContinue?" 12 70; then
            log_info "Security monitoring skipped by user"
            return 0
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would set up security monitoring"
        return 0
    fi
    
    # Use existing setup_security_monitoring function
    if setup_security_monitoring; then
        log_info "✓ Security monitoring setup completed"
    else
        log_error "✗ Security monitoring setup failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "=== Standalone Server Hardening ==="
    log_info "Project root: $PROJECT_ROOT"
    log_info "Dry-run mode: $DRY_RUN"
    log_info "Interactive mode: $INTERACTIVE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "DRY-RUN MODE: No changes will be applied"
    fi
    
    # Display configuration
    echo ""
    log_info "Configuration:"
    log_info "  SSH Hardening: $HARDEN_SSH (port: $SSH_PORT, preserve: $PRESERVE_SSH_PORT)"
    log_info "  Firewall: $HARDEN_FIREWALL"
    log_info "  Fail2ban: $HARDEN_FAIL2BAN"
    log_info "  Snort IDS: $HARDEN_SNORT"
    log_info "  AIDE: $HARDEN_AIDE"
    log_info "  Network Security: $HARDEN_NETWORK"
    log_info "  Security Monitoring: $HARDEN_MONITORING"
    echo ""
    
    if [[ "$INTERACTIVE" == "true" ]]; then
        if ! whiptail_yesno "Confirm Hardening" "Proceed with server hardening using the above configuration?" 10 60; then
            log_info "Hardening cancelled by user"
            exit 0
        fi
    fi
    
    # Run hardening modules
    local failed_modules=()
    
    harden_ssh || failed_modules+=("SSH")
    harden_firewall || failed_modules+=("Firewall")
    harden_fail2ban || failed_modules+=("Fail2ban")
    harden_snort || failed_modules+=("Snort")
    harden_aide || failed_modules+=("AIDE")
    harden_network || failed_modules+=("Network")
    harden_monitoring || failed_modules+=("Monitoring")
    
    # Summary
    echo ""
    log_info "=== Hardening Summary ==="
    
    if [[ ${#failed_modules[@]} -eq 0 ]]; then
        log_info "✓ All hardening modules completed successfully"
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "This was a dry-run - no changes were applied"
        else
            log_info "Server hardening completed"
        fi
        exit 0
    else
        log_error "✗ Some hardening modules failed:"
        for module in "${failed_modules[@]}"; do
            log_error "  - $module"
        done
        exit 1
    fi
}

# Run main function
main "$@"