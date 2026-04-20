#!/bin/bash
# Validates persistent guardrails that enforce security/review/regression workflow.
# Usage: ./test/validate_review_guardrails.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

assert_contains() {
    local file="$1"
    local needle="$2"
    local label="$3"
    if grep -Fq -- "$needle" "$file"; then
        echo "✓ $label"
    else
        echo "✗ $label"
        echo "  missing: $needle"
        echo "  file: $file"
        exit 1
    fi
}

assert_contains "$PROJECT_ROOT/AGENTS.md" "## Completion Quality Gate (Mandatory)" "AGENTS includes mandatory completion gate"
assert_contains "$PROJECT_ROOT/AGENTS.md" "security audit" "AGENTS requires security audit"
assert_contains "$PROJECT_ROOT/AGENTS.md" "regression review" "AGENTS requires regression review"

assert_contains "$PROJECT_ROOT/test/ci_test_run_2.sh" "validate_proxy_policy_sync.sh" "run_2 structure test includes shared-policy parity check"
assert_contains "$PROJECT_ROOT/test/ci_test_run_2.sh" "validate_proxy_policy_toggles.sh" "run_2 structure test includes policy toggle checks"
assert_contains "$PROJECT_ROOT/test/ci_test_run_2.sh" "validate_caddy_config.sh" "run_2 structure test includes caddy validation"
assert_contains "$PROJECT_ROOT/test/ci_test_run_2.sh" "validate_nginx_config.sh" "run_2 structure test includes nginx validation"

assert_contains "$PROJECT_ROOT/test/docker_test.sh" "validate_caddy_config.sh" "docker test includes caddy validation"
assert_contains "$PROJECT_ROOT/test/docker_test.sh" "validate_nginx_config.sh" "docker test includes nginx validation"

assert_contains "$PROJECT_ROOT/install/security/test_security_fixes.sh" "--exclude='sshd_config'" "security exposure check excludes intentional sshd binding"

echo "✓ Review/security/regression guardrails validated"
