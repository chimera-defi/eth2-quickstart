#!/bin/bash
# Local test: Run configure.sh with stdin from pipe (simulates curl|bash scenario)
# Uses expect to send Enter at first whiptail - verifies OK button works
#
# Run: ./test/test_configure_pipe_local.sh
# Requires: expect, whiptail

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

log_header "Configure.sh Pipe Test (local)"

if ! command -v expect &>/dev/null || ! command -v whiptail &>/dev/null; then
    record_test "configure.sh pipe test" "SKIP"
    echo "Requires: expect, whiptail"
    exit 0
fi

# Test: configure.sh with stdin from pipe - expect sends Enter to dismiss Welcome dialog
# If we get past it to Network selection, the fix works
PROJECT_ROOT="$PROJECT_ROOT" expect -c "
    set timeout 15
    spawn bash -c \"echo pipe | bash -c 'cd $PROJECT_ROOT && ./install/utils/configure.sh'\"
    expect {
        \"Welcome to the Ethereum\" {
            send \"\r\"
            expect {
                \"Choose the Ethereum Network\" { exit 0 }
                \"Select your hardware\" { exit 0 }
                timeout { exit 1 }
            }
        }
        \"Choose the Ethereum Network\" { send \"\r\"; exit 0 }
        timeout { exit 1 }
    }
" 2>/dev/null && result="PASS" || result="FAIL"

record_test "configure.sh: OK button works when stdin is pipe" "$result"
print_test_summary
