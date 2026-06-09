#!/bin/bash
# Unit tests for install/utils/validator_filter.py (balance / withdrawal-type / status).
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FILTER="$PROJECT_ROOT/install/utils/validator_filter.py"

PASS=0
FAIL=0

FIXTURE="$(mktemp /tmp/vfilter_XXXXXX.json)"
trap 'rm -f "$FIXTURE"' EXIT
cat > "$FIXTURE" <<'JSON'
{"data":[
  {"index":"1","balance":"32000000000","status":"active_ongoing","validator":{"pubkey":"0xaa","withdrawal_credentials":"0x010000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
  {"index":"2","balance":"16000000000","status":"active_ongoing","validator":{"pubkey":"0xbb","withdrawal_credentials":"0x00bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}},
  {"index":"3","balance":"2048000000000","status":"active_ongoing","validator":{"pubkey":"0xcc","withdrawal_credentials":"0x020000000000000000000000cccccccccccccccccccccccccccccccccccccccc"}},
  {"index":"4","balance":"31000000000","status":"exited_unslashed","validator":{"pubkey":"0xdd","withdrawal_credentials":"0x010000000000000000000000dddddddddddddddddddddddddddddddddddddddd"}}
]}
JSON

# count(expected, label, filter-args...)
count() {
    local expected="$1" label="$2"; shift 2
    local got
    got=$(python3 "$FILTER" "$FIXTURE" "$@" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"]))')
    if [[ "$got" == "$expected" ]]; then
        echo "PASS: $label (got $got)"; PASS=$((PASS+1))
    else
        echo "FAIL: $label (expected $expected, got $got)"; FAIL=$((FAIL+1))
    fi
}

count 4 "no filter"
count 2 "withdrawal-type 0x01" --withdrawal-type 0x01
count 1 "withdrawal-type 0x00" --withdrawal-type 0x00
count 1 "withdrawal-type 0x02" --withdrawal-type 0x02
count 2 "min-balance 32"       --min-balance 32
count 2 "max-balance 31"       --max-balance 31
count 2 "min 17 max 100"       --min-balance 17 --max-balance 100
count 1 "status exited"        --status exited
count 1 "0x01 AND min 32"      --withdrawal-type 0x01 --min-balance 32
count 0 "0x02 AND max 100"     --withdrawal-type 0x02 --max-balance 100

# invalid withdrawal type rejected (exit 2)
if python3 "$FILTER" "$FIXTURE" --withdrawal-type 0x99 >/dev/null 2>&1; then
    echo "FAIL: invalid withdrawal-type should error"; FAIL=$((FAIL+1))
else
    echo "PASS: invalid withdrawal-type rejected"; PASS=$((PASS+1))
fi

echo "=== validator_filter: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
