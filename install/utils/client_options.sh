#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OPTIONS_FILE="$ROOT_DIR/config/client_options.json"

usage() {
    cat <<'EOF'
Usage: ./install/utils/client_options.sh [--json]

Show the supported execution clients, consensus clients, MEV options, and
tested presets used by eth2-quickstart automation surfaces.
EOF
}

if [[ ! -f "$OPTIONS_FILE" ]]; then
    echo "Missing client options file: $OPTIONS_FILE" >&2
    exit 1
fi

case "${1:-}" in
    --json)
        cat "$OPTIONS_FILE"
        ;;
    -h|--help)
        usage
        ;;
    "")
        python3 - "$OPTIONS_FILE" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
print("Execution clients:", ", ".join(data["execution_clients"]))
print("Consensus clients:", ", ".join(data["consensus_clients"]))
print("MEV options:", ", ".join(data["mev_options"]))
print("ETHGas requires:", f"mev={data['ethgas_requires']['mev']}")
print("Common presets:")
for preset in data["common_presets"]:
    print(
        f"  - {preset['name']}: execution={preset['execution']} "
        f"consensus={preset['consensus']} mev={preset['mev']} ethgas={preset['ethgas']}"
    )
PY
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac
