#!/bin/bash
# Run shellcheck on all scripts (same as CI)
# Usage: ./run_shellcheck.sh
# Run before push to catch issues locally

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

SHELLCHECK_EXCLUDES="SC2317,SC1091,SC1090,SC2034,SC2031,SC2181"

if ! command -v shellcheck &>/dev/null; then
    echo "Error: shellcheck not found. Install with: sudo apt-get install shellcheck"
    exit 1
fi

echo "Running shellcheck on all shell scripts..."
fail=0
while IFS= read -r -d '' script; do
    if ! shellcheck -x --exclude="$SHELLCHECK_EXCLUDES" "$script"; then
        echo "❌ $script"
        fail=1
    fi
done < <(find . -name "*.sh" -type f ! -path "./.git/*" ! -path "./erigon/*" ! -path "./reth/*" -print0)

if [[ $fail -eq 1 ]]; then
    echo "Shellcheck failed. Fix issues above before pushing."
    exit 1
fi
echo "✅ All scripts passed shellcheck"
exit 0
