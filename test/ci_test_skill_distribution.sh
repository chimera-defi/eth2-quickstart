#!/bin/bash
# CI test for eth2-quickstart skill distribution/install contract.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

SKILL_DIR="$PROJECT_ROOT/skills/eth2-quickstart"
SKILL_FILE="$SKILL_DIR/SKILL.md"
WORKFLOW_REF="$SKILL_DIR/references/workflow.md"
RESOLVER="$SKILL_DIR/scripts/resolve_repo_root.sh"
LLMS_FILE="$PROJECT_ROOT/llms.txt"
LLMS_FULL_FILE="$PROJECT_ROOT/llms-full.txt"

log_info "=== CI Test: eth2-quickstart skill distribution ==="

assert_file_exists "$RESOLVER" "skills/eth2-quickstart/scripts/resolve_repo_root.sh"
assert_valid_syntax "$RESOLVER" "resolve_repo_root.sh"
assert_file_exists "$LLMS_FILE" "llms.txt"
assert_file_exists "$LLMS_FULL_FILE" "llms-full.txt"

if repo_root="$(cd "$PROJECT_ROOT" && bash "$RESOLVER")" && [[ "$repo_root" == "$PROJECT_ROOT" ]]; then
    record_test "resolver works from repo root" "PASS"
else
    record_test "resolver works from repo root" "FAIL"
fi

if repo_root="$(cd "$SKILL_DIR" && bash "$RESOLVER")" && [[ "$repo_root" == "$PROJECT_ROOT" ]]; then
    record_test "resolver works from skill directory" "PASS"
else
    record_test "resolver works from skill directory" "FAIL"
fi

if grep -q '^metadata:$' "$SKILL_FILE" &&
   grep -q '^  openclaw:$' "$SKILL_FILE" &&
   grep -q '^    skillKey: eth2-quickstart$' "$SKILL_FILE"; then
    record_test "SKILL.md has OpenClaw metadata" "PASS"
else
    record_test "SKILL.md has OpenClaw metadata" "FAIL"
fi

if grep -Fq "npx clawhub install eth2-quickstart" "$WORKFLOW_REF" &&
   grep -Fq "ClawHub" "$SKILL_FILE" &&
   grep -Fq "resolve_repo_root.sh" "$WORKFLOW_REF"; then
    record_test "distribution docs state clawhub install contract" "PASS"
else
    record_test "distribution docs state clawhub install contract" "FAIL"
fi

if grep -Fq "Skill entrypoint" "$LLMS_FILE" &&
   grep -Fq "llms-full.txt" "$LLMS_FILE" &&
   grep -Fq "./scripts/eth2qs.sh doctor --json" "$LLMS_FULL_FILE"; then
    record_test "llms ingest files expose the skill and command surface" "PASS"
else
    record_test "llms ingest files expose the skill and command surface" "FAIL"
fi

print_test_summary
