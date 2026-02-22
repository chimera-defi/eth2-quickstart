#!/bin/bash
# Creates dummy validator keys for Commit-Boost signer in E2E (CI_E2E=true, E2E_MEV=commit-boost).
# Signer needs keys to be fully active; without them it shows "pre-configured but will start after you import keys".
# Supports: lighthouse (via validator-manager create + import to running VC)

create_dummy_validator_keys() {
    local cons="$1"
    [[ "$cons" != "lighthouse" ]] && return 1

    local lh_bin="$HOME/lighthouse/lighthouse"
    local vc_token="$HOME/.lighthouse/mainnet/validators/api-token.txt"
    local tmp_keys
    tmp_keys=$(mktemp -d)

    if [[ ! -f "$lh_bin" ]]; then
        log_warn "Lighthouse binary not found at $lh_bin"
        rm -rf "$tmp_keys"
        return 1
    fi

    local mnemonic="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    if ! echo "$mnemonic" | "$lh_bin" validator-manager create \
        --stdin-inputs --network mainnet --first-index 0 --count 1 \
        --eth1-withdrawal-address 0x0000000000000000000000000000000000000001 \
        --output-path "$tmp_keys"; then
        log_warn "lighthouse validator-manager create failed"
        rm -rf "$tmp_keys"
        return 1
    fi

    [[ ! -f "$tmp_keys/validators.json" ]] && log_warn "validators.json not created" && rm -rf "$tmp_keys" && return 1

    local i
    for i in $(seq 1 10); do
        [[ -f "$vc_token" ]] && break
        sleep 2
    done
    if [[ ! -f "$vc_token" ]]; then
        log_warn "VC api-token not found (validator may not have created it yet)"
        rm -rf "$tmp_keys"
        return 1
    fi

    if ! "$lh_bin" validator-manager import --network mainnet --vc-token "$vc_token" \
        --validators-file "$tmp_keys/validators.json"; then
        log_warn "lighthouse validator-manager import failed"
        rm -rf "$tmp_keys"
        return 1
    fi

    rm -rf "$tmp_keys"
    return 0
}
