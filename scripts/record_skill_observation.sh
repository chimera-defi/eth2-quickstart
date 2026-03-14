#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="${SKILL_OBSERVATIONS_FILE:-$ROOT_DIR/docs/skill-observations.jsonl}"

SKILL=""
TASK=""
RESULT=""
COMMAND=""
EVIDENCE=""
NOTES=""
PRINT_ONLY=false

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

usage() {
    cat <<'EOF'
Usage: ./scripts/record_skill_observation.sh --skill <name> --task <task> --result <success|failure> [options]

Options:
  --command <cmd>     Canonical command or operation that was attempted
  --evidence <text>   Concrete failure/success signal
  --notes <text>      Optional follow-up context
  --print-only        Print JSON without appending to the observations file
  --help              Show this help text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skill)
            SKILL="${2:-}"
            shift
            ;;
        --task)
            TASK="${2:-}"
            shift
            ;;
        --result)
            RESULT="${2:-}"
            shift
            ;;
        --command)
            COMMAND="${2:-}"
            shift
            ;;
        --evidence)
            EVIDENCE="${2:-}"
            shift
            ;;
        --notes)
            NOTES="${2:-}"
            shift
            ;;
        --print-only)
            PRINT_ONLY=true
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

if [[ -z "$SKILL" || -z "$TASK" || -z "$RESULT" ]]; then
    echo "Missing required fields." >&2
    usage >&2
    exit 1
fi

if [[ "$RESULT" != "success" && "$RESULT" != "failure" ]]; then
    echo "--result must be 'success' or 'failure'" >&2
    exit 1
fi

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
GIT_SHA="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

json_line="$(printf '{\"timestamp\":\"%s\",\"skill\":\"%s\",\"task\":\"%s\",\"result\":\"%s\",\"command\":\"%s\",\"evidence\":\"%s\",\"notes\":\"%s\",\"git_sha\":\"%s\"}' \
    "$(json_escape "$TIMESTAMP")" \
    "$(json_escape "$SKILL")" \
    "$(json_escape "$TASK")" \
    "$(json_escape "$RESULT")" \
    "$(json_escape "$COMMAND")" \
    "$(json_escape "$EVIDENCE")" \
    "$(json_escape "$NOTES")" \
    "$(json_escape "$GIT_SHA")")"

if [[ "$PRINT_ONLY" == "true" ]]; then
    printf '%s\n' "$json_line"
    exit 0
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
printf '%s\n' "$json_line" >> "$OUTPUT_FILE"
printf '%s\n' "$json_line"
