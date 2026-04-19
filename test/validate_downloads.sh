#!/bin/bash
# Validates get_latest_release and get_github_release_asset_url locally
# Run from project root. Usage: ./test/validate_downloads.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

DOWNLOAD_TEST_RETRIES="${DOWNLOAD_TEST_RETRIES:-3}"
DOWNLOAD_TEST_RETRY_DELAY_SECONDS="${DOWNLOAD_TEST_RETRY_DELAY_SECONDS:-2}"
FAILURES=0
FAILED_TESTS=()

# shellcheck source=lib/common_functions.sh
source "$PROJECT_ROOT/lib/common_functions.sh"

run_test() {
    local name="$1"
    local result
    local attempt
    local backoff_seconds
    shift

    for ((attempt = 1; attempt <= DOWNLOAD_TEST_RETRIES; attempt++)); do
        if result=$("$@" 2>/dev/null) && [[ -n "$result" ]]; then
            echo "PASS: $name"
            return 0
        fi

        if ((attempt < DOWNLOAD_TEST_RETRIES)); then
            backoff_seconds=$((DOWNLOAD_TEST_RETRY_DELAY_SECONDS * attempt))
            echo "WARN: $name attempt $attempt/$DOWNLOAD_TEST_RETRIES failed, retrying in ${backoff_seconds}s..."
            sleep "$backoff_seconds"
        fi
    done

    echo "FAIL: $name"
    return 1
}

run_test_any_pattern() {
    local name="$1"
    local repo="$2"
    local result
    local attempt
    local backoff_seconds
    shift 2

    local pattern
    for ((attempt = 1; attempt <= DOWNLOAD_TEST_RETRIES; attempt++)); do
        for pattern in "$@"; do
            if result=$(get_github_release_asset_url "$repo" "$pattern" 2>/dev/null) && [[ -n "$result" ]]; then
                echo "PASS: $name"
                return 0
            fi
        done

        if ((attempt < DOWNLOAD_TEST_RETRIES)); then
            backoff_seconds=$((DOWNLOAD_TEST_RETRY_DELAY_SECONDS * attempt))
            echo "WARN: $name attempt $attempt/$DOWNLOAD_TEST_RETRIES failed, retrying in ${backoff_seconds}s..."
            sleep "$backoff_seconds"
        fi
    done

    echo "FAIL: $name"
    return 1
}

echo "=== get_latest_release ==="
run_test "flashbots/mev-boost" get_latest_release "flashbots/mev-boost" || FAILED_TESTS+=("flashbots/mev-boost")
run_test "Commit-Boost/commit-boost-client" get_latest_release "Commit-Boost/commit-boost-client" || FAILED_TESTS+=("Commit-Boost/commit-boost-client")
run_test "ConsenSys/teku" get_latest_release "ConsenSys/teku" || FAILED_TESTS+=("ConsenSys/teku")
run_test "besu-eth/besu" get_latest_release "besu-eth/besu" || FAILED_TESTS+=("besu-eth/besu")
run_test "grandinetech/grandine" get_latest_release "grandinetech/grandine" || FAILED_TESTS+=("grandinetech/grandine")
run_test "lambdaclass/ethrex" get_latest_release "lambdaclass/ethrex" || FAILED_TESTS+=("lambdaclass/ethrex")
run_test "erigontech/erigon" get_latest_release "erigontech/erigon" || FAILED_TESTS+=("erigontech/erigon")
run_test "paradigmxyz/reth" get_latest_release "paradigmxyz/reth" || FAILED_TESTS+=("paradigmxyz/reth")

echo ""
echo "=== get_github_release_asset_url ==="
run_test "Commit-Boost PBS linux_x86-64" get_github_release_asset_url "Commit-Boost/commit-boost-client" "commit-boost-pbs-.*-linux_x86-64\.tar\.gz" || FAILED_TESTS+=("Commit-Boost PBS linux_x86-64")
run_test "Lighthouse x86_64 linux" get_github_release_asset_url "sigp/lighthouse" "lighthouse-.*-x86_64-unknown-linux-gnu\.tar\.gz" || FAILED_TESTS+=("Lighthouse x86_64 linux")
run_test_any_pattern "Nimbus-eth1 linux-amd64" "status-im/nimbus-eth1" \
    "nimbus-eth1-linux-amd64-.*\\.tar\\.gz" \
    "nimbus-linux-amd64-.*\\.tar\\.gz" || FAILED_TESTS+=("Nimbus-eth1 linux-amd64")
run_test "Nethermind linux-x64" get_github_release_asset_url "NethermindEth/nethermind" "nethermind-.*-linux-x64\.zip" || FAILED_TESTS+=("Nethermind linux-x64")
run_test "Nimbus-eth2 Linux amd64" get_github_release_asset_url "status-im/nimbus-eth2" "nimbus-eth2_Linux_amd64" || FAILED_TESTS+=("Nimbus-eth2 Linux amd64")

echo ""
if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
    echo "=== Summary: all passed ==="
    exit 0
fi

FAILURES=${#FAILED_TESTS[@]}
echo "=== Summary: $FAILURES checks failed ==="
printf ' - %s\n' "${FAILED_TESTS[@]}"
exit 1
