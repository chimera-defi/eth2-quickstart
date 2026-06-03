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

# shellcheck disable=SC2317
test_query_beacon_validators_normalizes_prefixed_pubkeys() {
    local temp_root runner url_log output_json
    temp_root="$(mktemp -d)"
    runner="$temp_root/run.sh"
    url_log="$temp_root/url.log"

    cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
source "$PROJECT_ROOT/install/utils/validator_list.sh"
curl() {
    printf '%s\n' "$*" >> "$temp_root/url.log"
    cat <<'JSONEOF'
{"data":[{"index":"1","balance":"32000000000","validator":{"pubkey":"0x1111111111111111111111111111111111111111111111111111111111111111","withdrawal_credentials":"0x0100000000000000000000000000000000000000000000000000000000000000"}}]}
JSONEOF
}
query_beacon_validators "http://127.0.0.1:5052" "$temp_root/out.json" 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
cat "$temp_root/out.json"
EOF
    chmod +x "$runner"

    output_json="$(bash "$runner")"

    if grep -q '0x0x' "$url_log"; then
        return 1
    fi
    grep -q 'id=0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' "$url_log"
    python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))["data"]))' "$temp_root/out.json" | grep -q '^1$'
    [[ -n "$output_json" ]]

    rm -rf "$temp_root"
}

# shellcheck disable=SC2317
test_batches_validator_queries() {
    local temp_root runner output_json validator_count call_count first_call second_call
    temp_root="$(mktemp -d)"
    runner="$temp_root/run.sh"

    cat > "$runner" <<EOF
#!/bin/bash
set -euo pipefail
source "$PROJECT_ROOT/install/utils/validator_list.sh"
CALLS_FILE="$temp_root/calls.txt"
: > "\$CALLS_FILE"
query_beacon_validators() {
    echo "\$#" >> "\$CALLS_FILE"
    local out_file="\$2"
    local row_count="\$(( \$# - 2 ))"
    python3 - "\$out_file" "\$row_count" <<'PYEOF'
import json, sys
out_file = sys.argv[1]
row_count = int(sys.argv[2])
rows = []
for i in range(row_count):
    rows.append({
        "index": str(i),
        "balance": str(32000000000),
        "validator": {
            "pubkey": f"0x{i:096x}",
            "withdrawal_credentials": "0x0100000000000000000000000000000000000000000000000000000000000000",
        },
    })
with open(out_file, 'w') as fh:
    json.dump({"data": rows}, fh)
PYEOF
}
query_beacon_validators_batched "http://127.0.0.1:5052" "$temp_root/out.json" "\$@"
cat "$temp_root/out.json"
EOF
    chmod +x "$runner"

    mapfile -t pubkeys < <(python3 - <<'PYEOF'
for i in range(1, 102):
    print(f"0x{i:096x}")
PYEOF
)

    output_json="$(bash "$runner" "${pubkeys[@]}")"

    call_count="$(wc -l < "$temp_root/calls.txt")"
    first_call="$(sed -n '1p' "$temp_root/calls.txt")"
    second_call="$(sed -n '2p' "$temp_root/calls.txt")"
    validator_count="$(python3 -c 'import json, sys; print(len(json.load(open(sys.argv[1]))["data"]))' "$temp_root/out.json")"

    rm -rf "$temp_root"

    [[ "$call_count" -eq 2 ]]
    [[ "$first_call" -eq 100 ]]
    [[ "$second_call" -eq 1 ]]
    [[ "$validator_count" -eq 101 ]]
    [[ -n "$output_json" ]]
}

# shellcheck disable=SC2317
test_prysm_pubkey_discovery_uses_cli_fallback() {
    local temp_root pubkey_a pubkey_b output
    temp_root="$(mktemp -d)"
    pubkey_a="0x$(printf 'a%.0s' {1..96})"
    pubkey_b="0x$(printf 'b%.0s' {1..96})"

    mkdir -p "$temp_root/prysm" "$temp_root/.eth2validators/prysm-wallet-v2/direct/accounts" "$temp_root/secrets"

    cat > "$temp_root/prysm/prysm.sh" <<EOF
#!/bin/bash
set -euo pipefail
if [[ "\$1" != "validator" || "\$2" != "accounts" || "\$3" != "list" ]]; then
    echo "unexpected prysm command: \$*" >&2
    exit 1
fi
cat <<'OUT'
Account 1: ${pubkey_a}
Account 2: ${pubkey_b}
OUT
EOF
    chmod +x "$temp_root/prysm/prysm.sh"

    cat > "$temp_root/.eth2validators/prysm-wallet-v2/direct/accounts/all-accounts.keystore.json" <<'EOF'
{"wallet":"placeholder"}
EOF
    printf '%s
' 'test-passphrase' > "$temp_root/secrets/pass.txt"

    output="$(bash -c '
        source "$1"
        HOME="$2" find_pubkeys prysm
    ' _ "$PROJECT_ROOT/install/utils/validator_list.sh" "$temp_root")"

    [[ "$output" == "$pubkey_a"$'
'"$pubkey_b" ]]

    rm -rf "$temp_root"
}

echo "=========================================="
echo "Validator List Test Suite"
echo "=========================================="

run_test "normalize prefixed validator pubkeys" test_query_beacon_validators_normalizes_prefixed_pubkeys
run_test "batch beacon validator queries" test_batches_validator_queries
run_test "prysm pubkey discovery uses cli fallback" test_prysm_pubkey_discovery_uses_cli_fallback

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
