#!/bin/bash

# Shared planning logic for repo-backed install workflows.

planner_load_config() {
    local root_dir="$1"

    # shellcheck source=/dev/null
    source "$root_dir/exports.sh" 2>/dev/null || true
    if [[ -f "$root_dir/config/user_config.env" ]]; then
        # shellcheck source=/dev/null
        source "$root_dir/config/user_config.env" 2>/dev/null || true
    fi
}

planner_configured_chain() {
    local configured="${CHAIN:-ethereum}"
    case "$configured" in
        ethereum|monad)
            printf '%s\n' "$configured"
            ;;
        *)
            printf '%s\n' "ethereum"
            ;;
    esac
}

planner_core_services_for_chain() {
    local chain="$1"
    case "$chain" in
        ethereum)
            printf '%s\n' "eth1" "cl"
            ;;
        monad)
            printf '%s\n' "monad-bft" "monad-execution" "monad-rpc"
            ;;
        *)
            return 1
            ;;
    esac
}

planner_operator_user_exists() {
    local operator_user="$1"
    [[ -n "$operator_user" ]] && id -u "$operator_user" >/dev/null 2>&1
}

planner_collect_service_states() {
    local chain="$1"
    local service
    local status

    PLAN_SERVICE_NAMES=()
    PLAN_SERVICE_STATUSES=()
    PLAN_CORE_EXPECTED=0
    PLAN_CORE_INSTALLED=0
    PLAN_CORE_RUNNING=0

    local services=()
    mapfile -t services < <(planner_core_services_for_chain "$chain")
    for service in "${services[@]}"; do
        status="$(check_service_status "$service")"
        PLAN_SERVICE_NAMES+=("$service")
        PLAN_SERVICE_STATUSES+=("$status")
        ((PLAN_CORE_EXPECTED += 1))
        if [[ "$status" != "not_installed" ]]; then
            ((PLAN_CORE_INSTALLED += 1))
        fi
        if [[ "$status" == "running" ]]; then
            ((PLAN_CORE_RUNNING += 1))
        fi
    done
}

planner_prepare_context() {
    local root_dir="$1"
    local chain_override="${2:-}"

    planner_load_config "$root_dir"
    CHAIN_VALUE="${chain_override:-$(planner_configured_chain)}"
    OPERATOR_USER="${LOGIN_UNAME:-eth}"
    CURRENT_USER="$(id -un)"
    IS_ROOT=false
    if [[ $EUID -eq 0 ]]; then
        IS_ROOT=true
    fi

    if planner_operator_user_exists "$OPERATOR_USER"; then
        OPERATOR_EXISTS=true
    else
        OPERATOR_EXISTS=false
    fi

    planner_collect_service_states "$CHAIN_VALUE"
    planner_determine_next_action "$CHAIN_VALUE" "$IS_ROOT" "$OPERATOR_EXISTS" "$PLAN_CORE_INSTALLED" "$PLAN_CORE_EXPECTED"
}

planner_determine_next_action() {
    local chain="$1"
    local is_root="$2"
    local operator_exists="$3"
    local installed_count="$4"
    local expected_count="$5"

    PLAN_STATE=""
    PLAN_NEXT_ACTION=""
    PLAN_REASON=""

    if (( installed_count == expected_count )) && (( expected_count > 0 )); then
        PLAN_STATE="installed"
        PLAN_NEXT_ACTION="noop"
        PLAN_REASON="all core services for ${chain} are already installed"
        return 0
    fi

    if (( installed_count > 0 )); then
        PLAN_STATE="partial_install_review"
        PLAN_NEXT_ACTION="review"
        PLAN_REASON="some core services are installed, but the stack is incomplete"
        return 0
    fi

    if [[ "$is_root" == "true" ]]; then
        if [[ "$operator_exists" == "true" ]]; then
            PLAN_STATE="needs_relogin"
            PLAN_NEXT_ACTION="relogin"
            PLAN_REASON="phase 1 likely completed; continue as the operator user after reboot/login"
        else
            PLAN_STATE="needs_phase1"
            PLAN_NEXT_ACTION="phase1"
            PLAN_REASON="phase 1 system hardening has not been completed yet"
        fi
        return 0
    fi

    case "$chain" in
        ethereum)
            PLAN_STATE="needs_phase2"
            PLAN_NEXT_ACTION="phase2"
            PLAN_REASON="phase 1 appears complete and Ethereum clients are not installed yet"
            ;;
        monad)
            PLAN_STATE="needs_monad_install"
            PLAN_NEXT_ACTION="monad_install"
            PLAN_REASON="phase 1 appears complete and Monad services are not installed yet"
            ;;
        *)
            PLAN_STATE="unsupported"
            PLAN_NEXT_ACTION="review"
            PLAN_REASON="unsupported chain: ${chain}"
            ;;
    esac
}
