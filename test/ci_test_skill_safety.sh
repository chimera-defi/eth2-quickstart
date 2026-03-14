#!/bin/bash
# CI test for eth2-quickstart skill safety guarantees.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

SKILL_DIR="$PROJECT_ROOT/skills/eth2-quickstart"
SKILL_FILE="$SKILL_DIR/SKILL.md"
SAFETY_REF="$SKILL_DIR/references/safety.md"
COMMANDS_REF="$SKILL_DIR/references/commands.md"
ALL_SKILL_FILES=("$SKILL_FILE" "$SAFETY_REF" "$COMMANDS_REF" "$SKILL_DIR/references/workflow.md" "$SKILL_DIR/references/operator.md" "$SKILL_DIR/references/outputs.md" "$SKILL_DIR/references/examples.md" "$SKILL_DIR/references/improvement.md")

log_info "=== CI Test: eth2-quickstart skill safety ==="

if grep -Fq "Do not generate validator keys" "$SKILL_FILE" &&
   grep -Fq "Do not remove secrets" "$SKILL_FILE"; then
    record_test "SKILL.md states key and secret boundaries" "PASS"
else
    record_test "SKILL.md states key and secret boundaries" "FAIL"
fi

if grep -Fq "Require human confirmation" "$SAFETY_REF" &&
   grep -Fq "root" "$SAFETY_REF" &&
   grep -Fq "reboot" "$SAFETY_REF"; then
    record_test "safety.md covers confirmation, root, and reboot boundaries" "PASS"
else
    record_test "safety.md covers confirmation, root, and reboot boundaries" "FAIL"
fi

if grep -Fq "Preserving key/secret paths" "$PROJECT_ROOT/install/utils/purge_ethereum_data.sh" &&
   grep -Fq "preserve secrets" "$SAFETY_REF"; then
    record_test "cleanup guidance matches preserve-secrets implementation" "PASS"
else
    record_test "cleanup guidance matches preserve-secrets implementation" "FAIL"
fi

for file in "${ALL_SKILL_FILES[@]}"; do
    if rg -n 'curl[^[:cntrl:]]*\|\s*(sudo\s+)?bash|wget[^[:cntrl:]]*-O-[^[:cntrl:]]*\|\s*(sudo\s+)?bash' "$file" >/dev/null; then
        record_test "no inline remote bootstrap in ${file#"$PROJECT_ROOT"/}" "FAIL"
    else
        record_test "no inline remote bootstrap in ${file#"$PROJECT_ROOT"/}" "PASS"
    fi
done

if grep -Fq "./scripts/eth2qs.sh clean-data --dry-run" "$COMMANDS_REF"; then
    record_test "cleanup guidance prefers dry-run first" "PASS"
else
    record_test "cleanup guidance prefers dry-run first" "FAIL"
fi

print_test_summary
