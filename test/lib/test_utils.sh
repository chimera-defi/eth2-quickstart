#!/bin/bash
# Shared Test Utilities
# Common functions and variables used across all test scripts
# Source this file at the beginning of any test script

# =============================================================================
# SHELLCHECK CONFIGURATION (centralized)
# =============================================================================
# Exclusions with rationale:
# SC2317 - Unreachable code (false positive in test scripts)
# SC1091 - Not following source files (relative paths)
# SC1090 - Can't follow non-constant source (variable paths)
# SC2034 - Unused variables (template scripts)
# SC2031 - Variable modified in subshell (testing pattern)
# SC2181 - Check exit code directly (common in whiptail/dialog scripts)
SHELLCHECK_EXCLUDES="SC2317,SC1091,SC1090,SC2034,SC2031,SC2181"

# =============================================================================
# PATH RESOLUTION
# =============================================================================
# These must be set by the sourcing script BEFORE sourcing this file:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Then source this file to get PROJECT_ROOT

# Derive PROJECT_ROOT from SCRIPT_DIR if not already set
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    # Determine depth from test directory
    if [[ "$SCRIPT_DIR" == */test/lib ]]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    elif [[ "$SCRIPT_DIR" == */test ]]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    fi
fi

# =============================================================================
# COLOR DEFINITIONS (single source of truth)
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================
# Default prefix can be overridden by setting LOG_PREFIX before sourcing
LOG_PREFIX="${LOG_PREFIX:-TEST}"

log_info() { echo -e "${GREEN}[$LOG_PREFIX]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[$LOG_PREFIX]${NC} $*"; }
log_error() { echo -e "${RED}[$LOG_PREFIX]${NC} $*"; }
log_header() { echo -e "\n${BLUE}=== $* ===${NC}\n"; }
log_subheader() { echo -e "\n${BLUE}--- $* ---\n"; }

# =============================================================================
# TEST RESULT TRACKING
# =============================================================================
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

record_test() {
    local name="$1"
    local result="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "$result" in
        PASS)
            TESTS_PASSED=$((TESTS_PASSED + 1))
            echo -e "${GREEN}✓${NC} $name"
            ;;
        SKIP)
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            echo -e "${YELLOW}⊘${NC} $name (skipped)"
            ;;
        *)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo -e "${RED}✗${NC} $name"
            ;;
    esac
}

print_test_summary() {
    log_header "Test Summary"
    echo "Total tests: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    [[ $TESTS_SKIPPED -gt 0 ]] && echo -e "Skipped: ${YELLOW}$TESTS_SKIPPED${NC}"
    echo ""
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Some tests failed - see above for details.${NC}"
        return 1
    fi
    echo -e "${GREEN}All tests passed!${NC}"
    return 0
}

# All client install scripts (execution + consensus + MEV) - mirrors run_2.sh / select_clients.sh
CLIENT_SCRIPTS=(
    "install/execution/geth.sh"
    "install/execution/besu.sh"
    "install/execution/erigon.sh"
    "install/execution/nethermind.sh"
    "install/execution/nimbus_eth1.sh"
    "install/execution/reth.sh"
    "install/execution/ethrex.sh"
    "install/consensus/prysm.sh"
    "install/consensus/lighthouse.sh"
    "install/consensus/lodestar.sh"
    "install/consensus/teku.sh"
    "install/consensus/nimbus.sh"
    "install/consensus/grandine.sh"
    "install/mev/install_mev_boost.sh"
    "install/mev/install_commit_boost.sh"
    "install/mev/install_ethgas.sh"
)

# Run script with output teed to log_file. Returns script exit code.
# Usage: run_script_with_log log_file -- script arg1 arg2
# Or: run_script_with_log log_file script arg1 arg2
run_script_with_log() {
    local log_file="$1"
    shift
    "$@" 2>&1 | tee "$log_file"
    return "${PIPESTATUS[0]}"
}

# Dump last N lines of log file via log_error (for failure debugging)
# In CI: default 150 lines for more context when multiple tests fail
dump_log_tail() {
    local log_file="$1"
    local default_lines=50
    [[ -n "${CI:-}" || -n "${CI_E2E:-}" || -n "${GITHUB_ACTIONS:-}" ]] && default_lines=150
    local lines="${2:-$default_lines}"
    local prefix="${3:-  }"
    if [[ -f "$log_file" ]]; then
        log_error "--- Last $lines lines of $log_file ---"
        while IFS= read -r line; do log_error "${prefix}$line"; done < <(tail -n "$lines" "$log_file")
        log_error "--- Full log: $log_file ---"
    fi
}

# Returns 0 if output indicates path resolution failed (sourcing errors)
# Must match sourcing failures only - ufw/iptables also emit "No such file or directory"
output_has_path_errors() {
    local out="${1:-}"
    # Sourcing failure: .sh file not found (e.g. exports.sh, common_functions.sh)
    echo "$out" | grep -qE "\.sh:.*No such file or directory" && return 0
    # Sourcing failure: functions not loaded (common_functions wasn't sourced)
    echo "$out" | grep -qE "get_script_directories: command not found|log_installation_start: command not found" && return 0
    return 1
}

# Returns 0 if script loads (no path errors), 1 if path resolution failed
script_loads_ok() {
    local script="$1"
    local output
    output=$("$script" 2>&1) || true
    ! output_has_path_errors "$output"
}

assert_script_loads() {
    local script="$1"
    local name="${2:-$(basename "$script")}"
    if script_loads_ok "$script"; then
        record_test "$name loads from any cwd" "PASS"
        return 0
    else
        record_test "$name loads from any cwd" "FAIL"
        return 1
    fi
}

# =============================================================================
# COMMON TEST UTILITIES
# =============================================================================

# Check if running inside Docker container
is_docker() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

# Verify a file exists
assert_file_exists() {
    local file="$1"
    local description="${2:-$file}"
    if [[ -f "$file" ]]; then
        record_test "$description exists" "PASS"
        return 0
    else
        record_test "$description exists" "FAIL"
        return 1
    fi
}

# Verify a command exists
assert_command_exists() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        record_test "Command available: $cmd" "PASS"
        return 0
    else
        record_test "Command available: $cmd" "FAIL"
        return 1
    fi
}

# Verify script syntax
assert_valid_syntax() {
    local script="$1"
    local description="${2:-$(basename "$script")}"
    if bash -n "$script" 2>/dev/null; then
        record_test "$description has valid syntax" "PASS"
        return 0
    else
        record_test "$description has valid syntax" "FAIL"
        return 1
    fi
}

# Verify client/component installed (for E2E verification)
# Usage: verify_installed "Name" command args...
# Example: verify_installed "Geth" command -v geth
# Example: verify_installed "Besu" test -f "$HOME/besu/bin/besu"
verify_installed() {
    local name="$1"
    shift
    if "$@" 2>/dev/null; then
        record_test "$name installed" "PASS"
    else
        record_test "$name installed" "FAIL"
    fi
}

# Verify function exists after sourcing
assert_function_exists() {
    local func="$1"
    if declare -f "$func" >/dev/null 2>&1; then
        record_test "Function exists: $func" "PASS"
        return 0
    else
        record_test "Function exists: $func" "FAIL"
        return 1
    fi
}

# =============================================================================
# SHELLCHECK UTILITIES
# =============================================================================

# Run shellcheck with standard exclusions
run_shellcheck() {
    local script="$1"
    shellcheck -x --exclude="$SHELLCHECK_EXCLUDES" "$script"
}

# Check if shellcheck passes (silent)
check_shellcheck() {
    local script="$1"
    shellcheck -x --exclude="$SHELLCHECK_EXCLUDES" "$script" >/dev/null 2>&1
}

# =============================================================================
# SOURCE PROJECT FILES
# =============================================================================

# Helper to source project files with proper paths
source_exports() {
    # shellcheck source=../../exports.sh
    source "$PROJECT_ROOT/exports.sh"
}

source_common_functions() {
    # shellcheck source=../../lib/common_functions.sh
    source "$PROJECT_ROOT/lib/common_functions.sh"
}
