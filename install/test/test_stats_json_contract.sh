#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATS_SCRIPT="$PROJECT_ROOT/install/utils/stats.sh"

echo "=========================================="
echo "Stats JSON Contract Test Suite"
echo "=========================================="

output="$("$STATS_SCRIPT" --json)"

if printf '%s' "$output" | python3 -c '
import json
import sys

payload = json.load(sys.stdin)
assert "summary" in payload
assert "service_states" in payload
assert "versions" in payload
assert "issues" in payload
assert "repair_preview" in payload
assert payload["summary"]["status"] in {"pass", "warn", "fail"}
assert isinstance(payload["service_states"], dict)
assert isinstance(payload["recent_errors"], list)
assert isinstance(payload["repair_preview"], list)
print("ok")
'
then
    echo "PASS: stats --json emits the expected monitoring contract"
else
    echo "FAIL: stats --json contract check failed"
    exit 1
fi

echo
echo "All tests passed!"
