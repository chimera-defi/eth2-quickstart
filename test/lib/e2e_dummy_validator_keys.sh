#!/bin/bash
# Creates dummy validator keys for Commit-Boost signer in E2E (CI_E2E=true, E2E_MEV=commit-boost).
# Signer needs keys to be fully active; without them it shows "pre-configured but will start after you import keys".
# Supports: lighthouse (via validator-manager create + import to running VC)
#
# Root cause (VC api-token): Lighthouse VC creates api-token.txt on startup. In CI/Docker the VC
# can take 30-90s to initialize (beacon sync, HTTP server). We wait for validator service active
# then poll for api-token up to 90s.

create_dummy_validator_keys() {
    local cons="$1"
    [[ "$cons" != "lighthouse" ]] && return 1

    local lh_bin="$HOME/lighthouse/lighthouse"
    local vc_token="$HOME/.lighthouse/mainnet/validators/api-token.txt"
    local tmp_keys
    tmp_keys=$(mktemp -d)
    trap 'rm -rf "$tmp_keys"' EXIT

    if [[ ! -f "$lh_bin" ]]; then
        log_warn "Lighthouse binary not found at $lh_bin"
        return 1
    fi

    # Ensure VC is running before we create keys (VC creates api-token on startup)
    if declare -f _wait_for_service &>/dev/null; then
        if ! _wait_for_service "validator" 30; then
            log_warn "Lighthouse validator service not active"
            return 1
        fi
    fi

    local mnemonic="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    if ! echo "$mnemonic" | "$lh_bin" validator-manager create \
        --stdin-inputs --network mainnet --first-index 0 --count 1 \
        --eth1-withdrawal-address 0x0000000000000000000000000000000000000001 \
        --output-path "$tmp_keys"; then
        log_warn "lighthouse validator-manager create failed"
        return 1
    fi

    [[ ! -f "$tmp_keys/validators.json" ]] && log_warn "validators.json not created" && return 1

    # VC creates api-token on startup; in CI can take 30-90s (beacon sync, init)
    log_info "Waiting for VC api-token (up to 90s)..."
    local i
    for i in $(seq 1 45); do
        [[ -f "$vc_token" ]] && break
        sleep 2
    done
    if [[ ! -f "$vc_token" ]]; then
        log_warn "VC api-token not found after 90s (validator may still be initializing)"
        return 1
    fi

    if ! "$lh_bin" validator-manager import --network mainnet --vc-token "$vc_token" \
        --validators-file "$tmp_keys/validators.json"; then
        log_warn "lighthouse validator-manager import failed"
        return 1
    fi

    return 0
}
