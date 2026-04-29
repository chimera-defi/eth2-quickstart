#!/bin/bash
# CI test for eth2-quickstart skill structure.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

SKILL_DIR="$PROJECT_ROOT/skills/eth2-quickstart"
SKILL_FILE="$SKILL_DIR/SKILL.md"

log_info "=== CI Test: eth2-quickstart skill structure ==="

required_files=(
    "$SKILL_FILE"
    "$SKILL_DIR/references/workflow.md"
    "$SKILL_DIR/references/operator.md"
    "$SKILL_DIR/references/commands.md"
    "$SKILL_DIR/references/safety.md"
    "$SKILL_DIR/references/sizing.md"
    "$SKILL_DIR/references/outputs.md"
    "$SKILL_DIR/references/examples.md"
    "$SKILL_DIR/references/improvement.md"
)

for file in "${required_files[@]}"; do
    assert_file_exists "$file" "${file#"$PROJECT_ROOT"/}"
done

if head -n 1 "$SKILL_FILE" | grep -q '^---$' &&
   awk 'NR>1 && /^---$/ {found=1; exit} END {exit(found ? 0 : 1)}' "$SKILL_FILE"; then
    record_test "SKILL.md has YAML frontmatter block" "PASS"
else
    record_test "SKILL.md has YAML frontmatter block" "FAIL"
fi

if grep -q '^name: eth2-quickstart$' "$SKILL_FILE"; then
    record_test "SKILL.md declares skill name" "PASS"
else
    record_test "SKILL.md declares skill name" "FAIL"
fi

if grep -q '^description: ' "$SKILL_FILE"; then
    record_test "SKILL.md declares skill description" "PASS"
else
    record_test "SKILL.md declares skill description" "FAIL"
fi

mapfile -t reference_links < <(sed -nE 's/.*\((references\/[^)#?[:space:]]+).*/\1/p' "$SKILL_FILE")
if [[ "${#reference_links[@]}" -ge 4 ]]; then
    record_test "SKILL.md links reference files" "PASS"
else
    record_test "SKILL.md links reference files" "FAIL"
fi

for rel in "${reference_links[@]}"; do
    if [[ -f "$SKILL_DIR/$rel" ]]; then
        record_test "reference link resolves: $rel" "PASS"
    else
        record_test "reference link resolves: $rel" "FAIL"
    fi
done

print_test_summary
