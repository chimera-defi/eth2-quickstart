#!/bin/bash
# Creates dummy validator keys for Commit-Boost signer in E2E (CI_E2E=true, E2E_MEV=commit-boost).
# Signer needs keys to be fully active; without them it shows "pre-configured but will start after you import keys".
# Supports: lighthouse (via validator-manager create + import to running VC)
#
# VC api-token: Lighthouse VC creates api-token.txt when its HTTP server starts (after connecting to beacon).
# We wait for beacon REST API to respond, then validator, then poll for api-token.

create_dummy_validator_keys() {
    local cons="$1"
    [[ "$cons" != "lighthouse" ]] && return 1

    local lh_bin="$HOME/lighthouse/lighthouse"
    local vc_token="$HOME/.lighthouse/mainnet/validators/api-token.txt"
    # Must persist for EXIT trap (local would be unbound when trap runs with set -u)
    _e2e_tmp_keys=$(mktemp -d)
    trap '[[ -n "${_e2e_tmp_keys:-}" ]] && rm -rf "$_e2e_tmp_keys"' EXIT

    if [[ ! -f "$lh_bin" ]]; then
        log_warn "Lighthouse binary not found at $lh_bin"
        return 1
    fi

    log_info "Waiting for Lighthouse beacon (cl) service (up to 60s)..."
    if ! _wait_for_service "cl" 60; then
        log_warn "Lighthouse beacon (cl) not active"
        sudo systemctl status cl 2>/dev/null || true
        return 1
    fi

    # Beacon REST must be responding before VC can connect; poll up to 90s
    # Note: /eth/v1/node/health returns 503 during sync — 200/206/503 all mean "API up"
    log_info "Waiting for beacon REST API on 127.0.0.1:5052 (up to 90s)..."
    local i code exitcode beacon_ok=false
    for i in $(seq 1 45); do
        set +e
        code=$(curl -sS -o /dev/null --connect-timeout 2 -w "%{http_code}" "http://127.0.0.1:5052/eth/v1/node/health" 2>/dev/null)
        exitcode=$?
        set -e
        if [[ -n "$code" && "$code" =~ ^(200|206|503)$ ]]; then
            log_info "Beacon REST API ready after $(( (i - 1) * 2 ))s (HTTP $code)"
            beacon_ok=true
            break
        fi
        [[ $(( i % 5 )) -eq 0 ]] && log_info "  attempt $i/45 (curl exit=$exitcode, http=${code:-none})..."
        sleep 2
    done
    if [[ "$beacon_ok" != "true" ]]; then
        # Curl exit codes: 7=connection refused, 28=timeout, 6=could not resolve
        local curl_hint=""
        case "${exitcode:-0}" in
            7) curl_hint=" (connection refused — nothing listening on :5052 or firewall blocking)" ;;
            28) curl_hint=" (timeout — beacon may be slow to start)" ;;
            6) curl_hint=" (could not resolve host)" ;;
        esac
        log_warn "Beacon REST API not responding on :5052 (curl exit=$exitcode, http_code=${code:-none})$curl_hint"
        log_warn "Diagnostics:"
        log_warn "  Port 5052 listening: $(ss -tlnp 2>/dev/null | grep 5052 || echo 'none')"
        log_warn "  cl.service active: $(sudo systemctl is-active cl 2>/dev/null || echo 'unknown')"
        log_warn "  eth1.service active: $(sudo systemctl is-active eth1 2>/dev/null || echo 'unknown') (beacon depends on eth1)"
        log_warn "  cl.service ExecStart (verify --http present):"
        grep '^ExecStart=' /etc/systemd/system/cl.service 2>/dev/null | sed 's/^/    /' || true
        log_warn "  Last cl.service journal:"
        sudo journalctl -u cl -n 25 --no-pager 2>/dev/null | sed 's/^/    /' || true
        return 1
    fi

    log_info "Waiting for Lighthouse validator (VC) service (up to 60s)..."
    if ! _wait_for_service "validator" 60; then
        log_warn "Lighthouse validator not active"
        sudo systemctl status validator 2>/dev/null || true
        sudo journalctl -u cl -n 15 --no-pager 2>/dev/null || true
        return 1
    fi

    local mnemonic="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    if ! echo "$mnemonic" | "$lh_bin" validator-manager create \
        --stdin-inputs --network mainnet --first-index 0 --count 1 \
        --eth1-withdrawal-address 0x0000000000000000000000000000000000000001 \
        --output-path "$_e2e_tmp_keys"; then
        log_warn "lighthouse validator-manager create failed"
        return 1
    fi

    [[ ! -f "$_e2e_tmp_keys/validators.json" ]] && log_warn "validators.json not created" && return 1

    # VC creates api-token when HTTP server starts (after beacon connection); poll up to 120s
    log_info "Waiting for VC api-token at $vc_token (up to 120s)..."
    for i in $(seq 1 60); do
        [[ -f "$vc_token" ]] && break
        sleep 2
    done
    if [[ ! -f "$vc_token" ]]; then
        log_warn "VC api-token not found after 120s"
        log_warn "Diagnostics: ls -la $(dirname "$vc_token")"
        ls -la "$(dirname "$vc_token")" 2>/dev/null || true
        sudo journalctl -u validator -n 20 --no-pager 2>/dev/null || true
        return 1
    fi

    if ! "$lh_bin" validator-manager import --network mainnet --vc-token "$vc_token" \
        --validators-file "$_e2e_tmp_keys/validators.json"; then
        log_warn "lighthouse validator-manager import failed"
        return 1
    fi
}
