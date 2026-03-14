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
find_sh_files() {
  find . -name "*.sh" -type f \
    ! -path "./.git/*" \
    ! -path "./frontend/node_modules/*" \
    ! -path "./frontend/.next/*"
}

while IFS= read -r f; do
  head -1 "$f" | grep -q "^#!/" || { echo "❌ $f lacks shebang"; failed=1; }
done < <(find_sh_files)
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
done < <(find_sh_files)
[[ $failed -eq 1 ]] && exit 1

echo "=== run_1/run_2 structure ==="
for s in run_1.sh run_2.sh; do
  [[ -f "$s" ]] || continue
  grep -q "source.*exports.sh" "$s" || { echo "❌ $s must source exports.sh"; exit 1; }
done

echo "=== Common functions unit tests ==="
bash install/test/test_common_functions.sh
bash install/test/test_ensure_dispatch.sh
bash install/test/test_plan_json.sh
bash install/test/test_install_planner.sh

echo "=== Docs consistency ==="
bash test/ci_test_docs_consistency.sh

echo "=== Agent skill checks ==="
bash test/ci_test_skill_structure.sh
bash test/ci_test_skill_command_mapping.sh
bash test/ci_test_skill_safety.sh
bash test/ci_test_skill_distribution.sh

echo "✅ Pre-commit checks passed."
