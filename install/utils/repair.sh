#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/lib/common_functions.sh"

APPLY=false
CONFIRM=false

usage() {
    cat <<'EOF'
Usage: ./install/utils/repair.sh [--apply --confirm]

Default behavior prints a smart repair preview from `stats --json`.

Options:
  --apply      Execute only allowlisted safe restart actions from the preview
  --confirm    Required with --apply
  --help       Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --apply)
            APPLY=true
            ;;
        --confirm)
            CONFIRM=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

load_stats_payload() {
    if [[ -n "${REPAIR_STATS_PAYLOAD:-}" ]]; then
        printf '%s' "$REPAIR_STATS_PAYLOAD"
    else
        "$PROJECT_ROOT/install/utils/stats.sh" --json
    fi
}

safe_restart_services() {
    local script
    script="$(cat <<'PY'
import json
import re
import sys

payload = json.load(sys.stdin)
seen = set()
for item in payload.get("repair_preview", []):
    if not item.get("safe"):
        continue
    command = str(item.get("command", ""))
    match = re.fullmatch(r"sudo systemctl restart ([a-z0-9-]+)", command)
    if not match:
        continue
    service = match.group(1)
    if service not in seen:
        seen.add(service)
        print(service)
PY
)"
    python3 -c "$script"
}

show_preview() {
    local script
    script="$(cat <<'PY'
import json
import re
import sys

payload = json.load(sys.stdin)
summary = payload.get("summary", {})
issues = payload.get("issues", [])
print(f"Status: {summary.get('status', 'unknown')}")
print(f"Issues detected: {len(issues)}")
print("")
if not issues:
    print("No issues detected.")
else:
    print("Issues:")
    for issue in issues:
        label = f"{issue.get('severity', 'info')}: {issue.get('kind', 'issue')}"
        if issue.get("service"):
            label += f" [{issue['service']}]"
        print(f"- {label}")
        print(f"  summary: {issue.get('summary', '')}")
        print(f"  next: {issue.get('suggested_action', '')}")

safe_commands = []
for item in payload.get("repair_preview", []):
    if not item.get("safe"):
        continue
    command = str(item.get("command", ""))
    if re.fullmatch(r"sudo systemctl restart [a-z0-9-]+", command):
        safe_commands.append(command)

print("")
if safe_commands:
    print("Safe auto-repair candidates:")
    for command in dict.fromkeys(safe_commands):
        print(f"- {command}")
else:
    print("No safe auto-repair commands available.")
PY
)"
    python3 -c "$script"
}

payload="$(load_stats_payload)"

if [[ "$APPLY" == "false" ]]; then
    printf '%s' "$payload" | show_preview
    exit 0
fi

if [[ "$CONFIRM" != "true" ]]; then
    log_error "Refusing to execute repair actions without --confirm."
    exit 1
fi

mapfile -t services < <(printf '%s' "$payload" | safe_restart_services)

if [[ "${#services[@]}" -eq 0 ]]; then
    log_warn "No allowlisted safe restart actions were detected."
    exit 0
fi

failures=0
for service in "${services[@]}"; do
    if service_exists "$service"; then
        log_info "Smart repair: restarting $service"
        if ! sudo systemctl restart "$service"; then
            log_warn "Failed to restart $service"
            failures=$((failures + 1))
        fi
    else
        log_warn "Skipping missing service: $service"
    fi
done

if [[ "${REPAIR_SKIP_POST_STATS:-false}" != "true" ]]; then
    log_info "Post-repair stats:"
    "$PROJECT_ROOT/install/utils/stats.sh"
fi

if [[ "$failures" -gt 0 ]]; then
    exit 1
fi
