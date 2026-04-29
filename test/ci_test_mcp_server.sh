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
CLIENT_OPTIONS_SCRIPT="$PROJECT_ROOT/install/utils/client_options.sh"
DEBUG_SCRIPT="$PROJECT_ROOT/install/utils/debug.sh"
MONITOR_SCRIPT="$PROJECT_ROOT/install/utils/monitor.sh"
REPAIR_SCRIPT="$PROJECT_ROOT/install/utils/repair.sh"
STATS_JSON_SCRIPT="$PROJECT_ROOT/install/utils/stats_json.py"
UPDATE_CHECK_SCRIPT="$PROJECT_ROOT/install/utils/update_check.sh"
CLAUDE_PLUGIN_FILE="$PROJECT_ROOT/.claude-plugin/plugin.json"
CLAUDE_MARKETPLACE_FILE="$PROJECT_ROOT/.claude-plugin/marketplace.json"
CLAUDE_SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
CLAUDE_INSTALLER_FILE="$PROJECT_ROOT/scripts/install_claude_eth2qs_mcp.sh"
SKILL_FILE="$PROJECT_ROOT/skills/eth2-quickstart/SKILL.md"
MCP_REF="$PROJECT_ROOT/skills/eth2-quickstart/references/mcp.md"
README_FILE="$PROJECT_ROOT/README.md"

log_info "=== CI Test: eth2-quickstart MCP server ==="

assert_file_exists "$TOOLS_FILE" "mcp_server/eth2qs_mcp_tools.py"
assert_file_exists "$SERVER_FILE" "mcp_server/eth2qs_mcp_server.py"
assert_file_exists "$WRAPPER_FILE" "mcp_server/run_eth2qs_mcp.sh"
assert_file_exists "$CLIENT_OPTIONS_SCRIPT" "install/utils/client_options.sh"
assert_file_exists "$DEBUG_SCRIPT" "install/utils/debug.sh"
assert_file_exists "$MONITOR_SCRIPT" "install/utils/monitor.sh"
assert_file_exists "$REPAIR_SCRIPT" "install/utils/repair.sh"
assert_file_exists "$STATS_JSON_SCRIPT" "install/utils/stats_json.py"
assert_file_exists "$UPDATE_CHECK_SCRIPT" "install/utils/update_check.sh"
assert_file_exists "$CLAUDE_PLUGIN_FILE" ".claude-plugin/plugin.json"
assert_file_exists "$CLAUDE_MARKETPLACE_FILE" ".claude-plugin/marketplace.json"
assert_file_exists "$CLAUDE_SETTINGS_FILE" ".claude/settings.json"
assert_file_exists "$CLAUDE_INSTALLER_FILE" "scripts/install_claude_eth2qs_mcp.sh"
assert_valid_syntax "$WRAPPER_FILE" "run_eth2qs_mcp.sh"
assert_valid_syntax "$CLIENT_OPTIONS_SCRIPT" "client_options.sh"
assert_valid_syntax "$DEBUG_SCRIPT" "debug.sh"
assert_valid_syntax "$MONITOR_SCRIPT" "monitor.sh"
assert_valid_syntax "$REPAIR_SCRIPT" "repair.sh"
assert_valid_syntax "$UPDATE_CHECK_SCRIPT" "update_check.sh"
assert_valid_syntax "$CLAUDE_INSTALLER_FILE" "install_claude_eth2qs_mcp.sh"

if python3 -m py_compile "$TOOLS_FILE" "$SERVER_FILE" "$STATS_JSON_SCRIPT" "$PROJECT_ROOT/install/utils/debug_json.py" "$PROJECT_ROOT/install/utils/monitor_report.py" "$PROJECT_ROOT/install/utils/update_check.py" "$PROJECT_ROOT/install/utils/monitor_common.py"; then
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
   grep -Fq "mcp_server/run_eth2qs_mcp.sh" "$README_FILE" &&
   grep -Fq ".claude-plugin/" "$README_FILE" &&
   grep -Fq "client-options --json" "$README_FILE" &&
   grep -Fq "stats --json" "$README_FILE" &&
   grep -Fq "update-check --json" "$README_FILE" &&
   grep -Fq "monitor export --json" "$README_FILE" &&
   grep -Fq "./scripts/eth2qs.sh repair" "$README_FILE"; then
    record_test "MCP docs are wired from the skill and README" "PASS"
else
    record_test "MCP docs are wired from the skill and README" "FAIL"
fi

if python3 - <<'PY'
import json
from pathlib import Path
plugin = json.loads(Path(".claude-plugin/plugin.json").read_text())
marketplace = json.loads(Path(".claude-plugin/marketplace.json").read_text())
assert plugin["name"] == "eth2-quickstart"
assert "mcpServers" in plugin and "eth2-quickstart" in plugin["mcpServers"]
assert marketplace["plugins"][0]["name"] == "eth2-quickstart"
print("ok")
PY
then
    record_test "Claude plugin manifests parse and expose eth2-quickstart" "PASS"
else
    record_test "Claude plugin manifests parse and expose eth2-quickstart" "FAIL"
fi

if grep -Fq "eth2qs_doctor_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_client_options" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_stats_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_update_check_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_debug_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_monitor_export_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_monitor_history_json" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_repair_preview" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_repair_apply" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_phase1" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_phase2" "$TOOLS_FILE" &&
   grep -Fq "eth2qs_ensure_apply" "$TOOLS_FILE" &&
   grep -Fq "confirmation_token='apply'" "$MCP_REF"; then
    record_test "MCP contract exposes safe tool surface" "PASS"
else
    record_test "MCP contract exposes safe tool surface" "FAIL"
fi

print_test_summary
