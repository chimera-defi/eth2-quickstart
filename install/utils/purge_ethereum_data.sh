#!/bin/bash

# Ethereum Data Purge Script
# Removes default Ethereum node data/state directories while preserving keys/secrets
# Usage: ./purge_ethereum_data.sh [--confirm] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# Source common functions
source "$PROJECT_ROOT/lib/common_functions.sh"
get_script_directories

# Source exports for configuration
if [[ -f "$PROJECT_ROOT/exports.sh" ]]; then
    source "$PROJECT_ROOT/exports.sh"
fi
export LOGIN_UNAME="${LOGIN_UNAME:-eth}"

# Configuration
DRY_RUN=false
CONFIRM_ACTION=false
HOST_MODE=false

# Default data/state directories to purge
DATA_DIRS=(
    # Execution clients
    "$HOME/.ethereum"                    # Geth
    "$HOME/.local/share/nethermind"      # Nethermind
    "$HOME/.local/share/besu"           # Besu
    "$HOME/.local/share/erigon"         # Erigon
    "$HOME/.local/share/reth"           # Reth
    "$HOME/.local/share/nimbus-eth1"   # Nimbus execution client
    "$HOME/ethrex/data"                 # Ethrex

    # Consensus clients
    "$HOME/.local/share/prysm"          # Prysm data
    "$HOME/.eth2"                       # Prysm data (actual runtime path)
    "$HOME/.lighthouse"                 # Lighthouse
    "$HOME/.local/share/teku"           # Teku
    "$HOME/.local/share/nimbus"         # Nimbus
    "$HOME/.local/share/lodestar"       # Lodestar
    "$HOME/.local/share/grandine"       # Grandine
    
    # MEV components with local state/logs
    "$HOME/mev-boost"                   # MEV-Boost
    "$HOME/commit-boost"                # Commit-Boost
    "$HOME/ethgas"                      # ETHGas
)

HOST_DATA_DIRS=(
    "/root/.ethereum"
    "/root/.eth2"
    "/root/prysm"
    "/root/lodestar"
    "/root/ethrex"
)

# Paths that are always preserved (keys, secrets, passwords)
PRESERVE_PATHS=(
    "$HOME/secrets"
    "$HOME/.local/share/teku/validator"
    "$HOME/.local/share/nimbus/validators"
    "$HOME/.local/share/lodestar/validators"
    "$HOME/.local/share/grandine/validators"
    "$HOME/.lighthouse/validators"
    "$HOME/.lighthouse/secrets"
    "$HOME/.lighthouse/mainnet/validators"
    "$HOME/.lighthouse/mainnet/secrets"
)

HOST_PRESERVE_PATHS=(
    "/root/secrets"
    "/root/.eth2/network-keys"
)

# Services to manage
SERVICES=("${ETH_ALL_SERVICES[@]}")

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --confirm)
            CONFIRM_ACTION=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --host)
            HOST_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--confirm] [--dry-run] [--host]"
            echo "  --confirm    Skip confirmation prompt"
            echo "  --dry-run    Show what would be deleted"
            echo "  --host       Include root-managed custom datadirs and stale client installs"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

append_unique_paths() {
    local array_name="$1"
    shift
    local candidate existing

    for candidate in "$@"; do
        [[ -n "$candidate" ]] || continue
        eval "for existing in \"\${${array_name}[@]}\"; do
            if [[ \"\$existing\" == \"\$candidate\" ]]; then
                continue 2
            fi
        done"
        eval "${array_name}+=(\"\$candidate\")"
    done
}

if [[ "$HOST_MODE" == "true" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "Host cleanup must be run as root."
        exit 1
    fi
    append_unique_paths DATA_DIRS "${HOST_DATA_DIRS[@]}"
    append_unique_paths PRESERVE_PATHS "${HOST_PRESERVE_PATHS[@]}"
else
    check_user "$LOGIN_UNAME"
fi

path_is_preserved() {
    local path="$1"
    local preserve
    for preserve in "${PRESERVE_PATHS[@]}"; do
        if [[ "$path" == "$preserve" ]]; then
            return 0
        fi
    done
    return 1
}

has_preserved_descendant() {
    local path="$1"
    local preserve
    for preserve in "${PRESERVE_PATHS[@]}"; do
        if [[ "$preserve" == "$path/"* ]]; then
            return 0
        fi
    done
    return 1
}

is_key_or_secret_name() {
    local base="$1"
    [[ "$base" =~ ^(secrets?|validators?|keystore|keystores|passwords?|wallet|wallets)$ ]]
}

# Show what will be deleted
show_deletion_summary() {
    log_info "=== DELETION SUMMARY ==="
    local count=0
    
    for dir in "${DATA_DIRS[@]}"; do
        if [[ -d "$dir" && -n "$(find "$dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            log_info "  $dir ($size)"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_info "No Ethereum data directories found to delete."
        return 1
    fi
    
    log_warn "Total directories to delete: $count"
    return 0
}

# Confirm deletion
confirm_deletion() {
    if [[ "$CONFIRM_ACTION" == "true" ]]; then
        return 0
    fi
    
    log_warn "WARNING: This will permanently delete all Ethereum client data!"
    log_warn "This includes blockchain data/state in default directories."
    if [[ "$HOST_MODE" == "true" ]]; then
        log_warn "Host cleanup mode includes root-managed custom datadirs and stale client installs."
    fi
    log_info "Preserving key/secret paths (including ~/secrets and validator keystores)."
    read -p "Are you sure you want to continue? (yes/no): " -r
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        return 0
    else
        log_info "Operation cancelled by user."
        exit 0
    fi
}

# Stop services
stop_services() {
    log_info "Stopping Ethereum services..."
    
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Stopping $service service..."
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo systemctl stop "$service" || log_warn "Failed to stop $service"
            else
                log_info "[DRY RUN] Would stop: $service"
            fi
        fi
    done
}

# Disable services
disable_services() {
    log_info "Disabling Ethereum services..."
    
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
}

# Delete directories
delete_directory_contents_safely() {
    local dir="$1"
    local item
    local base

    # Include dotfiles and skip . and ..
    shopt -s dotglob nullglob
    for item in "$dir"/*; do
        base="$(basename "$item")"
        if [[ "$base" == "." || "$base" == ".." ]]; then
            continue
        fi

        if path_is_preserved "$item" || is_key_or_secret_name "$base"; then
            log_info "Preserving: $item"
            continue
        fi

        if [[ -d "$item" ]] && has_preserved_descendant "$item"; then
            log_info "Descending into protected parent directory: $item"
            delete_directory_contents_safely "$item"
            continue
        fi

        if [[ "$DRY_RUN" == "false" ]]; then
            if ! rm -rf "$item" 2>/dev/null; then
                log_error "Failed to delete $item"
            else
                log_info "Deleted: $item"
            fi
        else
            log_info "[DRY RUN] Would delete: $item"
        fi
    done
    shopt -u dotglob nullglob
}

delete_directories() {
    for dir in "${DATA_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            if path_is_preserved "$dir"; then
                log_info "Preserving protected directory: $dir"
                continue
            fi
            if [[ -n "$(find "$dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
                log_info "Purging contents in: $dir"
                delete_directory_contents_safely "$dir"
            fi
        fi
    done
}

# Main execution
main() {
    log_info "Starting Ethereum Data Purge"
    if [[ "$HOST_MODE" == "true" ]]; then
        log_info "Host cleanup mode enabled: includes root-managed custom datadirs"
    else
        log_info "Default data directories only (custom datadirs are not touched)"
    fi
    log_info "Preserving keys/secrets by design"
    
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
    
    # Stop services
    stop_services
    
    # Delete directories
    delete_directories
    
    # Disable services
    disable_services
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo systemctl daemon-reload
    fi
    
    log_info "Ethereum data purge completed!"
    log_info "You can now install new clients with a clean slate."
}

# Run main function
main "$@"
