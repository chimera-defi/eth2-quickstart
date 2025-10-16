#!/bin/bash

# Ethereum Data Purge Script
# Safely removes all Ethereum client data directories and files
# Allows clean switching between different client configurations
# Usage: ./purge_ethereum_data.sh [--confirm] [--backup] [--dry-run]

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common_functions.sh"

# Source exports for configuration
if [[ -f "$SCRIPT_DIR/../../exports.sh" ]]; then
    source "$SCRIPT_DIR/../../exports.sh"
else
    # Fallback if exports.sh not found
    export LOGIN_UNAME="eth"
fi

# Script configuration
SCRIPT_NAME="Ethereum Data Purge"
VERSION="1.0.0"
BACKUP_DIR="$HOME/ethereum-data-backups"
DRY_RUN=false
CREATE_BACKUP=false
CONFIRM_ACTION=false

# Data directories for different clients
declare -A EXECUTION_DATA_DIRS=(
    ["geth"]="$HOME/.ethereum"
    ["nethermind"]="$HOME/.local/share/nethermind"
    ["besu"]="$HOME/.local/share/besu"
    ["erigon"]="$HOME/.local/share/erigon"
    ["reth"]="$HOME/.local/share/reth"
)

declare -A CONSENSUS_DATA_DIRS=(
    ["prysm"]="$HOME/.local/share/prysm"
    ["lighthouse"]="$HOME/.lighthouse"
    ["teku"]="$HOME/.local/share/teku"
    ["nimbus"]="$HOME/.local/share/nimbus"
    ["lodestar"]="$HOME/.local/share/lodestar"
    ["grandine"]="$HOME/.local/share/grandine"
)

# Client-specific directories
declare -A CLIENT_DIRS=(
    ["prysm"]="$HOME/prysm"
    ["lighthouse"]="$HOME/lighthouse"
    ["teku"]="$HOME/teku"
    ["nimbus"]="$HOME/nimbus"
    ["lodestar"]="$HOME/lodestar"
    ["grandine"]="$HOME/grandine"
    ["nethermind"]="$HOME/nethermind"
    ["besu"]="$HOME/besu"
    ["erigon"]="$HOME/erigon"
    ["reth"]="$HOME/reth"
    ["mev-boost"]="$HOME/mev-boost"
)

# Common directories to clean
COMMON_DIRS=(
    "$HOME/secrets"
    "$HOME/.cargo"  # Rust toolchain (if only used for Ethereum)
    "$HOME/eth2-quickstart-backups"
)

# Systemd services to stop
SERVICES=(
    "eth1"
    "cl"
    "validator"
    "mev"
    "nginx"
)

# Function to show usage
show_usage() {
    cat << EOF
$SCRIPT_NAME v$VERSION

Safely removes all Ethereum client data directories and files to allow
clean switching between different client configurations.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --confirm          Skip confirmation prompt (use with caution)
    --backup           Create backup before purging (recommended)
    --dry-run          Show what would be deleted without actually deleting
    --help, -h         Show this help message
    --version, -v      Show version information

EXAMPLES:
    # Dry run to see what would be deleted
    $0 --dry-run

    # Create backup and purge with confirmation
    $0 --backup

    # Purge without backup (use with caution)
    $0 --confirm

    # Full backup and purge
    $0 --backup --confirm

WARNING:
    This script will permanently delete all Ethereum client data including:
    - Blockchain data (can be re-synced)
    - Validator keys and wallets (ensure you have backups!)
    - Client configurations
    - Logs and temporary files

    Always backup important data before running this script.

EOF
}

# Function to show version
show_version() {
    echo "$SCRIPT_NAME v$VERSION"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --confirm)
                CONFIRM_ACTION=true
                shift
                ;;
            --backup)
                CREATE_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                show_version
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to check if directory exists and has content
check_directory() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        if [[ -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
            return 0  # Directory exists and has content
        fi
    fi
    return 1  # Directory doesn't exist or is empty
}

# Function to get directory size
get_directory_size() {
    local dir="$1"
    if check_directory "$dir"; then
        du -sh "$dir" 2>/dev/null | cut -f1
    else
        echo "0B"
    fi
}

# Function to create backup
create_backup() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/ethereum_data_backup_$timestamp"
    
    log_info "Creating backup at: $backup_path"
    ensure_directory "$backup_path"
    
    # Backup execution client data
    for client in "${!EXECUTION_DATA_DIRS[@]}"; do
        local data_dir="${EXECUTION_DATA_DIRS[$client]}"
        if check_directory "$data_dir"; then
            log_info "Backing up $client data: $data_dir"
            cp -r "$data_dir" "$backup_path/$(basename "$data_dir")_$client" 2>/dev/null || true
        fi
    done
    
    # Backup consensus client data
    for client in "${!CONSENSUS_DATA_DIRS[@]}"; do
        local data_dir="${CONSENSUS_DATA_DIRS[$client]}"
        if check_directory "$data_dir"; then
            log_info "Backing up $client data: $data_dir"
            cp -r "$data_dir" "$backup_path/$(basename "$data_dir")_$client" 2>/dev/null || true
        fi
    done
    
    # Backup client directories
    for client in "${!CLIENT_DIRS[@]}"; do
        local client_dir="${CLIENT_DIRS[$client]}"
        if check_directory "$client_dir"; then
            log_info "Backing up $client directory: $client_dir"
            cp -r "$client_dir" "$backup_path/$(basename "$client_dir")_$client" 2>/dev/null || true
        fi
    done
    
    # Backup common directories
    for dir in "${COMMON_DIRS[@]}"; do
        if check_directory "$dir"; then
            log_info "Backing up common directory: $dir"
            cp -r "$dir" "$backup_path/$(basename "$dir")" 2>/dev/null || true
        fi
    done
    
    # Create backup info file
    cat > "$backup_path/backup_info.txt" << EOF
Ethereum Data Backup
Created: $(date)
Script Version: $VERSION
Backup Path: $backup_path

This backup contains all Ethereum client data directories and configurations
that were present at the time of backup creation.

To restore:
1. Stop all Ethereum services
2. Copy the desired directories back to their original locations
3. Restart services

WARNING: This backup may contain sensitive information like private keys.
Ensure it is stored securely and access is restricted.
EOF
    
    log_info "Backup completed: $backup_path"
    log_info "Backup size: $(get_directory_size "$backup_path")"
}

# Function to stop services
stop_services() {
    log_info "Stopping Ethereum services..."
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Stopping $service service..."
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo systemctl stop "$service" || log_warn "Failed to stop $service"
            fi
        else
            log_info "Service $service is not running"
        fi
    done
    
    # Wait a moment for services to stop
    if [[ "$DRY_RUN" == "false" ]]; then
        sleep 3
    fi
}

# Function to show what will be deleted
show_deletion_summary() {
    log_info "=== DELETION SUMMARY ==="
    
    local total_size=0
    local dirs_to_delete=()
    
    # Check execution client data directories
    log_info "Execution Client Data Directories:"
    for client in "${!EXECUTION_DATA_DIRS[@]}"; do
        local data_dir="${EXECUTION_DATA_DIRS[$client]}"
        if check_directory "$data_dir"; then
            local size=$(get_directory_size "$data_dir")
            log_info "  $client: $data_dir ($size)"
            dirs_to_delete+=("$data_dir")
        fi
    done
    
    # Check consensus client data directories
    log_info "Consensus Client Data Directories:"
    for client in "${!CONSENSUS_DATA_DIRS[@]}"; do
        local data_dir="${CONSENSUS_DATA_DIRS[$client]}"
        if check_directory "$data_dir"; then
            local size=$(get_directory_size "$data_dir")
            log_info "  $client: $data_dir ($size)"
            dirs_to_delete+=("$data_dir")
        fi
    done
    
    # Check client directories
    log_info "Client Directories:"
    for client in "${!CLIENT_DIRS[@]}"; do
        local client_dir="${CLIENT_DIRS[$client]}"
        if check_directory "$client_dir"; then
            local size=$(get_directory_size "$client_dir")
            log_info "  $client: $client_dir ($size)"
            dirs_to_delete+=("$client_dir")
        fi
    done
    
    # Check common directories
    log_info "Common Directories:"
    for dir in "${COMMON_DIRS[@]}"; do
        if check_directory "$dir"; then
            local size=$(get_directory_size "$dir")
            log_info "  $(basename "$dir"): $dir ($size)"
            dirs_to_delete+=("$dir")
        fi
    done
    
    if [[ ${#dirs_to_delete[@]} -eq 0 ]]; then
        log_info "No Ethereum data directories found to delete."
        return 0
    fi
    
    log_warn "Total directories to delete: ${#dirs_to_delete[@]}"
    return 1
}

# Function to confirm deletion
confirm_deletion() {
    if [[ "$CONFIRM_ACTION" == "true" ]]; then
        return 0
    fi
    
    echo
    log_warn "WARNING: This will permanently delete all Ethereum client data!"
    log_warn "This includes blockchain data, validator keys, and configurations."
    echo
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        return 0
    else
        log_info "Operation cancelled by user."
        exit 0
    fi
}

# Function to delete directories
delete_directories() {
    local deleted_count=0
    local failed_count=0
    
    # Delete execution client data directories
    for client in "${!EXECUTION_DATA_DIRS[@]}"; do
        local data_dir="${EXECUTION_DATA_DIRS[$client]}"
        if check_directory "$data_dir"; then
            log_info "Deleting $client data: $data_dir"
            if [[ "$DRY_RUN" == "false" ]]; then
                if rm -rf "$data_dir" 2>/dev/null; then
                    ((deleted_count++))
                else
                    log_error "Failed to delete $data_dir"
                    ((failed_count++))
                fi
            else
                log_info "[DRY RUN] Would delete: $data_dir"
                ((deleted_count++))
            fi
        fi
    done
    
    # Delete consensus client data directories
    for client in "${!CONSENSUS_DATA_DIRS[@]}"; do
        local data_dir="${CONSENSUS_DATA_DIRS[$client]}"
        if check_directory "$data_dir"; then
            log_info "Deleting $client data: $data_dir"
            if [[ "$DRY_RUN" == "false" ]]; then
                if rm -rf "$data_dir" 2>/dev/null; then
                    ((deleted_count++))
                else
                    log_error "Failed to delete $data_dir"
                    ((failed_count++))
                fi
            else
                log_info "[DRY RUN] Would delete: $data_dir"
                ((deleted_count++))
            fi
        fi
    done
    
    # Delete client directories
    for client in "${!CLIENT_DIRS[@]}"; do
        local client_dir="${CLIENT_DIRS[$client]}"
        if check_directory "$client_dir"; then
            log_info "Deleting $client directory: $client_dir"
            if [[ "$DRY_RUN" == "false" ]]; then
                if rm -rf "$client_dir" 2>/dev/null; then
                    ((deleted_count++))
                else
                    log_error "Failed to delete $client_dir"
                    ((failed_count++))
                fi
            else
                log_info "[DRY RUN] Would delete: $client_dir"
                ((deleted_count++))
            fi
        fi
    done
    
    # Delete common directories
    for dir in "${COMMON_DIRS[@]}"; do
        if check_directory "$dir"; then
            log_info "Deleting common directory: $dir"
            if [[ "$DRY_RUN" == "false" ]]; then
                if rm -rf "$dir" 2>/dev/null; then
                    ((deleted_count++))
                else
                    log_error "Failed to delete $dir"
                    ((failed_count++))
                fi
            else
                log_info "[DRY RUN] Would delete: $dir"
                ((deleted_count++))
            fi
        fi
    done
    
    # Summary
    if [[ "$DRY_RUN" == "false" ]]; then
        log_info "Deletion completed: $deleted_count directories deleted"
        if [[ $failed_count -gt 0 ]]; then
            log_warn "Failed to delete $failed_count directories"
        fi
    else
        log_info "Dry run completed: $deleted_count directories would be deleted"
    fi
}

# Function to clean up systemd services
cleanup_systemd_services() {
    log_info "Cleaning up systemd services..."
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log_info "Disabling $service service..."
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo systemctl disable "$service" || log_warn "Failed to disable $service"
            else
                log_info "[DRY RUN] Would disable: $service"
            fi
        fi
    done
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo systemctl daemon-reload
        log_info "Systemd daemon reloaded"
    fi
}

# Function to show post-purge instructions
show_post_purge_instructions() {
    log_info "=== POST-PURGE INSTRUCTIONS ==="
    echo
    log_info "Ethereum data has been successfully purged!"
    echo
    log_info "Next steps:"
    log_info "1. Update your exports.sh configuration if needed"
    log_info "2. Run the appropriate installation scripts for your new client setup"
    log_info "3. Start the new services when ready"
    echo
    log_info "Example workflow:"
    log_info "  # Install new execution client"
    log_info "  ./install/execution/install_geth.sh"
    log_info "  # Install new consensus client"
    log_info "  ./install/consensus/install_prysm.sh"
    log_info "  # Start services"
    log_info "  ./install/utils/start.sh"
    echo
    
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        log_info "Backup created at: $BACKUP_DIR"
        log_info "To restore from backup, copy directories back to their original locations"
    fi
}

# Main function
main() {
    log_info "Starting $SCRIPT_NAME v$VERSION"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Check if running as correct user
    check_user "$LOGIN_UNAME"
    
    # Show dry run notice
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No files will be deleted"
    fi
    
    # Show what will be deleted
    if ! show_deletion_summary; then
        log_info "No data to purge."
        exit 0
    fi
    
    # Confirm deletion
    confirm_deletion
    
    # Create backup if requested
    if [[ "$CREATE_BACKUP" == "true" ]]; then
        create_backup
    fi
    
    # Stop services
    stop_services
    
    # Delete directories
    delete_directories
    
    # Clean up systemd services
    cleanup_systemd_services
    
    # Show post-purge instructions
    show_post_purge_instructions
    
    log_info "$SCRIPT_NAME completed successfully!"
}

# Run main function
main "$@"