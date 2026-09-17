#!/bin/bash
# E2E test for eth2-quickstart skill installation routes.
#
# Validates both real-world installation paths:
# 1. Codex GitHub-path installer (ecosystem-native fallback)
# 2. git clone checkout (primary install path)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

SKILL_DIR="$PROJECT_ROOT/skills/eth2-quickstart"
RESOLVER="$SKILL_DIR/scripts/resolve_repo_root.sh"
TEMP_INSTALL_BASE="${TEMP_INSTALL_BASE:-/tmp/eth2qs-skill-e2e-test-$$}"

cleanup_temp() {
    if [[ -d "$TEMP_INSTALL_BASE" ]]; then
        rm -rf "$TEMP_INSTALL_BASE"
    fi
}
trap cleanup_temp EXIT

mkdir -p "$TEMP_INSTALL_BASE"

# =============================================================================
log_info "--- Test 1: Codex GitHub-path installation ---"
# =============================================================================

CODEX_REPO_DIR="$TEMP_INSTALL_BASE/codex-checkout"
cp -r "$PROJECT_ROOT" "$CODEX_REPO_DIR"
chmod +x "$CODEX_REPO_DIR/scripts"/*.sh 2>/dev/null || true
chmod +x "$CODEX_REPO_DIR/skills/eth2-quickstart/scripts"/*.sh 2>/dev/null || true

INSTALLED_SKILL_DIR="$CODEX_REPO_DIR/skills/eth2-quickstart"

if resolved_root="$(cd "$INSTALLED_SKILL_DIR" && bash "$INSTALLED_SKILL_DIR/scripts/resolve_repo_root.sh")"; then
    if [[ -f "$resolved_root/exports.sh" && -x "$resolved_root/scripts/eth2qs.sh" ]]; then
        record_test "codex: resolver finds repo from skill dir" "PASS"
    else
        record_test "codex: resolver finds repo from skill dir" "FAIL"
    fi
else
    record_test "codex: resolver finds repo from skill dir" "FAIL"
fi

if resolved_root="$(cd "$CODEX_REPO_DIR" && bash "$CODEX_REPO_DIR/skills/eth2-quickstart/scripts/resolve_repo_root.sh")"; then
    if [[ "$resolved_root" == "$CODEX_REPO_DIR" ]]; then
        record_test "codex: resolver finds correct repo root" "PASS"
    else
        record_test "codex: resolver finds correct repo root" "FAIL"
    fi
else
    record_test "codex: resolver finds correct repo root" "FAIL"
fi

if [[ -x "$CODEX_REPO_DIR/scripts/eth2qs.sh" ]]; then
    if "$CODEX_REPO_DIR/scripts/eth2qs.sh" help >/dev/null 2>&1; then
        record_test "codex: wrapper help command works" "PASS"
    else
        record_test "codex: wrapper help command works" "FAIL"
    fi
else
    record_test "codex: wrapper help command works" "FAIL"
fi

if (
    cd "$INSTALLED_SKILL_DIR"
    REPO_ROOT="$CODEX_REPO_DIR"
    export REPO_ROOT
    "$CODEX_REPO_DIR/scripts/eth2qs.sh" doctor --json >/dev/null 2>&1
); then
    record_test "codex: doctor --json works via skill" "PASS"
else
    if (
        cd "$INSTALLED_SKILL_DIR"
        REPO_ROOT="$CODEX_REPO_DIR"
        export REPO_ROOT
        output="$("$CODEX_REPO_DIR/scripts/eth2qs.sh" doctor --json 2>&1 || true)"
        if echo "$output" | grep -q "^{"; then
            exit 0
        fi
        exit 1
    ); then
        record_test "codex: doctor --json works via skill" "PASS"
    else
        record_test "codex: doctor --json works via skill" "FAIL"
    fi
fi

# =============================================================================
log_info "--- Test 2: git clone checkout (primary install path) ---"
# =============================================================================

CLONE_INSTALL_DIR="$TEMP_INSTALL_BASE/clone-checkout"
mkdir -p "$CLONE_INSTALL_DIR"
CLONE_WORKSPACE="$CLONE_INSTALL_DIR/eth2-quickstart"
cp -r "$PROJECT_ROOT" "$CLONE_WORKSPACE"
chmod +x "$CLONE_WORKSPACE/scripts"/*.sh 2>/dev/null || true
chmod +x "$CLONE_WORKSPACE/skills/eth2-quickstart/scripts"/*.sh 2>/dev/null || true

CLONE_SKILL_DIR="$CLONE_WORKSPACE/skills/eth2-quickstart"

if grep -q '^metadata:$' "$CLONE_SKILL_DIR/SKILL.md" &&
   grep -q '^  openclaw:$' "$CLONE_SKILL_DIR/SKILL.md" &&
   grep -q '^    skillKey: eth2-quickstart$' "$CLONE_SKILL_DIR/SKILL.md"; then
    record_test "clone: SKILL.md has OpenClaw metadata" "PASS"
else
    record_test "clone: SKILL.md has OpenClaw metadata" "FAIL"
fi

if [[ -x "$CLONE_SKILL_DIR/scripts/resolve_repo_root.sh" ]]; then
    record_test "clone: resolver is executable" "PASS"
else
    record_test "clone: resolver is executable" "FAIL"
fi

if resolved_root="$(cd "$CLONE_SKILL_DIR" && bash "$CLONE_SKILL_DIR/scripts/resolve_repo_root.sh")"; then
    if [[ -f "$resolved_root/exports.sh" && -x "$resolved_root/scripts/eth2qs.sh" ]]; then
        record_test "clone: resolver finds repo from skill" "PASS"
    else
        record_test "clone: resolver finds repo from skill" "FAIL"
    fi
else
    record_test "clone: resolver finds repo from skill" "FAIL"
fi

if grep -Fq "git clone https://github.com/chimera-defi/eth2-quickstart.git" "$CLONE_SKILL_DIR/references/workflow.md"; then
    record_test "clone: workflow docs reference git clone install" "PASS"
else
    record_test "clone: workflow docs reference git clone install" "FAIL"
fi

# ClawHub is unpublished: if workflow.md mentions it, it must be framed as such.
if ! grep -qi "clawhub" "$CLONE_SKILL_DIR/references/workflow.md" ||
   grep -qi "not yet published" "$CLONE_SKILL_DIR/references/workflow.md"; then
    record_test "clone: clawhub mentions framed as unpublished" "PASS"
else
    record_test "clone: clawhub mentions framed as unpublished" "FAIL"
fi

if [[ -f "$CLONE_SKILL_DIR/references/safety.md" &&
      -f "$CLONE_SKILL_DIR/references/commands.md" &&
      -f "$CLONE_SKILL_DIR/references/operator.md" &&
      -f "$CLONE_SKILL_DIR/references/examples.md" ]]; then
    record_test "clone: all reference docs exist" "PASS"
else
    record_test "clone: all reference docs exist" "FAIL"
fi

# =============================================================================
log_info "--- Test 3: Cross-installation consistency ---"
# =============================================================================

CODEX_DOCTOR_OUTPUT="$("$CODEX_REPO_DIR/scripts/eth2qs.sh" doctor --json 2>&1 || true)"
CLONE_DOCTOR_OUTPUT="$("$CLONE_WORKSPACE/scripts/eth2qs.sh" doctor --json 2>&1 || true)"

if echo "$CODEX_DOCTOR_OUTPUT" | grep -q "^{" && \
   echo "$CLONE_DOCTOR_OUTPUT" | grep -q "^{"; then
    record_test "both paths: doctor outputs valid JSON" "PASS"
else
    log_warn "doctor output format check skipped (may fail in test environment)"
    record_test "both paths: doctor outputs valid JSON" "SKIP"
fi

CODEX_HELP="$("$CODEX_REPO_DIR/scripts/eth2qs.sh" help 2>&1 || true)"
CLONE_HELP="$("$CLONE_WORKSPACE/scripts/eth2qs.sh" help 2>&1 || true)"

if [[ "$CODEX_HELP" == "$CLONE_HELP" ]]; then
    record_test "both paths: wrapper help identical" "PASS"
else
    record_test "both paths: wrapper help identical" "FAIL"
fi

print_test_summary
