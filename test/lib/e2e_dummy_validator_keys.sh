#!/bin/bash
# Creates dummy validator keys for E2E testing of Commit-Boost signer
# Used when CI_E2E=true and E2E_MEV=commit-boost - signer needs keys to be fully active
# Supports: lighthouse (via lighthouse validator-manager)

create_dummy_validator_keys() {
    local cons="$1"
    case "$cons" in
        lighthouse)
            create_lighthouse_dummy_keys
            ;;
        *)
            log_info "Dummy keys not implemented for $cons (signer may run without keys)"
            return 1
            ;;
    esac
}

create_lighthouse_dummy_keys() {
    local lh_bin="$HOME/lighthouse/lighthouse"
    local vc_token="$HOME/.lighthouse/mainnet/validators/api-token.txt"
    local tmp_keys
    tmp_keys=$(mktemp -d)

    if [[ ! -f "$lh_bin" ]]; then
        log_warn "Lighthouse binary not found at $lh_bin"
        rm -rf "$tmp_keys"
        return 1
    fi

    # Create 1 validator with dummy withdrawal address
    # Use standard test mnemonic for non-interactive creation
    local mnemonic="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    if ! echo "$mnemonic" | "$lh_bin" validator-manager create \
        --network mainnet \
        --first-index 0 \
        --count 1 \
        --eth1-withdrawal-address 0x0000000000000000000000000000000000000001 \
        --output-path "$tmp_keys" 2>/dev/null; then
        log_warn "lighthouse validator-manager create failed"
        rm -rf "$tmp_keys"
        return 1
    fi

    if [[ ! -f "$tmp_keys/validators.json" ]]; then
        log_warn "validators.json not created"
        rm -rf "$tmp_keys"
        return 1
    fi

    # Import to VC (must be running). VC creates api-token on first start
    local i
    for i in $(seq 1 10); do
        [[ -f "$vc_token" ]] && break
        sleep 2
    done
    if [[ ! -f "$vc_token" ]]; then
        log_warn "VC api-token not found at $vc_token (validator service may not have created it yet)"
        rm -rf "$tmp_keys"
        return 1
    fi

    if ! "$lh_bin" validator-manager import \
        --network mainnet \
        --vc-token "$vc_token" \
        --validators-file "$tmp_keys/validators.json" 2>/dev/null; then
        log_warn "lighthouse validator-manager import failed"
        rm -rf "$tmp_keys"
        return 1
    fi

    rm -rf "$tmp_keys"
    return 0
}
