#!/bin/bash
# Live Prysm checkpoint-sync smoke test.
# This is opt-in and intended for environments with systemd + journalctl.

set -Eeuo pipefail

SERVICE_NAME="${SERVICE_NAME:-cl}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-90}"
ENABLE_PRYSM_CHECKPOINT_SMOKE="${ENABLE_PRYSM_CHECKPOINT_SMOKE:-false}"
PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG="${PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG:-true}"
PRYSM_CHECKPOINT_REQUIRE_FALLBACK_LOG="${PRYSM_CHECKPOINT_REQUIRE_FALLBACK_LOG:-false}"

CHECKPOINT_START_PATTERNS=(
    "Checkpoint sync - Downloading origin state and block"
    "Downloaded checkpoint sync state and block."
)
CHECKPOINT_FALLBACK_PATTERN="Origin checkpoint found in the database, ignoring checkpoint sync flags"

log_info() { printf '[INFO] %s\n' "$1"; }
log_warn() { printf '[WARN] %s\n' "$1"; }
log_error() { printf '[ERROR] %s\n' "$1" >&2; }

skip() {
    printf '[SKIP] %s\n' "$1"
    exit 2
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || skip "$1 is not installed"
}

wait_service_active() {
    local svc="$1"
    local timeout="$2"
    local elapsed=0
    while (( elapsed < timeout )); do
        if systemctl is-active --quiet "${svc}.service"; then
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    return 1
}

has_any_checkpoint_start_pattern() {
    local input="$1"
    local pat
    for pat in "${CHECKPOINT_START_PATTERNS[@]}"; do
        if grep -Fq "$pat" <<<"$input"; then
            return 0
        fi
    done
    return 1
}

extract_yaml_value() {
    local key="$1"
    local file="$2"
    sed -n "s/^${key}:[[:space:]]*//p" "$file" | head -n1 | sed 's/^"//; s/"$//'
}

main() {
    if [[ "$ENABLE_PRYSM_CHECKPOINT_SMOKE" != "true" ]]; then
        skip "Set ENABLE_PRYSM_CHECKPOINT_SMOKE=true to run this live smoke test"
    fi

    require_cmd systemctl
    require_cmd journalctl

    if ! systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -Fxq "${SERVICE_NAME}.service"; then
        skip "${SERVICE_NAME}.service is not installed"
    fi

    local exec_start
    exec_start="$(systemctl show -p ExecStart --value "${SERVICE_NAME}.service" 2>/dev/null || true)"
    if ! grep -Fq "prysm.sh beacon-chain" <<<"$exec_start"; then
        skip "${SERVICE_NAME}.service is not a Prysm beacon service"
    fi

    local config_file="$HOME/prysm/prysm_beacon_conf.yaml"
    if [[ ! -f "$config_file" ]]; then
        skip "Missing Prysm beacon config: $config_file"
    fi

    local checkpoint_url genesis_url
    checkpoint_url="$(extract_yaml_value "checkpoint-sync-url" "$config_file")"
    genesis_url="$(extract_yaml_value "genesis-beacon-api-url" "$config_file")"
    [[ -n "$checkpoint_url" ]] || { log_error "checkpoint-sync-url is empty in $config_file"; exit 1; }
    [[ -n "$genesis_url" ]] || { log_error "genesis-beacon-api-url is empty in $config_file"; exit 1; }
    log_info "checkpoint-sync-url configured: $checkpoint_url"
    log_info "genesis-beacon-api-url configured: $genesis_url"

    local saw_start_pattern=false
    local saw_fallback_pattern=false
    local last_restart_logs=""
    local marker logs attempt

    for attempt in 1 2 3; do
        marker="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        log_info "Restart attempt ${attempt}: restarting ${SERVICE_NAME}.service"
        systemctl restart "${SERVICE_NAME}.service"
        if ! wait_service_active "$SERVICE_NAME" "$WAIT_TIMEOUT_SECONDS"; then
            log_error "${SERVICE_NAME}.service did not become active within ${WAIT_TIMEOUT_SECONDS}s"
            journalctl -u "${SERVICE_NAME}.service" -n 80 --no-pager -o cat || true
            exit 1
        fi
        sleep 3

        logs="$(journalctl -u "${SERVICE_NAME}.service" --since "$marker" --no-pager -o cat 2>/dev/null || true)"
        last_restart_logs="$logs"
        if has_any_checkpoint_start_pattern "$logs"; then
            saw_start_pattern=true
        fi
        if grep -Fq "$CHECKPOINT_FALLBACK_PATTERN" <<<"$logs"; then
            saw_fallback_pattern=true
            break
        fi
    done

    # Also check recent service history in case the first bootstrap happened before this script started.
    local recent_logs
    recent_logs="$(journalctl -u "${SERVICE_NAME}.service" -n 300 --no-pager -o cat 2>/dev/null || true)"
    if has_any_checkpoint_start_pattern "$recent_logs"; then
        saw_start_pattern=true
    fi
    if grep -Fq "$CHECKPOINT_FALLBACK_PATTERN" <<<"$recent_logs"; then
        saw_fallback_pattern=true
    fi

    if [[ "$saw_start_pattern" != "true" ]]; then
        if [[ "$PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG" == "true" ]]; then
            log_error "Did not observe checkpoint bootstrap logs"
            printf '%s\n' "$recent_logs" | tail -n 120
            exit 1
        fi
        log_warn "No checkpoint bootstrap log observed; continuing because PRYSM_CHECKPOINT_REQUIRE_DOWNLOAD_LOG=false"
    fi

    # Fallback log may not appear immediately on fresh nodes where checkpoint
    # bootstrap has started but not yet completed.
    if [[ "$saw_fallback_pattern" != "true" ]]; then
        if [[ "$PRYSM_CHECKPOINT_REQUIRE_FALLBACK_LOG" == "true" ]]; then
            log_error "Did not observe fallback log: $CHECKPOINT_FALLBACK_PATTERN"
            printf '%s\n' "$last_restart_logs" | tail -n 80
            exit 1
        fi
        log_warn "Fallback log not observed yet; continuing because PRYSM_CHECKPOINT_REQUIRE_FALLBACK_LOG=false"
    fi

    log_info "Prysm checkpoint-sync smoke passed"
}

main "$@"
