#!/bin/bash
# Creates dummy validator keys for E2E testing of Commit-Boost signer
# Used when CI_E2E=true and E2E_MEV=commit-boost - signer needs keys to be fully active
# Supports: lighthouse, prysm (via lighthouse validator-manager + client-specific import)

create_dummy_validator_keys() {
    local cons="$1"
    case "$cons" in
        lighthouse)
            create_lighthouse_dummy_keys
            ;;
        prysm)
            create_prysm_dummy_keys
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
    # Use standard test mnemonic; --stdin-inputs reads mnemonic from stdin
    local mnemonic="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    if ! echo "$mnemonic" | "$lh_bin" validator-manager create \
        --stdin-inputs \
        --network mainnet \
        --first-index 0 \
        --count 1 \
        --eth1-withdrawal-address 0x0000000000000000000000000000000000000001 \
        --output-path "$tmp_keys"; then
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

create_prysm_dummy_keys() {
    local lh_bin="$HOME/lighthouse/lighthouse"
    local prysm_bin="$HOME/prysm/prysm.sh"
    local wallet_dir="$HOME/.eth2validators/prysm-wallet-v2/direct"
    local accounts_dir="$wallet_dir/accounts"
    local pass_file="$HOME/secrets/pass.txt"
    local tmp_keys
    tmp_keys=$(mktemp -d)

    # Use lighthouse to create keys (works even when testing prysm+commit-boost)
    if [[ ! -f "$lh_bin" ]]; then
        log_warn "Lighthouse binary not found (needed for key generation)"
        rm -rf "$tmp_keys"
        return 1
    fi

    local mnemonic="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    if ! echo "$mnemonic" | "$lh_bin" validator-manager create \
        --stdin-inputs \
        --network mainnet \
        --first-index 0 \
        --count 1 \
        --eth1-withdrawal-address 0x0000000000000000000000000000000000000001 \
        --output-path "$tmp_keys"; then
        log_warn "lighthouse validator-manager create failed (Prysm keys)"
        rm -rf "$tmp_keys"
        return 1
    fi

    if [[ ! -f "$tmp_keys/validators.json" ]] || ! command -v jq &>/dev/null; then
        log_warn "validators.json not created or jq missing"
        rm -rf "$tmp_keys"
        return 1
    fi

    # Extract keystore and password from validators.json
    local keystore_json password
    keystore_json=$(jq -r '.[0].voting_keystore' "$tmp_keys/validators.json")
    password=$(jq -r '.[0].voting_keystore_password' "$tmp_keys/validators.json")
    [[ -z "$keystore_json" || "$keystore_json" == "null" ]] && log_warn "Failed to extract keystore" && rm -rf "$tmp_keys" && return 1

    # Create Prysm wallet structure
    mkdir -p "$accounts_dir"
    mkdir -p "$HOME/secrets"
    chmod 700 "$HOME/secrets" 2>/dev/null || true

    # Write keystore (Prysm expects keystore-m_* prefix)
    local uuid
    uuid=$(echo "$keystore_json" | jq -r '.uuid')
    echo "$keystore_json" > "$accounts_dir/keystore-m_12381_3600_0_0_0-${uuid}.json"

    # Create password file for this keystore (Prysm format: same-name.txt)
    echo "$password" > "$accounts_dir/keystore-m_12381_3600_0_0_0-${uuid}.txt"

    # Prysm direct wallet: all-accounts.keystore.json contains array of EIP-2335 keystores
    echo "$keystore_json" | jq -s '.' > "$accounts_dir/all-accounts.keystore.json" 2>/dev/null || {
        log_warn "Failed to create all-accounts.keystore.json"
        rm -rf "$tmp_keys"
        return 1
    }

    # secrets_path: password file for Prysm
    echo "$password" > "$pass_file"
    chmod 600 "$pass_file"

    rm -rf "$tmp_keys"
    return 0
}
