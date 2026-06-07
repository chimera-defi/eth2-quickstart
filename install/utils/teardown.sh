#!/bin/bash
# shellcheck source=../../exports.sh
# shellcheck source=../../lib/common_functions.sh

# Teardown Script
# Completely removes all Ethereum client services, processes, and data.
# Run this after testing to return the server to a clean baseline.
#
# Usage: ./teardown.sh [--confirm] [--dry-run]
#   --confirm    Skip confirmation prompt (for scripted use)
#   --dry-run    Show what would happen without making changes
#
# What this does (in order):
#   1. Stops and disables all Ethereum systemd services
#   2. Kills any orphaned client processes not managed by systemd
#   3. Removes systemd unit files and reloads daemon
#   4. Purges all blockchain data directories (via purge_ethereum_data.sh)

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

source "$PROJECT_ROOT/lib/common_functions.sh"
if [[ -f "$PROJECT_ROOT/exports.sh" ]]; then
    source "$PROJECT_ROOT/exports.sh"
fi

# Unit files installed by run_2.sh
UNIT_FILES=(
    "/etc/systemd/system/eth1.service"
    "/etc/systemd/system/cl.service"
    "/etc/systemd/system/validator.service"
    "/etc/systemd/system/mev.service"
    "/etc/systemd/system/commit-boost-pbs.service"
    "/etc/systemd/system/commit-boost-signer.service"
    "/etc/systemd/system/ethgas.service"
)

# Binary names of client processes that may run outside systemd
CLIENT_PROCESS_NAMES=(
    "geth"
    "erigon"
    "reth"
    "Nethermind.Runner"
    "besu"
    "ethrex"
    "prysm.sh"
    "beacon-chain"
    "lighthouse"
    "teku"
    "nimbus_beacon_node"
    "lodestar"
    "grandine"
    "mev-boost"
    "commit-boost"
)

DRY_RUN=false
CONFIRM_ACTION=false

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
        --help|-h)
            echo "Usage: $0 [--confirm] [--dry-run]"
            echo "  --confirm    Skip confirmation prompt"
            echo "  --dry-run    Show what would be done without making changes"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

confirm_teardown() {
    if [[ "$CONFIRM_ACTION" == "true" ]]; then
        return 0
    fi
    log_warn "WARNING: This permanently stops all Ethereum services and deletes all chain data."
    log_warn "Intended for post-testing cleanup. Validator keys in ~/secrets/ are preserved."
    read -rp "Proceed? (yes/no): "
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        return 0
    else
        log_info "Teardown cancelled."
        exit 0
    fi
}

stop_and_disable_services() {
    log_info "Stopping and disabling Ethereum systemd services..."
    # Intentionally excludes ETH_WEB_SERVICES (nginx, caddy) — web servers are
    # optional infrastructure that may serve non-test sites on the same host.
    local teardown_services=("${ETH_CORE_SERVICES[@]}" "${ETH_MEV_SERVICES[@]}")
    local service
    for service in "${teardown_services[@]}"; do
        if service_active "$service"; then
            log_info "Stopping $service..."
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo systemctl stop "$service" || log_warn "Failed to stop $service"
            else
                log_info "[DRY RUN] Would stop: $service"
            fi
        fi
        if service_enabled "$service" 2>/dev/null; then
            log_info "Disabling $service..."
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo systemctl disable "$service" 2>/dev/null || log_warn "Failed to disable $service"
            else
                log_info "[DRY RUN] Would disable: $service"
            fi
        fi
    done
}

kill_orphaned_processes() {
    log_info "Checking for orphaned Ethereum client processes..."
    local name found_any=false
    for name in "${CLIENT_PROCESS_NAMES[@]}"; do
        local pids
        # Linux truncates comm to 15 chars; pgrep -x matches comm exactly.
        # For names longer than 15 chars, fall back to pgrep -f (full cmdline match).
        if [[ "${#name}" -gt 15 ]]; then
            pids=$(pgrep -f "$name" 2>/dev/null || true)
        else
            pids=$(pgrep -x "$name" 2>/dev/null || true)
        fi
        if [[ -n "$pids" ]]; then
            found_any=true
            log_warn "Orphaned process found: $name (PIDs: $pids)"
            if [[ "$DRY_RUN" == "false" ]]; then
                # shellcheck disable=SC2086
                kill $pids 2>/dev/null || true
                sleep 2
                pids=$(pgrep -x "$name" 2>/dev/null || true)
                if [[ -n "$pids" ]]; then
                    log_warn "Force-killing $name..."
                    # shellcheck disable=SC2086
                    kill -9 $pids 2>/dev/null || true
                fi
            else
                log_info "[DRY RUN] Would kill: $name (PIDs: $pids)"
            fi
        fi
    done
    if [[ "$found_any" == "false" ]]; then
        log_info "No orphaned client processes found."
    fi
}

remove_unit_files() {
    log_info "Removing systemd unit files..."
    local found_any=false unit
    for unit in "${UNIT_FILES[@]}"; do
        if [[ -f "$unit" ]]; then
            found_any=true
            log_info "Removing $unit..."
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo rm -f "$unit" || log_warn "Failed to remove $unit"
            else
                log_info "[DRY RUN] Would remove: $unit"
            fi
        fi
    done
    if [[ "$found_any" == "false" ]]; then
        log_info "No unit files to remove."
    fi
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo systemctl daemon-reload
        log_info "systemd daemon reloaded."
    else
        log_info "[DRY RUN] Would run: systemctl daemon-reload"
    fi
}

purge_data() {
    log_info "Purging Ethereum data directories..."
    local purge_script="$SCRIPT_DIR/purge_ethereum_data.sh"
    if [[ ! -f "$purge_script" ]]; then
        log_error "purge_ethereum_data.sh not found at $purge_script"
        return 1
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        bash "$purge_script" --dry-run
    else
        bash "$purge_script" --confirm
    fi
}

main() {
    log_info "=== eth2-quickstart Teardown ==="
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE — no changes will be made"
    fi

    confirm_teardown
    stop_and_disable_services
    kill_orphaned_processes
    remove_unit_files
    purge_data

    log_info ""
    log_info "=== Teardown complete. Server is clean. ==="
    log_info "Note: Docker images and build cache were NOT removed."
    log_info "To also reclaim Docker space: docker system prune -f"
}

main "$@"
