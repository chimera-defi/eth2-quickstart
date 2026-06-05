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
    mkdir -p "$temp_root/bin"

    cp "$SCRIPT_DIR/fixtures/validator_withdrawal_changes_inventory.json" "$temp_root/validators.json"

    cat > "$temp_root/bin/deposit.sh" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
: "${MOCK_DEPOSIT_LOG:?missing MOCK_DEPOSIT_LOG}"
echo "[MOCK] deposit.sh $*" >> "$MOCK_DEPOSIT_LOG"
out_dir=""
indices=""
for arg in "$@"; do
    case "$arg" in
        --bls_to_execution_changes_folder=*) out_dir="${arg#*=}" ;;
        --validator_indices=*) indices="${arg#*=}" ;;
    esac
done
mkdir -p "$out_dir"
python3 - "$out_dir" "$indices" <<'PYEOF'
import os, sys
out_dir, indices = sys.argv[1:3]
for idx in [i for i in indices.split(',') if i]:
    with open(os.path.join(out_dir, f'bls_to_execution_change-{idx}.json'), 'w') as fh:
        fh.write('{"mock": true, "index": "%s"}\n' % idx)
PYEOF
EOF

    cat > "$temp_root/bin/curl" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
: "${MOCK_CURL_LOG:?missing MOCK_CURL_LOG}"
echo "[MOCK] curl $*" >> "$MOCK_CURL_LOG"
exit 0
EOF

    chmod +x "$temp_root/bin/deposit.sh" "$temp_root/bin/curl"

    cat > "$temp_root/mnemonic.txt" <<'EOF'
abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about
EOF
    cat > "$temp_root/password.txt" <<'EOF'
correct horse battery staple
EOF

    printf '%s\n' "$temp_root"
}

assert_contains() {
    local needle="$1"
    local file="$2"
    grep -qF -- "$needle" "$file"
}

assert_file_empty() {
    local file="$1"
    [[ ! -e "$file" || ! -s "$file" ]]
}

# shellcheck disable=SC2317
test_dry_run_reports_without_invoking_tools() {
    local temp_root output deposit_log curl_log
    temp_root="$(setup_fake_env)"
    deposit_log="$temp_root/deposit.log"
    curl_log="$temp_root/curl.log"

    output="$(PATH="$temp_root/bin:$PATH" "$PROJECT_ROOT/install/utils/validator_withdrawal_changes.sh"         --validators-json "$temp_root/validators.json"         --credential-type 0x00         --dry-run         --generate         --submit         --yes         --withdrawal-address 0x1111111111111111111111111111111111111111         --mnemonic-file "$temp_root/mnemonic.txt"         --mnemonic-password-file "$temp_root/password.txt"         --out-dir "$temp_root/generated"         --deposit-tool deposit-sh         --beacon-url http://127.0.0.1:5052)"

    printf '%s
' "$output" | grep -q "Dry run: no files will be written or submitted."
    printf '%s
' "$output" | grep -q "Would affect 1 validator(s): 101"
    printf '%s
' "$output" | grep -q "generate-bls-to-execution-change"
    printf '%s
' "$output" | grep -q "bls_to_execution_change-101.json"
    assert_file_empty "$deposit_log"
    assert_file_empty "$curl_log"

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_inventory_shows_withdrawal_types() {
    local temp_root output
    temp_root="$(setup_fake_env)"

    output="$(PATH="$temp_root/bin:$PATH" "$PROJECT_ROOT/install/utils/validator_withdrawal_changes.sh" --validators-json "$temp_root/validators.json" --credential-type all)"

    printf '%s\n' "$output" | grep -q "WCred"
    printf '%s\n' "$output" | grep -q "0x00"
    printf '%s\n' "$output" | grep -q "0x01"
    printf '%s\n' "$output" | grep -q "0x02"

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_generate_and_submit_0x00_changes() {
    local temp_root output deposit_log curl_log out_dir
    temp_root="$(setup_fake_env)"
    deposit_log="$temp_root/deposit.log"
    curl_log="$temp_root/curl.log"
    out_dir="$temp_root/generated"

    output="$(MOCK_DEPOSIT_LOG="$deposit_log" MOCK_CURL_LOG="$curl_log" PATH="$temp_root/bin:$PATH" "$PROJECT_ROOT/install/utils/validator_withdrawal_changes.sh" \
        --validators-json "$temp_root/validators.json" \
        --credential-type 0x00 \
        --generate \
        --submit \
        --yes \
        --withdrawal-address 0x1111111111111111111111111111111111111111 \
        --mnemonic-file "$temp_root/mnemonic.txt" \
        --mnemonic-password-file "$temp_root/password.txt" \
        --out-dir "$out_dir" \
        --deposit-tool deposit-sh \
        --beacon-url http://127.0.0.1:5052)"

    assert_contains "0x00" "$deposit_log"
    assert_contains "generate-bls-to-execution-change" "$deposit_log"
    assert_contains "--validator_indices=101" "$deposit_log"
    assert_contains "--execution_address=0x1111111111111111111111111111111111111111" "$deposit_log"
    test -f "$out_dir/bls_to_execution_change-101.json"
    assert_contains "/eth/v1/beacon/pool/bls_to_execution_changes" "$curl_log"

    printf '%s\n' "$output" | grep -q "Submitting bls_to_execution_change-101.json"

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Validator Withdrawal Change Test Suite"
echo "=========================================="

run_test "dry run reports without invoking tools" test_dry_run_reports_without_invoking_tools
run_test "inventory shows withdrawal types" test_inventory_shows_withdrawal_types
run_test "generate and submit 0x00 changes" test_generate_and_submit_0x00_changes

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
