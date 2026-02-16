#!/bin/bash
# Validates get_latest_release and get_github_release_asset_url locally
# Run from project root. Usage: ./test/validate_downloads.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# shellcheck source=lib/common_functions.sh
source "$PROJECT_ROOT/lib/common_functions.sh"

run_test() {
    local name="$1"
    local result
    shift
    if result=$("$@") && [[ -n "$result" ]]; then
        echo "PASS: $name"
        return 0
    else
        echo "FAIL: $name"
        exit 1
    fi
}

echo "=== get_latest_release ==="
run_test "flashbots/mev-boost" get_latest_release "flashbots/mev-boost"
run_test "Commit-Boost/commit-boost-client" get_latest_release "Commit-Boost/commit-boost-client"
run_test "ConsenSys/teku" get_latest_release "ConsenSys/teku"
run_test "hyperledger/besu" get_latest_release "hyperledger/besu"
run_test "grandinetech/grandine" get_latest_release "grandinetech/grandine"
run_test "lambdaclass/ethrex" get_latest_release "lambdaclass/ethrex"
run_test "erigontech/erigon" get_latest_release "erigontech/erigon"
run_test "paradigmxyz/reth" get_latest_release "paradigmxyz/reth"

echo ""
echo "=== get_github_release_asset_url ==="
run_test "Lighthouse x86_64 linux" get_github_release_asset_url "sigp/lighthouse" "lighthouse-.*-x86_64-unknown-linux-gnu\.tar\.gz"
run_test "Nimbus-eth1 linux-amd64" get_github_release_asset_url "status-im/nimbus-eth1" "linux-amd64-nightly-latest"
run_test "Nethermind linux-x64" get_github_release_asset_url "NethermindEth/nethermind" "nethermind-.*-linux-x64\.zip"
run_test "Nimbus-eth2 Linux amd64" get_github_release_asset_url "status-im/nimbus-eth2" "nimbus-eth2_Linux_amd64"

echo ""
echo "=== Summary: all passed ==="
