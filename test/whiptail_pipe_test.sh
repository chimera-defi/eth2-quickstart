#!/bin/bash
# Test that whiptail works when run via "curl | bash" (stdin is a pipe)
# The fix: whiptail must use </dev/tty to read from terminal, not stdin
#
# This test uses expect to:
# 1. Spawn a process with stdin from a pipe (simulating curl | bash)
# 2. Run whiptail with </dev/tty
# 3. Send Enter to dismiss the OK button
# 4. Verify whiptail exits 0

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

log_header "Whiptail Pipe Test (curl|bash scenario)"

# Skip if no TTY (e.g. in CI without expect)
if ! command -v expect &>/dev/null || ! command -v whiptail &>/dev/null; then
    record_test "Whiptail pipe test (expect/whiptail not installed)" "SKIP"
    exit 0
fi

# Test 1: whiptail msgbox with </dev/tty - should work when stdin is pipe
# SC2016: expect -c requires single-quoted Tcl script; shell must not expand
# shellcheck disable=SC2016
expect -c '
    set timeout 10
    exit_code 0
    spawn sh -c "echo pipe | bash -c \"whiptail --title Test --msgbox test 5 20 </dev/tty\""
    expect {
        -re "test|OK" {
            send "\r"
            exp_continue
        }
        eof {
            catch wait result
            set exit_code [lindex $result 3]
            exit $exit_code
        }
        timeout {
            exit 1
        }
    }
' 2>/dev/null && result="PASS" || result="FAIL"

record_test "Whiptail msgbox with </dev/tty when stdin is pipe" "$result"

# Test 1 proves the fix: whiptail with </dev/tty works when stdin is a pipe.
# All whiptail calls (msgbox, yesno, menu, inputbox) use the same redirect pattern.

print_test_summary
