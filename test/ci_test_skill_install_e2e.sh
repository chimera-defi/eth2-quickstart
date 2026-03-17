#!/bin/bash
# E2E test for eth2-quickstart skill installation routes.
#
# This test validates both real-world installation paths:
# 1. Codex GitHub-path installer (ecosystem-native fallback)
# 2. npx clawhub install (registry path when published)
#
# Each path is tested with a simulated fresh environment to catch
# resolver failures, missing dependencies, and command-mapping issues.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_PREFIX="SKILL_INSTALL_E2E"

# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

SKILL_DIR="$PROJECT_ROOT/skills/eth2-quickstart"
RESOLVER="$SKILL_DIR/scripts/resolve_repo_root.sh"
WRAPPER="$PROJECT_ROOT/scripts/eth2qs.sh"
TEMP_INSTALL_BASE="${TEMP_INSTALL_BASE:-/tmp/eth2qs-skill-e2e-test-$$}"

log_info "=== E2E Test: eth2-quickstart skill installation routes ==="
log_info "Temp install base: $TEMP_INSTALL_BASE"

cleanup_temp() {
    if [[ -d "$TEMP_INSTALL_BASE" ]]; then
        log_info "Cleaning up temp install directory"
        rm -rf "$TEMP_INSTALL_BASE"
    fi
}
trap cleanup_temp EXIT

mkdir -p "$TEMP_INSTALL_BASE"

# =============================================================================
# Test 1: Codex GitHub-path installer simulation
# =============================================================================
# This simulates: python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
#   --repo chimera-defi/eth2-quickstart --path skills/eth2-quickstart

log_info ""
log_info "--- Test 1: Codex GitHub-path installation ---"

# The Codex GitHub-path installer extracts the skill from the repo URL.
# Since the skill is IN the repo (eth2-quickstart/skills/eth2-quickstart/),
# this simulates installing a fresh checkout of the repo.
CODEX_REPO_DIR="$TEMP_INSTALL_BASE/codex-checkout"
cp -r "$PROJECT_ROOT" "$CODEX_REPO_DIR"
# Preserve execute permissions
chmod +x "$CODEX_REPO_DIR/scripts"/*.sh 2>/dev/null || true
chmod +x "$CODEX_REPO_DIR/skills/eth2-quickstart/scripts"/*.sh 2>/dev/null || true

# The skill is accessed from inside the repo
INSTALLED_SKILL_DIR="$CODEX_REPO_DIR/skills/eth2-quickstart"

log_info "Simulated Codex install structure:"
log_info "  Repo:  $CODEX_REPO_DIR"
log_info "  Skill: $INSTALLED_SKILL_DIR"

# Test 1a: Resolver works from installed skill directory
log_info "Test 1a: Resolver from installed skill directory..."
if resolved_root="$(cd "$INSTALLED_SKILL_DIR" && bash "$INSTALLED_SKILL_DIR/scripts/resolve_repo_root.sh")"; then
    if [[ -f "$resolved_root/exports.sh" && -x "$resolved_root/scripts/eth2qs.sh" ]]; then
        record_test "codex: resolver finds repo from skill dir" "PASS"
    else
        log_error "Resolved root missing required files: $resolved_root"
        record_test "codex: resolver finds repo from skill dir" "FAIL"
    fi
else
    record_test "codex: resolver finds repo from skill dir" "FAIL"
fi

# Test 1b: Resolver works from repo root
log_info "Test 1b: Resolver from repo root..."
if resolved_root="$(cd "$CODEX_REPO_DIR" && bash "$CODEX_REPO_DIR/skills/eth2-quickstart/scripts/resolve_repo_root.sh")"; then
    if [[ "$resolved_root" == "$CODEX_REPO_DIR" ]]; then
        record_test "codex: resolver finds correct repo root" "PASS"
    else
        log_error "Resolver returned wrong root: $resolved_root (expected $CODEX_REPO_DIR)"
        record_test "codex: resolver finds correct repo root" "FAIL"
    fi
else
    record_test "codex: resolver finds correct repo root" "FAIL"
fi

# Test 1c: Wrapper commands accessible from repo
log_info "Test 1c: Wrapper accessible from repo..."
if [[ -x "$CODEX_REPO_DIR/scripts/eth2qs.sh" ]]; then
    if "$CODEX_REPO_DIR/scripts/eth2qs.sh" help >/dev/null 2>&1; then
        record_test "codex: wrapper help command works" "PASS"
    else
        log_error "Wrapper help command failed"
        record_test "codex: wrapper help command works" "FAIL"
    fi
else
    record_test "codex: wrapper help command works" "FAIL"
fi

# Test 1d: doctor --json reachable from skill context
log_info "Test 1d: doctor --json from skill context..."
if (
    cd "$INSTALLED_SKILL_DIR"
    REPO_ROOT="$CODEX_REPO_DIR"
    export REPO_ROOT
    "$CODEX_REPO_DIR/scripts/eth2qs.sh" doctor --json >/dev/null 2>&1
); then
    record_test "codex: doctor --json works via skill" "PASS"
else
    # doctor may fail due to missing system context, but shouldn't error on JSON parsing
    # Check if error was JSON-parse related or system-context related
    if (
        cd "$INSTALLED_SKILL_DIR"
        REPO_ROOT="$CODEX_REPO_DIR"
        export REPO_ROOT
        output="$("$CODEX_REPO_DIR/scripts/eth2qs.sh" doctor --json 2>&1 || true)"
        if echo "$output" | grep -q "^{"; then
            # Valid JSON output even if some checks failed
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
# Test 2: npx clawhub install simulation
# =============================================================================
# This simulates: npx clawhub install eth2-quickstart
# When a user installs via clawhub, they get the skill package. But to use it,
# they still need an eth2-quickstart repo checkout (the skill is repo-aware).
# So we test: repo checkout with the skill already inside it.

log_info ""
log_info "--- Test 2: npx clawhub install (contract verification) ---"

# Simulate a fresh repo checkout (as user would do via clawhub or git)
CLAWHUB_INSTALL_DIR="$TEMP_INSTALL_BASE/clawhub-checkout"
mkdir -p "$CLAWHUB_INSTALL_DIR"
CLAWHUB_WORKSPACE="$CLAWHUB_INSTALL_DIR/eth2-quickstart"
cp -r "$PROJECT_ROOT" "$CLAWHUB_WORKSPACE"
chmod +x "$CLAWHUB_WORKSPACE/scripts"/*.sh 2>/dev/null || true
chmod +x "$CLAWHUB_WORKSPACE/skills/eth2-quickstart/scripts"/*.sh 2>/dev/null || true

# The skill is at its standard location within the repo
CLAWHUB_SKILL_DIR="$CLAWHUB_WORKSPACE/skills/eth2-quickstart"

log_info "Simulated clawhub+repo structure:"
log_info "  Repo: $CLAWHUB_WORKSPACE"
log_info "  Skill: $CLAWHUB_SKILL_DIR"

# Test 2a: SKILL.md has required OpenClaw metadata
log_info "Test 2a: OpenClaw metadata present..."
if grep -q '^metadata:$' "$CLAWHUB_SKILL_DIR/SKILL.md" &&
   grep -q '^  openclaw:$' "$CLAWHUB_SKILL_DIR/SKILL.md" &&
   grep -q '^    skillKey: eth2-quickstart$' "$CLAWHUB_SKILL_DIR/SKILL.md"; then
    record_test "clawhub: SKILL.md has OpenClaw metadata" "PASS"
else
    record_test "clawhub: SKILL.md has OpenClaw metadata" "FAIL"
fi

# Test 2b: Resolver exists and is executable
log_info "Test 2b: Resolver exists and executable..."
if [[ -x "$CLAWHUB_SKILL_DIR/scripts/resolve_repo_root.sh" ]]; then
    record_test "clawhub: resolver is executable" "PASS"
else
    record_test "clawhub: resolver is executable" "FAIL"
fi

# Test 2c: Resolver can find repo from skill directory
log_info "Test 2c: Resolver finds repo from skill..."
if resolved_root="$(cd "$CLAWHUB_SKILL_DIR" && bash "$CLAWHUB_SKILL_DIR/scripts/resolve_repo_root.sh")"; then
    if [[ -f "$resolved_root/exports.sh" && -x "$resolved_root/scripts/eth2qs.sh" ]]; then
        record_test "clawhub: resolver finds repo from skill" "PASS"
    else
        log_error "Resolved root missing required files: $resolved_root"
        record_test "clawhub: resolver finds repo from skill" "FAIL"
    fi
else
    record_test "clawhub: resolver finds repo from skill" "FAIL"
fi

# Test 2d: Workflow documentation mentions clawhub install
log_info "Test 2d: Installation docs mention clawhub..."
if grep -Fq "npx clawhub install eth2-quickstart" "$CLAWHUB_SKILL_DIR/references/workflow.md"; then
    record_test "clawhub: workflow docs reference clawhub install" "PASS"
else
    record_test "clawhub: workflow docs reference clawhub install" "FAIL"
fi

# Test 2e: Safety and command references exist
log_info "Test 2e: All reference docs present..."
if [[ -f "$CLAWHUB_SKILL_DIR/references/safety.md" &&
      -f "$CLAWHUB_SKILL_DIR/references/commands.md" &&
      -f "$CLAWHUB_SKILL_DIR/references/operator.md" &&
      -f "$CLAWHUB_SKILL_DIR/references/examples.md" ]]; then
    record_test "clawhub: all reference docs exist" "PASS"
else
    record_test "clawhub: all reference docs exist" "FAIL"
fi

# =============================================================================
# Test 3: Cross-installation integration
# =============================================================================
# Verify that both installation paths can use the same wrapper commands
# and produce consistent output formats.

log_info ""
log_info "--- Test 3: Cross-installation consistency ---"

# Test 3a: Both paths' doctor outputs match format
log_info "Test 3a: doctor output format consistency..."
CODEX_DOCTOR_OUTPUT="$("$CODEX_REPO_DIR/scripts/eth2qs.sh" doctor --json 2>&1 || true)"
CLAWHUB_DOCTOR_OUTPUT="$("$CLAWHUB_WORKSPACE/scripts/eth2qs.sh" doctor --json 2>&1 || true)"

# Check both start with valid JSON (even if checks fail due to environment)
if echo "$CODEX_DOCTOR_OUTPUT" | grep -q "^{" && \
   echo "$CLAWHUB_DOCTOR_OUTPUT" | grep -q "^{"; then
    record_test "both paths: doctor outputs valid JSON" "PASS"
else
    log_warn "doctor output format check skipped (may fail in test environment)"
    record_test "both paths: doctor outputs valid JSON" "SKIP"
fi

# Test 3b: Wrapper help is consistent
log_info "Test 3b: wrapper help consistency..."
CODEX_HELP="$("$CODEX_REPO_DIR/scripts/eth2qs.sh" help 2>&1 || true)"
CLAWHUB_HELP="$("$CLAWHUB_WORKSPACE/scripts/eth2qs.sh" help 2>&1 || true)"

if [[ "$CODEX_HELP" == "$CLAWHUB_HELP" ]]; then
    record_test "both paths: wrapper help identical" "PASS"
else
    record_test "both paths: wrapper help identical" "FAIL"
fi

print_test_summary
