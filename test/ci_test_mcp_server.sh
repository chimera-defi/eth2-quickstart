#!/bin/bash
# CI test for eth2-quickstart MCP server contract.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/test_utils.sh
source "$SCRIPT_DIR/lib/test_utils.sh"

MCP_DIR="$PROJECT_ROOT/mcp_server"
TOOLS_FILE="$MCP_DIR/eth2qs_mcp_tools.py"
SERVER_FILE="$MCP_DIR/eth2qs_mcp_server.py"
WRAPPER_FILE="$MCP_DIR/run_eth2qs_mcp.sh"
SKILL_FILE="$PROJECT_ROOT/skills/eth2-quickstart/SKILL.md"
MCP_REF="$PROJECT_ROOT/skills/eth2-quickstart/references/mcp.md"
README_FILE="$PROJECT_ROOT/README.md"

log_info "=== CI Test: eth2-quickstart MCP server ==="

assert_file_exists "$TOOLS_FILE" "mcp_server/eth2qs_mcp_tools.py"
assert_file_exists "$SERVER_FILE" "mcp_server/eth2qs_mcp_server.py"
assert_file_exists "$WRAPPER_FILE" "mcp_server/run_eth2qs_mcp.sh"
assert_valid_syntax "$WRAPPER_FILE" "run_eth2qs_mcp.sh"

if python3 -m py_compile "$TOOLS_FILE" "$SERVER_FILE"; then
    record_test "python MCP files compile" "PASS"
else
    record_test "python MCP files compile" "FAIL"
fi

if python3 -m unittest discover -s "$PROJECT_ROOT/test" -p "test_mcp_tools.py"; then
    record_test "python MCP unit tests pass" "PASS"
else
    record_test "python MCP unit tests pass" "FAIL"
fi

if grep -Fq "references/mcp.md" "$SKILL_FILE" &&
   grep -Fq "Claude Code" "$MCP_REF" &&
   grep -Fq "Codex" "$MCP_REF" &&
   grep -Fq "mcp_server/run_eth2qs_mcp.sh" "$README_FILE"; then
    record_test "MCP docs are wired from the skill and README" "PASS"
else
    record_test "MCP docs are wired from the skill and README" "FAIL"
fi

if grep -Fq "eth2qs_doctor_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_client_options" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_phase1" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_phase2" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_ensure_apply" "$TOOLS_FILE" &&
   grep -Fq "confirmation_token='apply'" "$MCP_REF"; then
    record_test "MCP contract exposes safe tool surface" "PASS"
else
    record_test "MCP contract exposes safe tool surface" "FAIL"
fi

print_test_summary
