#!/bin/bash

set -Eeuo pipefail
# shellcheck disable=SC2317

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

run_test() {
    local test_name="$1"
    local test_func="$2"

    TEST_COUNT=$((TEST_COUNT + 1))
    echo ""
    echo "=== Test $TEST_COUNT: $test_name ==="

    if "$test_func"; then
        echo "PASS: $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "FAIL: $test_name"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

setup_fake_env() {
    local temp_root
    temp_root="$(mktemp -d)"
    cp "$SCRIPT_DIR/fixtures/validator_withdrawal_changes_inventory.json" "$temp_root/validators.json"
    printf '%s\n' "$temp_root"
}

test_resolve_selection_to_pubkeys() {
    local temp_root output
    temp_root="$(setup_fake_env)"

    output="$(bash -c 'source "$1"; resolve_selection_to_pubkeys "$2" "101 102"' _ "$PROJECT_ROOT/install/utils/validator_manage.sh" "$temp_root/validators.json")"
    [[ "$output" == "0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999,0xbbbbccccddddeeeeffff0000111122223333444455556666777788889999aaaa" ]]

    output="$(bash -c 'source "$1"; resolve_selection_to_pubkeys "$2" all' _ "$PROJECT_ROOT/install/utils/validator_manage.sh" "$temp_root/validators.json")"
    [[ "$output" == "0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999,0xbbbbccccddddeeeeffff0000111122223333444455556666777788889999aaaa,0xccccddddeeeeffff0000111122223333444455556666777788889999aaaabbbb" ]]

    rm -rf "$temp_root"
}

test_resolve_consolidation_contract_guard() {
    local output
    output="$(bash -c 'source "$1"; CONSOLIDATION_CONTRACT=""; CONSOLIDATION_CHAIN=holesky; resolve_consolidation_contract' _ "$PROJECT_ROOT/install/utils/validator_manage.sh" 2>&1)" && return 1
    [[ "$output" == *"No consolidation contract is configured for chain 'holesky'"* ]]
}

# shellcheck disable=SC2317
test_cmd_consolidate_rejects_non_inventory_or_duplicate_pubkeys() {
    local temp_root temp_bin cast_log fixture source_pubkey target_pubkey priv_key runner output
    temp_root="$(mktemp -d)"
    temp_bin="$temp_root/bin"
    mkdir -p "$temp_bin"
    cast_log="$temp_root/cast.log"
    fixture="$PROJECT_ROOT/install/test/fixtures/validator_withdrawal_changes_inventory.json"
    source_pubkey="0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999"
    target_pubkey="0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999"
    priv_key="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    runner="$temp_root/run.sh"

    cat > "$temp_bin/cast" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${CAST_LOG_FILE:?}"
echo "$*" >> "$log_file"
exit 1
EOF
    chmod +x "$temp_bin/cast"

    cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
source "$PROJECT_ROOT/install/utils/validator_manage.sh"
load_local_validators() { cp "$fixture" "\$1"; }
print_local_validators() { :; }
confirm_destructive() { return 0; }
query_execution_chain_id_hex() { echo 0x1; }
curl() {
    if [[ "\$*" == *eth_call* ]]; then
        echo '{"jsonrpc":"2.0","id":1,"result":"0x1"}'
        return 0
    fi
    command curl "\$@"
}
cmd_consolidate
EOF
    chmod +x "$runner"

    output="$(printf '%s\n%s\n%s\n' "$source_pubkey" "$target_pubkey" "$priv_key" | PATH="$temp_bin:$PATH" CAST_LOG_FILE="$cast_log" bash "$runner" 2>&1 || true)"

    printf '%s\n' "$output" | grep -q 'Source and target pubkeys must be different.'
    [[ ! -e "$cast_log" || ! -s "$cast_log" ]]

    rm -rf "$temp_root"
}

test_cmd_consolidate_uses_temp_keystore() {
    local temp_root temp_bin cast_log fixture source_pubkey target_pubkey priv_key runner output
    temp_root="$(mktemp -d)"
    temp_bin="$temp_root/bin"
    mkdir -p "$temp_bin"
    cast_log="$temp_root/cast.log"
    fixture="$PROJECT_ROOT/install/test/fixtures/validator_withdrawal_changes_inventory.json"
    source_pubkey="0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999"
    target_pubkey="0xbbbbccccddddeeeeffff0000111122223333444455556666777788889999aaaa"
    priv_key="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    runner="$temp_root/run.sh"

    cat > "$temp_bin/cast" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${CAST_LOG_FILE:?}"
case "$1" in
    wallet)
        shift
        if [[ "$1" != "import" ]]; then
            echo "unsupported cast wallet command: $*" >&2
            exit 1
        fi
        shift
        keystore_dir=""
        account_name=""
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --keystore-dir)
                    keystore_dir="$2"
                    shift 2
                    ;;
                --interactive)
                    shift
                    ;;
                *)
                    account_name="$1"
                    shift
                    ;;
            esac
        done
        mkdir -p "$keystore_dir"
        : > "$keystore_dir/${account_name}.json"
        cat >/dev/null || true
        ;;
    send)
        printf '%s
' "$*" >> "$log_file"
        cat >/dev/null || true
        ;;
    *)
        echo "unsupported cast command: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$temp_bin/cast"

    cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
source "$PROJECT_ROOT/install/utils/validator_manage.sh"
load_local_validators() { cp "$fixture" "\$1"; }
print_local_validators() { :; }
confirm_destructive() { return 0; }
query_execution_chain_id_hex() { echo 0x1; }
curl() {
    if [[ "\$*" == *eth_call* ]]; then
        echo '{"jsonrpc":"2.0","id":1,"result":"0x1"}'
        return 0
    fi
    command curl "\$@"
}
cmd_consolidate
EOF
    chmod +x "$runner"

    output="$(printf '%s
%s
%s
' "$source_pubkey" "$target_pubkey" "$priv_key" | PATH="$temp_bin:$PATH" CAST_LOG_FILE="$cast_log" bash "$runner")"

    local send_line
    send_line="$(cat "$cast_log")"
    [[ "$send_line" == *"send 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb"* ]]
    [[ "$send_line" == *"--keystore "* ]]
    [[ "$send_line" == *"--password-file "* ]]
    [[ "$send_line" != *"--private-key"* ]]

    rm -rf "$temp_root"
    [[ -n "$output" ]]
}

# shellcheck disable=SC2317
test_resolve_prysm_beacon_rpc_provider() {
    local output
    output="$(bash -c '
        source "$1"
        PRYSM_BEACON_RPC_PROVIDER="127.0.0.1:4900" resolve_prysm_beacon_rpc_provider "http://127.0.0.1:5052"
    ' _ "$PROJECT_ROOT/install/utils/validator_manage.sh")"
    [[ "$output" == "127.0.0.1:4900" ]]

    output="$(bash -c '
        source "$1"
        unset PRYSM_BEACON_RPC_PROVIDER
        resolve_prysm_beacon_rpc_provider "http://example.com:5052"
    ' _ "$PROJECT_ROOT/install/utils/validator_manage.sh")"
    [[ "$output" == "example.com:4000" ]]
}

# shellcheck disable=SC2317
test_do_exit_uses_prysm_rpc_provider() {
    local temp_root temp_bin prysm_log runner output pubkey_csv
    temp_root="$(mktemp -d)"
    temp_bin="$temp_root/bin"
    mkdir -p "$temp_bin" "$temp_root/secrets" "$temp_root/prysm/wallet"
    prysm_log="$temp_root/prysm.log"
    runner="$temp_root/run.sh"
    pubkey_csv="0x$(printf 'a%.0s' {1..96})"
    printf '%s
' 'validator-passphrase' > "$temp_root/secrets/pass.txt"

    cat > "$temp_bin/prysm.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${PRYSM_LOG_FILE:?}"
printf '%s
' "$*" >> "$log_file"
exit 0
EOF
    chmod +x "$temp_bin/prysm.sh"

    cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
source "$PROJECT_ROOT/install/utils/validator_manage.sh"
_do_exit prysm "http://127.0.0.1:5052" "$temp_bin/prysm.sh" "$pubkey_csv"
EOF
    chmod +x "$runner"

    output="$(HOME="$temp_root" PRYSM_LOG_FILE="$prysm_log" bash "$runner" 2>&1)"

    grep -Fq -- "--beacon-rpc-provider=127.0.0.1:4900" "$prysm_log"
    grep -Fq -- "--wallet-dir=$temp_bin/wallet" "$prysm_log"
    grep -Fq -- "--pubkeys=$pubkey_csv" "$prysm_log"
    [[ -n "$output" ]]

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_cmd_consolidate_dry_run_skips_signing_and_send() {
    local temp_root temp_bin cast_log fixture source_pubkey target_pubkey priv_key runner output
    temp_root="$(mktemp -d)"
    temp_bin="$temp_root/bin"
    mkdir -p "$temp_bin"
    cast_log="$temp_root/cast.log"
    fixture="$PROJECT_ROOT/install/test/fixtures/validator_withdrawal_changes_inventory.json"
    source_pubkey="0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999"
    target_pubkey="0xbbbbccccddddeeeeffff0000111122223333444455556666777788889999aaaa"
    priv_key="0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    runner="$temp_root/run.sh"

    cat > "$temp_bin/cast" <<'EOF'
#!/bin/bash
set -euo pipefail
log_file="${CAST_LOG_FILE:?}"
echo "$*" >> "$log_file"
exit 1
EOF
    chmod +x "$temp_bin/cast"

    cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
source "$PROJECT_ROOT/install/utils/validator_manage.sh"
load_local_validators() { cp "$fixture" "\$1"; }
print_local_validators() { :; }
confirm_destructive() { echo "confirm_destructive should not be called" >&2; return 1; }
query_execution_chain_id_hex() { echo 0x1; }
curl() {
    if [[ "\$*" == *eth_call* ]]; then
        echo '{"jsonrpc":"2.0","id":1,"result":"0x1"}'
        return 0
    fi
    command curl "\$@"
}
CONSOLIDATE_DRY_RUN=true cmd_consolidate
EOF
    chmod +x "$runner"

    output="$(printf '%s
%s
%s
' "$source_pubkey" "$target_pubkey" "$priv_key" | PATH="$temp_bin:$PATH" CAST_LOG_FILE="$cast_log" bash "$runner" 2>&1)"

    [[ ! -e "$cast_log" || ! -s "$cast_log" ]]
    grep -Fq -- "Dry run requested. No keystore import or transaction will be sent." <<< "$output"
    grep -Fq -- "cast send" <<< "$output"

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Validator Manage Test Suite"
echo "=========================================="

run_test "resolve selection to pubkeys" test_resolve_selection_to_pubkeys
run_test "guard consolidation contract by chain" test_resolve_consolidation_contract_guard
run_test "reject invalid consolidation pubkeys" test_cmd_consolidate_rejects_non_inventory_or_duplicate_pubkeys
run_test "resolve Prysm beacon RPC provider" test_resolve_prysm_beacon_rpc_provider
run_test "use Prysm RPC provider in exit flow" test_do_exit_uses_prysm_rpc_provider
run_test "dry-run skips signing and send" test_cmd_consolidate_dry_run_skips_signing_and_send
run_test "use temp keystore for consolidation" test_cmd_consolidate_uses_temp_keystore

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests: $TEST_COUNT"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo ""
    echo "All tests passed!"
    exit 0
fi

exit 1
