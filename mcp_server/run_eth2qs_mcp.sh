#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run the eth2-quickstart MCP server" >&2
  exit 1
fi

if ! python3 -c 'import mcp.server.fastmcp' >/dev/null 2>&1; then
  echo "Missing Python MCP SDK. Install it with: python3 -m pip install mcp" >&2
  exit 1
fi

export REPO_ROOT="${REPO_ROOT:-$ROOT_DIR}"
exec python3 "$ROOT_DIR/mcp_server/eth2qs_mcp_server.py"
