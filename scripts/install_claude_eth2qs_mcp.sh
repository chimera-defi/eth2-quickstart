#!/bin/bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude CLI not found on PATH" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

if ! python3 -c 'import mcp.server.fastmcp' >/dev/null 2>&1; then
  echo "Missing Python MCP SDK. Install it with: python3 -m pip install mcp" >&2
  exit 1
fi

claude mcp remove eth2-quickstart >/dev/null 2>&1 || true
claude mcp add eth2-quickstart -- "$PROJECT_ROOT/mcp_server/run_eth2qs_mcp.sh"

echo "Registered Claude MCP server: eth2-quickstart"
echo "Next step: run Claude Code from inside $PROJECT_ROOT"
