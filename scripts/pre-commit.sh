#!/bin/bash
# Pre-commit checks matching shellcheck.yml. Run before pushing.
# Usage: ./scripts/pre-commit.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=== Shellcheck + syntax ==="
./test/run_tests.sh --lint-only

echo "=== Shebang check ==="
failed=0
while IFS= read -r f; do
  head -1 "$f" | grep -q "^#!/" || { echo "❌ $f lacks shebang"; failed=1; }
done < <(find . -name "*.sh" -type f ! -path "./.git/*")
[[ $failed -eq 1 ]] && exit 1

echo "=== Dependency validation ==="
failed=0
while IFS= read -r script; do
  script_dir=$(dirname "$script")
  while IFS= read -r line; do
    sf=$(echo "$line" | sed -n 's/.*source[[:space:]]*["\x27]*\([^"'\''[:space:]]*\)["\x27]*.*/\1/p')
    [[ -z "$sf" ]] || [[ "$sf" == \$* ]] || [[ "$sf" == *\$* ]] && continue
    [[ "$sf" == ~/* ]] || [[ "$sf" == /dev/null ]] || [[ "$sf" == *cargo/env* ]] && continue
    if [[ "$sf" == ./* ]] || [[ "$sf" == ../* ]]; then
      res=$(cd "$script_dir" && realpath "$sf" 2>/dev/null || echo "")
    else
      res="$sf"
    fi
    if [[ -n "$res" ]] && [[ ! -f "$res" ]]; then
      echo "❌ $script sources missing: $sf"; failed=1
    fi
  done < <(grep -n '^[[:space:]]*source[[:space:]]' "$script" 2>/dev/null || true)
done < <(find . -name "*.sh" -type f ! -path "./.git/*")
[[ $failed -eq 1 ]] && exit 1

echo "=== run_1/run_2 structure ==="
for s in run_1.sh run_2.sh; do
  [[ -f "$s" ]] || continue
  grep -q "source.*exports.sh" "$s" || { echo "❌ $s must source exports.sh"; exit 1; }
done

echo "=== Common functions unit tests ==="
bash install/test/test_common_functions.sh

echo "✅ Pre-commit checks passed."
