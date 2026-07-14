#!/bin/bash
# Test suite for common_functions.sh
# Tests the 4 new functions added to prevent runtime issues
#
# Safety: This test uses mock functions to prevent actual system modifications.
# Run with USE_MOCKS=true (default) for safe testing.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source exports and common functions
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Apply mocks for safe testing (prevents actual systemctl, apt, etc. calls)
USE_MOCKS="${USE_MOCKS:-true}"
MOCK_FILE="$PROJECT_ROOT/test/lib/mock_functions.sh"

if [[ "$USE_MOCKS" == "true" ]] && [[ -f "$MOCK_FILE" ]]; then
    echo "[INFO] Applying mock functions for safe testing..."
    # shellcheck source=../../test/lib/mock_functions.sh
    source "$MOCK_FILE"
    apply_mocks
    echo "[INFO] Mock functions applied - no system changes will be made"
else
    echo "[WARN] Running WITHOUT mocks - system changes may occur!"
    echo "[WARN] Set USE_MOCKS=true and ensure test/lib/mock_functions.sh exists for safe testing"
fi

test_count=0
pass_count=0
fail_count=0

# Test helper functions
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    test_count=$((test_count + 1))
    echo ""
    echo "=== Test $test_count: $test_name ==="
    
    local _rc _e_was=0
    [[ $- == *e* ]] && _e_was=1
    set +e
    ( set -euo pipefail; $test_func )
    _rc=$?
    [[ $_e_was -eq 1 ]] && set -e
    if [[ $_rc -eq 0 ]]; then
        echo "✅ PASS: $test_name"
        pass_count=$((pass_count + 1))
        return 0
    else
        echo "❌ FAIL: $test_name"
        fail_count=$((fail_count + 1))
        return 1
    fi
}

# Test 1: get_latest_release with valid repo
test_get_latest_release_valid() {
    local version
    version=$(get_latest_release "besu-eth/besu")
    
    if [[ -n "$version" ]]; then
        echo "  Got version: $version"
        return 0
    else
        echo "  ERROR: No version returned"
        return 1
    fi
}

# Test 2: get_latest_release with invalid repo
test_get_latest_release_invalid() {
    # Skip this test when mocks are enabled (mocks always succeed)
    if [[ "$USE_MOCKS" == "true" ]]; then
        echo "  Skipped (mocks always succeed - test requires real network)"
        return 0
    fi
    
    # Should return 1 (failure) but not crash
    if ! get_latest_release "nonexistent/repo123456789" >/dev/null 2>&1; then
        echo "  Correctly handled invalid repo"
        return 0
    else
        echo "  ERROR: Should have failed for invalid repo"
        return 1
    fi
}

# Test 3: extract_archive with tar.gz
test_extract_archive_targz() {
    local test_dir="/tmp/test_extract_$$"
    mkdir -p "$test_dir/test_content"
    echo "test data" > "$test_dir/test_content/file.txt"
    
    # Create test archive
    (cd "$test_dir" && tar -czf test.tar.gz test_content/)
    
    # Test extraction
    local extract_dir="/tmp/test_extract_dest_$$"
    mkdir -p "$extract_dir"
    
    if extract_archive "$test_dir/test.tar.gz" "$extract_dir" 0; then
        if [[ -f "$extract_dir/test_content/file.txt" ]]; then
            echo "  Successfully extracted tar.gz"
            rm -rf "$test_dir" "$extract_dir"
            return 0
        else
            echo "  ERROR: File not found after extraction"
            rm -rf "$test_dir" "$extract_dir"
            return 1
        fi
    else
        echo "  ERROR: extract_archive failed"
        rm -rf "$test_dir" "$extract_dir"
        return 1
    fi
}

# Test 4: extract_archive with strip-components
test_extract_archive_strip() {
    local test_dir="/tmp/test_extract_strip_$$"
    mkdir -p "$test_dir/outer/inner"
    echo "test data" > "$test_dir/outer/inner/file.txt"
    
    # Create test archive
    (cd "$test_dir" && tar -czf test.tar.gz outer/)
    
    # Test extraction with strip=1
    local extract_dir="/tmp/test_extract_strip_dest_$$"
    mkdir -p "$extract_dir"
    
    if extract_archive "$test_dir/test.tar.gz" "$extract_dir" 1; then
        if [[ -f "$extract_dir/inner/file.txt" ]]; then
            echo "  Successfully stripped one component"
            rm -rf "$test_dir" "$extract_dir"
            return 0
        else
            echo "  ERROR: Strip-components didn't work correctly"
            rm -rf "$test_dir" "$extract_dir"
            return 1
        fi
    else
        echo "  ERROR: extract_archive with strip failed"
        rm -rf "$test_dir" "$extract_dir"
        return 1
    fi
}

# Test 5: validate_menu_choice with valid input
test_validate_menu_choice_valid() {
    if validate_menu_choice "3" 5; then
        echo "  Accepted valid choice (3 in range 1-5)"
        return 0
    else
        echo "  ERROR: Rejected valid choice"
        return 1
    fi
}

# Test 6: validate_menu_choice with invalid input
test_validate_menu_choice_invalid() {
    if ! validate_menu_choice "10" 5; then
        echo "  Correctly rejected out-of-range choice (10 > 5)"
        return 0
    else
        echo "  ERROR: Accepted out-of-range choice"
        return 1
    fi
}

# Test 7: validate_menu_choice with non-numeric input
test_validate_menu_choice_nonnumeric() {
    if ! validate_menu_choice "abc" 5; then
        echo "  Correctly rejected non-numeric input"
        return 0
    else
        echo "  ERROR: Accepted non-numeric input"
        return 1
    fi
}

# Test 8: stop_all_services doesn't crash
test_stop_all_services() {
    # Just verify it doesn't crash when services don't exist
    if stop_all_services 2>/dev/null; then
        echo "  Function executed without crashing"
        return 0
    else
        echo "  Function returned error but didn't crash (acceptable)"
        return 0  # Still pass since it's expected services may not exist
    fi
}

# Test 9: download_file calls secure_download
test_download_file_calls_secure() {
    # Check the source file (not the function type, which may be mocked)
    if grep -A10 "^download_file()" "$PROJECT_ROOT/lib/common_functions.sh" | grep -q "secure_download"; then
        echo "  download_file correctly calls secure_download in source"
        return 0
    else
        echo "  ERROR: download_file doesn't call secure_download"
        return 1
    fi
}

# Test 10: check_system_compatibility works without root
test_check_system_compatibility_nonroot() {
    # This should work even as non-root user
    if check_system_compatibility >/dev/null 2>&1; then
        echo "  check_system_compatibility works without root"
        return 0
    else
        echo "  ERROR: check_system_compatibility failed"
        return 1
    fi
}

# Test 11: Regression - collect uses getent for SUDO_USER home (non-/home paths)
test_getent_for_sudo_user() {
    if grep -q "getent passwd.*SUDO_USER" "$PROJECT_ROOT/lib/common_functions.sh"; then
        echo "  collect uses getent for SUDO_USER home"
        return 0
    else
        echo "  ERROR: getent for SUDO_USER missing (needed for non-/home paths)"
        return 1
    fi
}

# Test 12: Canonical service registry contains expected services
test_service_registry_contains_expected() {
    local expected=("eth1" "cl" "validator" "mev" "commit-boost-pbs" "commit-boost-signer" "ethgas" "nginx" "caddy")
    local service
    local found
    local existing

    for service in "${expected[@]}"; do
        found=false
        for existing in "${ETH_ALL_SERVICES[@]}"; do
            if [[ "$existing" == "$service" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" != "true" ]]; then
            echo "  ERROR: Missing service in ETH_ALL_SERVICES: $service"
            return 1
        fi
    done

    echo "  ETH_ALL_SERVICES contains expected service names"
    return 0
}

# Test 13: New service helper functions exist
test_service_helpers_exist() {
    local funcs=(
        "service_exists"
        "service_enabled"
        "service_active"
        "start_all_services"
        "restart_all_services"
        "show_service_status"
        "choose_mev_stack"
    )
    local fn
    for fn in "${funcs[@]}"; do
        if ! declare -f "$fn" >/dev/null 2>&1; then
            echo "  ERROR: Missing function: $fn"
            return 1
        fi
    done

    echo "  Service helper functions exist"
    return 0
}

# Test 14: choose_mev_stack prefers Commit-Boost over mev when both enabled
test_choose_mev_stack_precedence() {
    # Override service checks for deterministic test
    service_exists() {
        case "$1" in
            commit-boost-pbs|commit-boost-signer|ethgas|mev) return 0 ;;
            *) return 1 ;;
        esac
    }
    service_enabled() {
        case "$1" in
            commit-boost-pbs|commit-boost-signer|ethgas|mev) return 0 ;;
            *) return 1 ;;
        esac
    }

    local stack
    stack=$(choose_mev_stack)
    stack=$(echo "$stack" | tr '\n' ' ' | xargs)
    if [[ "$stack" == "commit-boost-pbs commit-boost-signer ethgas" ]]; then
        echo "  choose_mev_stack precedence is correct: $stack"
        return 0
    fi

    echo "  ERROR: unexpected stack result: $stack"
    return 1
}

# Test 15: require_cmd returns the documented exit code for missing commands
test_require_cmd_missing() {
    local output rc
    output="$(bash -c '
        set -Eeuo pipefail
        source "$1"
        require_cmd command_that_should_not_exist_12345
    ' _ "$PROJECT_ROOT/lib/common_functions.sh" 2>&1)" || rc=$?

    if [[ "${rc:-0}" -ne 2 ]]; then
        echo "  ERROR: require_cmd returned ${rc:-0} instead of 2"
        printf '%s\n' "$output"
        return 1
    fi

    if [[ "$output" != *"missing required command"* ]]; then
        echo "  ERROR: require_cmd did not print the standard error"
        printf '%s\n' "$output"
        return 1
    fi

    echo "  require_cmd reports missing commands with exit code 2"
    return 0
}

# Test 16: cron helpers replace and remove lines by marker
test_cron_helpers_by_marker() {
    local temp_root fake_bin state_file output
    temp_root="$(mktemp -d)"
    fake_bin="$temp_root/bin"
    state_file="$temp_root/crontab.state"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/crontab" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
state_file="${CRONTAB_STATE_FILE:?missing CRONTAB_STATE_FILE}"
case "${1:-}" in
    -l)
        if [[ -f "$state_file" ]]; then
            cat "$state_file"
        fi
        ;;
    -)
        cat > "$state_file"
        ;;
    *)
        cat "$1" > "$state_file"
        ;;
esac
EOF
    chmod +x "$fake_bin/crontab"

    PATH="$fake_bin:$PATH" CRONTAB_STATE_FILE="$state_file" bash -c '
        set -Eeuo pipefail
        source "$1"
        printf "%s\n" "0 1 * * * keep-this # other" "15 9 * * * old # eth2qs-cli-pr-watch" > "$2"
        cron_replace_by_marker "eth2qs-cli-pr-watch" "30 9 * * * new # eth2qs-cli-pr-watch"
        cron_remove_by_marker "eth2qs-cli-pr-watch"
        cat "$2"
    ' _ "$PROJECT_ROOT/lib/common_functions.sh" "$state_file" > "$temp_root/output.txt"

    output="$(cat "$temp_root/output.txt")"
    rm -rf "$temp_root"

    if [[ "$output" != *"0 1 * * * keep-this # other"* ]]; then
        echo "  ERROR: cron helper removed unrelated lines"
        return 1
    fi

    if [[ "$output" == *"eth2qs-cli-pr-watch"* ]]; then
        echo "  ERROR: cron helper did not remove marker lines"
        return 1
    fi

    echo "  cron helpers replace and remove marker lines correctly"
    return 0
}

# Test 17: doctor checks mev service unit name (not mev-boost)
test_doctor_mev_service_name() {
    if grep -q 'record_service_health "mev" "MEV-Boost (mev)"' "$PROJECT_ROOT/install/utils/doctor.sh" && \
       ! grep -q 'check_service "mev-boost"' "$PROJECT_ROOT/install/utils/doctor.sh"; then
        echo "  doctor.sh uses correct mev service unit name"
        return 0
    fi

    echo "  ERROR: doctor.sh MEV service check is inconsistent"
    return 1
}

# Test 16: require_cmd returns the documented exit code for missing commands
test_require_cmd_missing() {
    local output rc
    output="$(bash -c '
        set -Eeuo pipefail
        source "$1"
        require_cmd command_that_should_not_exist_12345
    ' _ "$PROJECT_ROOT/lib/common_functions.sh" 2>&1)" || rc=$?

    if [[ "${rc:-0}" -ne 2 ]]; then
        echo "  ERROR: require_cmd returned ${rc:-0} instead of 2"
        printf '%s\n' "$output"
        return 1
    fi

    if [[ "$output" != *"missing required command"* ]]; then
        echo "  ERROR: require_cmd did not print the standard error"
        printf '%s\n' "$output"
        return 1
    fi

    echo "  require_cmd reports missing commands with exit code 2"
    return 0
}

# Test 17: cron helpers replace and remove lines by marker
test_cron_helpers_by_marker() {
    local temp_root fake_bin state_file output
    temp_root="$(mktemp -d)"
    fake_bin="$temp_root/bin"
    state_file="$temp_root/crontab.state"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/crontab" <<'EOF'
#!/bin/bash
set -Eeuo pipefail
state_file="${CRONTAB_STATE_FILE:?missing CRONTAB_STATE_FILE}"
case "${1:-}" in
    -l)
        if [[ -f "$state_file" ]]; then
            cat "$state_file"
        fi
        ;;
    -)
        cat > "$state_file"
        ;;
    *)
        cat "$1" > "$state_file"
        ;;
esac
EOF
    chmod +x "$fake_bin/crontab"

    PATH="$fake_bin:$PATH" CRONTAB_STATE_FILE="$state_file" bash -c '
        set -Eeuo pipefail
        source "$1"
        printf "%s\n" "0 1 * * * keep-this # other" "15 9 * * * old # eth2qs-cli-pr-watch" > "$2"
        cron_replace_by_marker "eth2qs-cli-pr-watch" "30 9 * * * new # eth2qs-cli-pr-watch"
        cron_remove_by_marker "eth2qs-cli-pr-watch"
        cat "$2"
    ' _ "$PROJECT_ROOT/lib/common_functions.sh" "$state_file" > "$temp_root/output.txt"

    output="$(cat "$temp_root/output.txt")"
    rm -rf "$temp_root"

    if [[ "$output" != *"0 1 * * * keep-this # other"* ]]; then
        echo "  ERROR: cron helper removed unrelated lines"
        return 1
    fi

    if [[ "$output" == *"eth2qs-cli-pr-watch"* ]]; then
        echo "  ERROR: cron helper did not remove marker lines"
        return 1
    fi

    echo "  cron helpers replace and remove marker lines correctly"
    return 0
}

# Main test execution
main() {
    echo "=========================================="
    echo "Common Functions Test Suite"
    echo "Testing new functions for runtime issues"
    echo "=========================================="
    
    # Run all tests
    run_test "get_latest_release with valid repo" test_get_latest_release_valid
    run_test "get_latest_release with invalid repo" test_get_latest_release_invalid
    run_test "extract_archive with tar.gz" test_extract_archive_targz
    run_test "extract_archive with strip-components" test_extract_archive_strip
    run_test "validate_menu_choice with valid input" test_validate_menu_choice_valid
    run_test "validate_menu_choice with invalid input" test_validate_menu_choice_invalid
    run_test "validate_menu_choice with non-numeric input" test_validate_menu_choice_nonnumeric
    run_test "stop_all_services doesn't crash" test_stop_all_services
    run_test "download_file calls secure_download" test_download_file_calls_secure
    run_test "check_system_compatibility works without root" test_check_system_compatibility_nonroot
    run_test "getent for SUDO_USER home (regression)" test_getent_for_sudo_user
    run_test "service registry contains expected units" test_service_registry_contains_expected
    run_test "service helper functions exist" test_service_helpers_exist
    run_test "choose_mev_stack precedence (regression)" test_choose_mev_stack_precedence
    run_test "require_cmd missing command returns 2" test_require_cmd_missing
    run_test "cron helpers replace/remove by marker" test_cron_helpers_by_marker
    run_test "doctor uses mev unit name (regression)" test_doctor_mev_service_name
    run_test "require_cmd missing command returns 2" test_require_cmd_missing
    run_test "cron helpers replace/remove by marker" test_cron_helpers_by_marker

    # Print summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total tests: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    echo ""
    
    if [[ $fail_count -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed"
        return 1
    fi
}

# Run tests
main
