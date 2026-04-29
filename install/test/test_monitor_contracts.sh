#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEBUG_SCRIPT="$PROJECT_ROOT/install/utils/debug.sh"
UPDATE_CHECK_SCRIPT="$PROJECT_ROOT/install/utils/update_check.sh"
MONITOR_SCRIPT="$PROJECT_ROOT/install/utils/monitor.sh"

stats_fixture='{"summary":{"status":"warn","services_failed":1,"issues_detected":2},"service_states":{"cl":"running"},"issues":[{"kind":"planner_state","severity":"warn","summary":"needs phase1"}],"repair_preview":[],"doctor_summary":{"status":"warn"},"repo_status":{"upstream":"origin/master","ahead":0,"behind":1}}'
update_fixture='{"summary":{"status":"warn","outdated_components":1,"repo_behind_commits":2},"checks":[{"component":"geth","status":"warn","summary":"outdated"}]}'
debug_fixture='{"summary":{"status":"warn","services_examined":1,"services_failed":0,"services_stopped":0,"issues_detected":2},"services":[{"service":"cl","status":"running","unit":{"active_state":"active","sub_state":"running","unit_file_state":"enabled","fragment_path":"/etc/systemd/system/cl.service","exec_start":"/usr/bin/cl","main_pid":1234},"recent_error":null,"listen_sockets":[],"recent_log_tail":["log line"]}],"issues":[{"kind":"planner_state","severity":"warn","summary":"needs phase1"}]}'

echo "=========================================="
echo "Monitor Contract Test Suite"
echo "=========================================="

if ETH2QS_UPDATE_CHECK_FIXTURE="$update_fixture" "$UPDATE_CHECK_SCRIPT" --json | python3 -c '
import json, sys
payload = json.load(sys.stdin)
assert payload["summary"]["status"] == "warn"
assert payload["summary"]["outdated_components"] == 1
print("ok")
'
then
    echo "PASS: update-check --json emits the expected contract"
else
    echo "FAIL: update-check --json contract check failed"
    exit 1
fi

if ETH2QS_DEBUG_FIXTURE="$debug_fixture" "$DEBUG_SCRIPT" --json | python3 -c '
import json, sys
payload = json.load(sys.stdin)
assert payload["summary"]["services_examined"] == 1
assert payload["services"][0]["service"] == "cl"
print("ok")
'
then
    echo "PASS: debug --json emits the expected contract"
else
    echo "FAIL: debug --json contract check failed"
    exit 1
fi

monitor_dir="$(mktemp -d)"
trap 'rm -rf "$monitor_dir"' EXIT

if ETH2QS_MONITOR_DIR="$monitor_dir" \
   ETH2QS_MONITOR_STATS_FIXTURE="$stats_fixture" \
   ETH2QS_MONITOR_UPDATE_FIXTURE="$update_fixture" \
   "$MONITOR_SCRIPT" export --json | python3 -c '
import json, sys
payload = json.load(sys.stdin)
assert payload["summary"]["status"] == "warn"
assert payload["summary"]["repo_behind_commits"] == 2
print("ok")
'
then
    echo "PASS: monitor export --json emits the expected contract"
else
    echo "FAIL: monitor export --json contract check failed"
    exit 1
fi

snapshot_output="$(ETH2QS_MONITOR_DIR="$monitor_dir" ETH2QS_MONITOR_STATS_FIXTURE="$stats_fixture" ETH2QS_MONITOR_UPDATE_FIXTURE="$update_fixture" "$MONITOR_SCRIPT" snapshot --json)"
snapshot_path="$(printf '%s' "$snapshot_output" | python3 -c 'import json,sys; print(json.load(sys.stdin)["path"])')"

if [[ -f "$snapshot_path" ]]; then
    echo "PASS: monitor snapshot writes a snapshot file"
else
    echo "FAIL: monitor snapshot did not write a snapshot file"
    exit 1
fi

if ETH2QS_MONITOR_DIR="$monitor_dir" "$MONITOR_SCRIPT" history --json --limit 5 | python3 -c '
import json, sys
payload = json.load(sys.stdin)
assert payload["summary"]["entries"] >= 1
print("ok")
'
then
    echo "PASS: monitor history --json emits the expected contract"
else
    echo "FAIL: monitor history --json contract check failed"
    exit 1
fi

echo
echo "All tests passed!"
