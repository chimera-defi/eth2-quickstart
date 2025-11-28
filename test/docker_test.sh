#!/bin/bash
# Docker Test Runner - Runs tests inside an isolated container
# This script executes with REAL system calls (no mocks) inside Docker

set -Eeuo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_header() { echo -e "\n${BLUE}=== $* ===${NC}\n"; }

record_test() {
    local name="$1"
    local result="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$result" == "PASS" ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $name"
    fi
}

# Parse arguments
TEST_MODE="${1:-full}"

log_header "Docker Integration Tests"
log_info "Running inside container with REAL system calls"
log_info "Test mode: $TEST_MODE"
log_info "User: $(whoami)"
log_info "Working directory: $(pwd)"

# =============================================================================
# PHASE 1: Environment Verification
# =============================================================================
log_header "Phase 1: Environment Verification"

# Check we're in a container
if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    record_test "Running inside Docker container" "PASS"
else
    log_warn "Not running in Docker - tests may affect host system!"
    record_test "Running inside Docker container" "FAIL"
fi

# Check required tools
for tool in bash curl wget git sudo ufw jq tar; do
    if command -v "$tool" &>/dev/null; then
        record_test "Tool available: $tool" "PASS"
    else
        record_test "Tool available: $tool" "FAIL"
    fi
done

# =============================================================================
# PHASE 2: Shellcheck and Syntax
# =============================================================================
log_header "Phase 2: Shellcheck and Syntax Validation"

# Run shellcheck on key files
shellcheck_pass=0
shellcheck_fail=0

for script in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/lib/*.sh; do
    [[ -f "$script" ]] || continue
    if shellcheck -x --exclude=SC2317,SC1091,SC1090,SC2034,SC2031 "$script" >/dev/null 2>&1; then
        shellcheck_pass=$((shellcheck_pass + 1))
    else
        shellcheck_fail=$((shellcheck_fail + 1))
        log_error "Shellcheck failed: $script"
    fi
done

if [[ $shellcheck_fail -eq 0 ]]; then
    record_test "Shellcheck: $shellcheck_pass scripts passed" "PASS"
else
    record_test "Shellcheck: $shellcheck_fail scripts failed" "FAIL"
fi

# Syntax check
syntax_pass=0
syntax_fail=0

for script in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT"/lib/*.sh "$PROJECT_ROOT"/install/*/*.sh; do
    [[ -f "$script" ]] || continue
    if bash -n "$script" 2>/dev/null; then
        syntax_pass=$((syntax_pass + 1))
    else
        syntax_fail=$((syntax_fail + 1))
        log_error "Syntax error: $script"
    fi
done

if [[ $syntax_fail -eq 0 ]]; then
    record_test "Syntax check: $syntax_pass scripts valid" "PASS"
else
    record_test "Syntax check: $syntax_fail scripts invalid" "FAIL"
fi

# =============================================================================
# PHASE 3: Source File Verification
# =============================================================================
log_header "Phase 3: Source File Verification"

# Test exports.sh loads
if source "$PROJECT_ROOT/exports.sh" 2>/dev/null; then
    record_test "exports.sh loads successfully" "PASS"
    
    # Check key variables
    if [[ -n "${LOGIN_UNAME:-}" ]]; then
        record_test "LOGIN_UNAME is set" "PASS"
    else
        record_test "LOGIN_UNAME is set" "FAIL"
    fi
    
    if [[ -n "${SERVER_NAME:-}" ]]; then
        record_test "SERVER_NAME is set" "PASS"
    else
        record_test "SERVER_NAME is set" "FAIL"
    fi
    
    if [[ -n "${FEE_RECIPIENT:-}" ]]; then
        record_test "FEE_RECIPIENT is set" "PASS"
    else
        record_test "FEE_RECIPIENT is set" "FAIL"
    fi
else
    record_test "exports.sh loads successfully" "FAIL"
fi

# Test common_functions.sh loads
if source "$PROJECT_ROOT/lib/common_functions.sh" 2>/dev/null; then
    record_test "common_functions.sh loads successfully" "PASS"
    
    # Check key functions exist
    for func in log_info log_error ensure_directory download_file create_systemd_service; do
        if declare -f "$func" >/dev/null 2>&1; then
            record_test "Function exists: $func" "PASS"
        else
            record_test "Function exists: $func" "FAIL"
        fi
    done
else
    record_test "common_functions.sh loads successfully" "FAIL"
fi

# =============================================================================
# PHASE 4: Function Unit Tests (Real System Calls)
# =============================================================================
log_header "Phase 4: Function Unit Tests (Real System Calls)"

# Source the libraries
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Test ensure_directory - creates real directory
test_dir="/tmp/test_ensure_dir_$$"
if ensure_directory "$test_dir" && [[ -d "$test_dir" ]]; then
    record_test "ensure_directory creates real directory" "PASS"
    rm -rf "$test_dir"
else
    record_test "ensure_directory creates real directory" "FAIL"
fi

# Test validate_menu_choice
if validate_menu_choice "3" 5; then
    record_test "validate_menu_choice accepts valid input" "PASS"
else
    record_test "validate_menu_choice accepts valid input" "FAIL"
fi

if ! validate_menu_choice "10" 5 2>/dev/null; then
    record_test "validate_menu_choice rejects invalid input" "PASS"
else
    record_test "validate_menu_choice rejects invalid input" "FAIL"
fi

# Test extract_archive with real tar
test_archive_dir="/tmp/test_archive_$$"
mkdir -p "$test_archive_dir/content"
echo "test data" > "$test_archive_dir/content/file.txt"
(cd "$test_archive_dir" && tar -czf test.tar.gz content/)
extract_dest="/tmp/test_extract_dest_$$"
mkdir -p "$extract_dest"

if extract_archive "$test_archive_dir/test.tar.gz" "$extract_dest" 0 && [[ -f "$extract_dest/content/file.txt" ]]; then
    record_test "extract_archive extracts real tar.gz" "PASS"
else
    record_test "extract_archive extracts real tar.gz" "FAIL"
fi
rm -rf "$test_archive_dir" "$extract_dest"

# Test command_exists
if command_exists "bash"; then
    record_test "command_exists finds bash" "PASS"
else
    record_test "command_exists finds bash" "FAIL"
fi

if ! command_exists "nonexistent_command_xyz123"; then
    record_test "command_exists returns false for missing command" "PASS"
else
    record_test "command_exists returns false for missing command" "FAIL"
fi

# =============================================================================
# PHASE 5: System Integration Tests
# =============================================================================
log_header "Phase 5: System Integration Tests"

# Test UFW (firewall) - requires sudo
if sudo ufw status >/dev/null 2>&1; then
    record_test "UFW is available and accessible" "PASS"
else
    record_test "UFW is available and accessible" "FAIL"
fi

# Test apt-get works
if sudo apt-get update -qq 2>/dev/null; then
    record_test "apt-get update works" "PASS"
else
    record_test "apt-get update works" "FAIL"
fi

# Test systemctl is available (may not fully work without systemd running)
if command -v systemctl &>/dev/null; then
    record_test "systemctl command available" "PASS"
else
    record_test "systemctl command available" "FAIL"
fi

# Test JWT secret creation
jwt_dir="/tmp/test_jwt_$$"
mkdir -p "$jwt_dir"
export HOME="$jwt_dir"
mkdir -p "$jwt_dir/secrets"

# shellcheck disable=SC2119  # ensure_jwt_secret uses $HOME, not $1
if ensure_jwt_secret 2>/dev/null && [[ -f "$jwt_dir/secrets/jwt.hex" ]]; then
    jwt_content=$(cat "$jwt_dir/secrets/jwt.hex")
    if [[ ${#jwt_content} -eq 66 ]] && [[ "$jwt_content" =~ ^0x[a-fA-F0-9]+$ ]]; then
        record_test "ensure_jwt_secret creates valid JWT" "PASS"
    else
        record_test "ensure_jwt_secret creates valid JWT" "FAIL"
    fi
else
    record_test "ensure_jwt_secret creates valid JWT" "FAIL"
fi
rm -rf "$jwt_dir"

# =============================================================================
# PHASE 6: Install Script Structure Tests
# =============================================================================
log_header "Phase 6: Install Script Structure Tests"

# Check install scripts have proper structure
for script in "$PROJECT_ROOT"/install/execution/*.sh "$PROJECT_ROOT"/install/consensus/*.sh; do
    [[ -f "$script" ]] || continue
    script_name=$(basename "$script")
    
    # Check for shebang
    if head -1 "$script" | grep -q "^#!/bin/bash"; then
        record_test "$script_name has shebang" "PASS"
    else
        record_test "$script_name has shebang" "FAIL"
    fi
    
    # Check for source statements
    if grep -q "source.*exports.sh" "$script" && grep -q "source.*common_functions.sh" "$script"; then
        record_test "$script_name sources required files" "PASS"
    else
        record_test "$script_name sources required files" "FAIL"
    fi
done

# =============================================================================
# SUMMARY
# =============================================================================
log_header "Test Summary"

echo "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
