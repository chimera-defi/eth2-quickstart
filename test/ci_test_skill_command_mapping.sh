#!/bin/bash
# CI test for eth2-quickstart skill command mapping.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_PREFIX="CI"
# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

SKILL_DIR="$PROJECT_ROOT/skills/eth2-quickstart"
COMMANDS_REF="$SKILL_DIR/references/commands.md"
WORKFLOW_REF="$SKILL_DIR/references/workflow.md"
OUTPUTS_REF="$SKILL_DIR/references/outputs.md"

log_info "=== CI Test: eth2-quickstart skill command mapping ==="

canonical_commands=(
    "./scripts/eth2qs.sh bootstrap"
    "./scripts/eth2qs.sh configure"
    "./scripts/eth2qs.sh plan --json"
    "./scripts/eth2qs.sh ensure"
    "./scripts/eth2qs.sh phase1"
    "./scripts/eth2qs.sh phase2"
    "./scripts/eth2qs.sh monad-install"
    "./scripts/eth2qs.sh doctor --json"
    "./scripts/eth2qs.sh start"
    "./scripts/eth2qs.sh repair"
    "./scripts/eth2qs.sh stop"
    "./scripts/eth2qs.sh stats"
    "./scripts/eth2qs.sh logs"
    "./scripts/eth2qs.sh clean-data"
    "./scripts/eth2qs.sh cleanup-host"
    "./scripts/eth2qs.sh update-all"
)

for cmd in "${canonical_commands[@]}"; do
    if grep -Fq "$cmd" "$COMMANDS_REF"; then
        record_test "commands.md maps canonical command: $cmd" "PASS"
    else
        record_test "commands.md maps canonical command: $cmd" "FAIL"
    fi
done

if grep -Fq "install.sh" "$WORKFLOW_REF" &&
   grep -Fq "run_1.sh" "$WORKFLOW_REF" &&
   grep -Fq "run_2.sh" "$WORKFLOW_REF"; then
    record_test "workflow.md covers bootstrap and both phases" "PASS"
else
    record_test "workflow.md covers bootstrap and both phases" "FAIL"
fi

if grep -Fq "Fresh Host Bootstrap" "$SKILL_DIR/references/operator.md" &&
   grep -Fq "./scripts/eth2qs.sh plan --json" "$SKILL_DIR/references/operator.md" &&
   grep -Fq "./scripts/eth2qs.sh repair --apply --confirm" "$SKILL_DIR/references/operator.md" &&
   grep -Fq "./scripts/eth2qs.sh stop" "$SKILL_DIR/references/operator.md" &&
   grep -Fq "./scripts/eth2qs.sh update-all" "$SKILL_DIR/references/operator.md"; then
    record_test "operator.md covers install, operate, and update flows" "PASS"
else
    record_test "operator.md covers install, operate, and update flows" "FAIL"
fi

if grep -Fq "./scripts/eth2qs.sh doctor --json" "$OUTPUTS_REF" &&
   grep -Fq "./scripts/eth2qs.sh stats --json" "$OUTPUTS_REF" &&
   grep -Fq "machine-readable" "$OUTPUTS_REF"; then
    record_test "outputs.md documents doctor/stats JSON paths" "PASS"
else
    record_test "outputs.md documents doctor/stats JSON paths" "FAIL"
fi

if grep -Fq "./scripts/eth2qs.sh doctor --json" "$PROJECT_ROOT/scripts/eth2qs.sh"; then
    record_test "wrapper exposes doctor JSON example" "PASS"
else
    record_test "wrapper exposes doctor JSON example" "FAIL"
fi

if grep -Fq "bootstrap)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "plan)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "ensure)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "monad-install)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "repair)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "stop)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "stats)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "clean-data)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "cleanup-host)" "$PROJECT_ROOT/scripts/eth2qs.sh" &&
   grep -Fq "update-all)" "$PROJECT_ROOT/scripts/eth2qs.sh"; then
    record_test "wrapper implements documented lifecycle/cleanup commands" "PASS"
else
    record_test "wrapper implements documented lifecycle/cleanup commands" "FAIL"
fi

print_test_summary
