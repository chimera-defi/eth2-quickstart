#!/bin/bash
# View run_1.sh, run_2.sh, and security validation logs
# Usage: ./install/utils/view_logs.sh [--list|--run1|--run2|--security] [-n N] [-f]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RUN1_DIR="/var/log/eth2-quickstart"
RUN2_DIR="$ROOT/logs"

LINES=50
FOLLOW=false
MODE="latest"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)
            MODE="list"
            shift
            ;;
        --run1)
            MODE="run1"
            shift
            ;;
        --run2)
            MODE="run2"
            shift
            ;;
        --security)
            MODE="security"
            shift
            ;;
        -n)
            LINES="$2"
            shift 2
            ;;
        -f)
            FOLLOW=true
            shift
            ;;
        *)
            echo "Usage: $0 [--list|--run1|--run2|--security] [-n N] [-f]"
            echo "  --list     List all logs"
            echo "  --run1     Latest run_1.sh log"
            echo "  --run2     Latest run_2.sh log"
            echo "  --security Latest security validation log"
            echo "  -n N       Show last N lines (default 50)"
            echo "  -f         Follow (like tail -f)"
            exit 0
            ;;
    esac
done

latest() {
    local dir="$1"
    local pattern="$2"
    [[ -d "$dir" ]] || return 1
    find "$dir" -maxdepth 1 -name "$pattern" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-
}

case "$MODE" in
    list)
        echo "=== run_1.sh (sudo may be needed) ==="
        if [[ -d "$RUN1_DIR" ]]; then
            ls -la "$RUN1_DIR"/*.log 2>/dev/null || echo "  (none)"
        else
            echo "  (dir not found)"
        fi
        echo ""
        echo "=== run_2.sh / security validation ==="
        if [[ -d "$RUN2_DIR" ]]; then
            ls -la "$RUN2_DIR"/*.log 2>/dev/null || echo "  (none)"
        else
            echo "  (dir not found)"
        fi
        ;;
    run1)
        f=$(latest "$RUN1_DIR" "run_1_*.log")
        if [[ -z "$f" ]]; then
            echo "No run_1.sh logs in $RUN1_DIR"
            exit 1
        fi
        if [[ -r "$f" ]]; then
            if [[ "$FOLLOW" == true ]]; then tail -n "$LINES" -f "$f"; else tail -n "$LINES" "$f"; fi
        else
            if [[ "$FOLLOW" == true ]]; then sudo tail -n "$LINES" -f "$f"; else sudo tail -n "$LINES" "$f"; fi
        fi
        ;;
    run2)
        f=$(latest "$RUN2_DIR" "run_2_*.log")
        if [[ -z "$f" || ! -r "$f" ]]; then
            echo "No run_2.sh logs in $RUN2_DIR"
            exit 1
        fi
        if [[ "$FOLLOW" == true ]]; then tail -n "$LINES" -f "$f"; else tail -n "$LINES" "$f"; fi
        ;;
    security)
        f=$(latest "$RUN2_DIR" "security_validation_*.log")
        if [[ -z "$f" || ! -r "$f" ]]; then
            echo "No security validation logs in $RUN2_DIR"
            exit 1
        fi
        if [[ "$FOLLOW" == true ]]; then tail -n "$LINES" -f "$f"; else tail -n "$LINES" "$f"; fi
        ;;
    latest)
        f=$(latest "$RUN2_DIR" "run_2_*.log")
        [[ -z "$f" ]] && f=$(latest "$RUN2_DIR" "security_validation_*.log")
        [[ -z "$f" ]] && f=$(latest "$RUN1_DIR" "run_1_*.log")
        if [[ -z "$f" ]]; then
            echo "No logs found. Run run_1.sh or run_2.sh first."
            exit 1
        fi
        echo "=== $(basename "$f") ==="
        if [[ -r "$f" ]]; then
            if [[ "$FOLLOW" == true ]]; then tail -n "$LINES" -f "$f"; else tail -n "$LINES" "$f"; fi
        else
            if [[ "$FOLLOW" == true ]]; then sudo tail -n "$LINES" -f "$f"; else sudo tail -n "$LINES" "$f"; fi
        fi
        ;;
esac
