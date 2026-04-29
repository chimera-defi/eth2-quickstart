#!/bin/bash
# Creates dummy validator keys for Commit-Boost signer in E2E (CI_E2E=true, E2E_MEV=commit-boost).
# Signer needs keys to be fully active; without them it shows "pre-configured but will start after you import keys".
# Supports:
# - lighthouse (via validator-manager create + import to running VC)
# - prysm (creates a valid Prysm wallet keystore with Prysm CLI)
#
# VC api-token: Lighthouse VC creates api-token.txt when its HTTP server starts (after connecting to beacon).
# We wait for beacon REST API to respond, then validator, then poll for api-token.

create_dummy_validator_keys() {
    local cons="$1"
    if [[ "$cons" == "prysm" ]]; then
        local prysm_wallet_dir="$HOME/.eth2validators/prysm-wallet-v2"
        local prysm_keys_dir="$prysm_wallet_dir/direct/accounts"
        local prysm_keys_file="$prysm_keys_dir/all-accounts.keystore.json"
        local prysm_pass_file="$HOME/secrets/pass.txt"
        local prysm_cli="$HOME/prysm/prysm.sh"
        mkdir -p "$HOME/secrets"
        printf '%s\n' "insecure-e2e-passphrase" > "$prysm_pass_file"
        chmod 600 "$prysm_pass_file"

        if [[ ! -x "$prysm_cli" ]]; then
            log_warn "Prysm CLI not found at $prysm_cli"
            return 1
        fi

        # Create a valid wallet file using Prysm's own command so both Prysm VC and
        # Commit-Boost signer can parse the keystore format.
        if [[ ! -f "$prysm_keys_file" ]]; then
            if ! "$prysm_cli" validator wallet create \
                --wallet-dir "$prysm_wallet_dir" \
                --keymanager-kind imported \
                --wallet-password-file "$prysm_pass_file" \
                --accept-terms-of-use; then
                log_warn "Failed to create Prysm wallet keystore"
                return 1
            fi
        fi

        if [[ ! -s "$prysm_keys_file" ]]; then
            log_warn "Prysm wallet keystore not created at $prysm_keys_file"
            return 1
        fi
        log_info "Created Prysm wallet keystore for Commit-Boost signer: $prysm_keys_file"
        return 0
    fi

    [[ "$cons" != "lighthouse" ]] && return 1

    local lh_bin="$HOME/lighthouse/lighthouse"
    local vc_token="$HOME/.lighthouse/mainnet/validators/api-token.txt"
    local lh_keys_dir="$HOME/.lighthouse/mainnet/validators"
    local lh_secrets_dir="$HOME/.lighthouse/mainnet/secrets"
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

    # Beacon REST must be responding before VC can connect; poll up to 360s
    # Note: /eth/v1/node/health returns 503 during sync — 200/206/503 all mean "API up"
    log_info "Waiting for beacon REST API on 127.0.0.1:5052 (up to 360s)..."
    local i code exitcode beacon_ok=false
    for i in $(seq 1 180); do
        set +e
        code=$(curl -sS -o /dev/null --connect-timeout 2 -w "%{http_code}" "http://127.0.0.1:5052/eth/v1/node/health" 2>/dev/null)
        exitcode=$?
        set -e
        if [[ -n "$code" && "$code" =~ ^(200|206|503)$ ]]; then
            log_info "Beacon REST API ready after $(( (i - 1) * 2 ))s (HTTP $code)"
            beacon_ok=true
            break
        fi
        [[ $(( i % 5 )) -eq 0 ]] && log_info "  attempt $i/180 (curl exit=$exitcode, http=${code:-none})..."
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

    # Commit-Boost signer expects file-based Lighthouse key/secrets paths.
    # Seed canonical Lighthouse directories from generated artifacts so signer
    # can start during E2E before/alongside VC import path usage.
    mkdir -p "$lh_keys_dir" "$lh_secrets_dir"
    find "$_e2e_tmp_keys" -type f -name "*keystore*.json" 2>/dev/null | while IFS= read -r f; do
        cp -f "$f" "$lh_keys_dir/"
    done
    find "$_e2e_tmp_keys" -type f -name "*.txt" 2>/dev/null | while IFS= read -r f; do
        cp -f "$f" "$lh_secrets_dir/"
    done

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

    if [[ -z "$(find "$lh_keys_dir" -name "*.json" -maxdepth 3 2>/dev/null | head -1)" ]]; then
        log_warn "No Lighthouse keystore JSON copied to $lh_keys_dir"
        return 1
    fi
    if [[ -z "$(find "$lh_secrets_dir" -type f -maxdepth 2 2>/dev/null | head -1)" ]]; then
        log_warn "No Lighthouse secret file copied to $lh_secrets_dir (validator may create it shortly)"
    fi
}
