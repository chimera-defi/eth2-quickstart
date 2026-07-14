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

    # Run the test with -e active as a PLAIN subshell statement. Invoking it
    # via `if "$test_func"` disables set -e inside the function, so a failing
    # assertion would not fail the test (the function returns its last
    # command's status, usually the cleanup `rm -rf`). Save/restore errexit.
    local _rc _e_was=0
    [[ $- == *e* ]] && _e_was=1
    set +e
    ( set -euo pipefail; "$test_func" )
    _rc=$?
    [[ $_e_was -eq 1 ]] && set -e
    if [[ $_rc -eq 0 ]]; then
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
# The real deposit CLI prompts for the mnemonic on stdin when --mnemonic is
# omitted; capture it so the test can confirm it arrived off-argv.
if [[ -n "${MOCK_MNEMONIC_LOG:-}" ]]; then
    _stdin_mnemonic=""
    IFS= read -r _stdin_mnemonic || true
    printf '%s\n' "$_stdin_mnemonic" >> "$MOCK_MNEMONIC_LOG"
fi
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
import json, os, sys
out_dir, indices = sys.argv[1:3]
idxs = [i for i in indices.split(',') if i]
# Mirror the real staking-deposit-cli: ONE timestamped file for ALL validators,
# not one file per index. Fixed epoch keeps the assertion deterministic.
path = os.path.join(out_dir, 'bls_to_execution_change-1700000000.json')
with open(path, 'w') as fh:
    json.dump({'mock': True, 'validator_indices': idxs}, fh)
    fh.write('\n')
PYEOF
EOF

    cat > "$temp_root/bin/curl" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
: "${MOCK_CURL_LOG:?missing MOCK_CURL_LOG}"
echo "[MOCK] curl $*" >> "$MOCK_CURL_LOG"
printf '200'
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
test_submit_requires_generation_manifest() {
    local temp_root output curl_log out_dir
    temp_root="$(setup_fake_env)"
    curl_log="$temp_root/curl.log"
    out_dir="$temp_root/stale"
    mkdir -p "$out_dir"
    printf '{"mock":true}\n' > "$out_dir/bls_to_execution_change-101.json"

    set +e
    output="$(MOCK_CURL_LOG="$curl_log" PATH="$temp_root/bin:$PATH" "$PROJECT_ROOT/install/utils/validator_withdrawal_changes.sh"         --validators-json "$temp_root/validators.json"         --credential-type 0x00         --submit         --yes         --out-dir "$out_dir"         --deposit-tool deposit-sh         --beacon-url http://127.0.0.1:5052 2>&1)"
    local rc=$?
    set -e

    [[ $rc -ne 0 ]]
    printf '%s
' "$output" | grep -q 'Missing generation manifest'
    assert_file_empty "$curl_log"

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_submit_only_accepts_manifest_withdrawal_address() {
    local temp_root output curl_log out_dir
    temp_root="$(setup_fake_env)"
    curl_log="$temp_root/curl.log"
    out_dir="$temp_root/generated"
    mkdir -p "$out_dir"
    printf '{"mock":true}\n' > "$out_dir/bls_to_execution_change-101.json"
    cat > "$out_dir/.eth2qs-withdrawal-manifest" <<'JSONEOF'
{
  "chain": "mainnet",
  "selector": "0x00",
  "validator_indices": "101",
  "withdrawal_credentials": "0x00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "withdrawal_address": "0x1111111111111111111111111111111111111111",
  "expected_files": ["bls_to_execution_change-101.json"]
}
JSONEOF

    output="$(MOCK_CURL_LOG="$curl_log" PATH="$temp_root/bin:$PATH" "$PROJECT_ROOT/install/utils/validator_withdrawal_changes.sh" \
        --validators-json "$temp_root/validators.json" \
        --credential-type 0x00 \
        --submit \
        --yes \
        --out-dir "$out_dir" \
        --deposit-tool deposit-sh \
        --beacon-url http://127.0.0.1:5052)"

    printf '%s\n' "$output" | grep -q "Submitting bls_to_execution_change-101.json"
    assert_contains "/eth/v1/beacon/pool/bls_to_execution_changes" "$curl_log"

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_generate_and_submit_0x00_changes() {
    local temp_root output deposit_log curl_log out_dir mnemonic_log
    temp_root="$(setup_fake_env)"
    deposit_log="$temp_root/deposit.log"
    curl_log="$temp_root/curl.log"
    mnemonic_log="$temp_root/mnemonic.stdin.log"
    out_dir="$temp_root/generated"

    output="$(MOCK_DEPOSIT_LOG="$deposit_log" MOCK_CURL_LOG="$curl_log" MOCK_MNEMONIC_LOG="$mnemonic_log" PATH="$temp_root/bin:$PATH" "$PROJECT_ROOT/install/utils/validator_withdrawal_changes.sh" \
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
    test -f "$out_dir/bls_to_execution_change-1700000000.json"
    assert_contains "/eth/v1/beacon/pool/bls_to_execution_changes" "$curl_log"

    # Security: the master mnemonic must NOT appear on argv (it would be visible
    # in /proc/<pid>/cmdline and `ps`). It must instead be delivered on stdin.
    if grep -q -- '--mnemonic=' "$deposit_log"; then return 1; fi
    assert_contains "abandon abandon abandon" "$mnemonic_log"

    printf '%s\n' "$output" | grep -q "Submitting bls_to_execution_change-1700000000.json"

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Validator Withdrawal Change Test Suite"
echo "=========================================="

run_test "dry run reports without invoking tools" test_dry_run_reports_without_invoking_tools
run_test "inventory shows withdrawal types" test_inventory_shows_withdrawal_types
run_test "submit requires generation manifest" test_submit_requires_generation_manifest
run_test "submit only accepts manifest withdrawal address" test_submit_only_accepts_manifest_withdrawal_address
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
