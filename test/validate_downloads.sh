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

check_http_code_200() {
    local url="$1"
    local status_code

    status_code="$(curl -sIL -o /dev/null -w '%{http_code}' "$url")" || return 1
    echo "$status_code"
    [[ "$status_code" == "200" ]]
}

check_download_url_besu() {
    local latest_version
    local url

    latest_version="$(get_latest_release "besu-eth/besu")" || return 1
    [[ -n "$latest_version" ]] || return 1
    url="https://github.com/besu-eth/besu/releases/download/${latest_version}/besu-${latest_version}.tar.gz"
    check_http_code_200 "$url"
}

check_download_url_erigon() {
    local latest_version
    local version_num
    local url

    latest_version="$(get_latest_release "erigontech/erigon")" || return 1
    [[ -n "$latest_version" ]] || return 1
    version_num="${latest_version#v}"
    url="https://github.com/erigontech/erigon/releases/download/${latest_version}/erigon_v${version_num}_linux_amd64.tar.gz"
    check_http_code_200 "$url"
}

check_download_url_ethrex() {
    local latest_version
    local arch
    local binary_name
    local url

    arch="$(uname -m)"
    case "$arch" in
        x86_64)
            binary_name="ethrex-linux-x86_64"
            ;;
        aarch64)
            binary_name="ethrex-linux-aarch64"
            ;;
        *)
            return 1
            ;;
    esac

    latest_version="$(get_latest_release "lambdaclass/ethrex")" || return 1
    [[ -n "$latest_version" ]] || return 1
    url="https://github.com/lambdaclass/ethrex/releases/download/${latest_version}/${binary_name}"
    check_http_code_200 "$url"
}

check_download_url_nimbus_eth1() {
    local nimbus_url

    nimbus_url="$(get_github_release_asset_url "status-im/nimbus-eth1" "nimbus-eth1-linux-amd64-.*\\.tar\\.gz")"
    if [[ -z "$nimbus_url" ]]; then
        nimbus_url="$(get_github_release_asset_url "status-im/nimbus-eth1" "nimbus-linux-amd64-.*\\.tar\\.gz")"
    fi
    [[ -n "$nimbus_url" ]] || return 1
    check_http_code_200 "$nimbus_url"
}

check_download_url_nethermind() {
    local download_url

    download_url="$(get_github_release_asset_url "NethermindEth/nethermind" "nethermind-.*-linux-x64\\.zip")"
    [[ -n "$download_url" ]] || return 1
    check_http_code_200 "$download_url"
}

check_download_url_reth() {
    local latest_version
    local version_num
    local url

    latest_version="$(get_latest_release "paradigmxyz/reth")" || return 1
    [[ -n "$latest_version" ]] || return 1
    version_num="${latest_version#v}"
    url="https://github.com/paradigmxyz/reth/releases/download/${latest_version}/reth-v${version_num}-x86_64-unknown-linux-gnu.tar.gz"
    check_http_code_200 "$url"
}

check_download_url_teku() {
    local latest_version
    local url

    latest_version="$(get_latest_release "ConsenSys/teku")" || return 1
    [[ -n "$latest_version" ]] || return 1
    url="https://artifacts.consensys.net/public/teku/raw/names/teku.tar.gz/versions/${latest_version}/teku-${latest_version}.tar.gz"
    check_http_code_200 "$url"
}

check_download_url_grandine() {
    local arch
    local latest_version
    local download_url
    local pattern

    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            arch="x64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            return 1
            ;;
    esac

    latest_version="$(get_latest_release "grandinetech/grandine" || true)"
    if [[ -n "$latest_version" ]]; then
        download_url="https://github.com/grandinetech/grandine/releases/download/${latest_version}/grandine-${latest_version}-linux-${arch}"
    fi

    if [[ -z "$download_url" ]]; then
        for pattern in "grandine-.*-linux-${arch}" "grandine-.*-linux-${arch}\\.tar\\.gz"; do
            download_url="$(get_github_release_asset_url "grandinetech/grandine" "$pattern" || true)"
            if [[ -n "$download_url" ]]; then
                break
            fi
        done
    fi

    [[ -n "$download_url" ]] || return 1
    check_http_code_200 "$download_url"
}

check_download_url_lighthouse() {
    local download_url

    download_url="$(get_github_release_asset_url "sigp/lighthouse" "lighthouse-.*-x86_64-unknown-linux-gnu\\.tar\\.gz")"
    [[ -n "$download_url" ]] || return 1
    check_http_code_200 "$download_url"
}

check_download_url_nimbus_consensus() {
    local download_url

    download_url="$(get_github_release_asset_url "status-im/nimbus-eth2" "nimbus-eth2_Linux_amd64")"
    [[ -n "$download_url" ]] || return 1
    check_http_code_200 "$download_url"
}

check_download_url_prysm() {
    check_http_code_200 "https://raw.githubusercontent.com/prysmaticlabs/prysm/master/prysm.sh"
}

# Upstream consolidated its artifacts at v0.10.0 (2026-08-10): one
# commit-boost-<version>-<arch>.tar.gz replaces the old separate pbs/signer tarballs.
check_download_url_commit_boost() {
    local latest_version
    local arch
    local url

    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            arch="linux_x86-64"
            ;;
        aarch64|arm64)
            arch="linux_arm64"
            ;;
        *)
            return 1
            ;;
    esac

    latest_version="$(get_latest_release "Commit-Boost/commit-boost-client")" || return 1
    [[ -n "$latest_version" ]] || return 1
    url="https://github.com/Commit-Boost/commit-boost-client/releases/download/${latest_version}/commit-boost-${latest_version}-${arch}.tar.gz"
    check_http_code_200 "$url"
}

check_download_url_mev_boost() {
    local latest_version
    local fallback_version
    local version_num
    local archive_file
    local download_url

    latest_version="$(get_latest_release "flashbots/mev-boost" || true)"
    if [[ -n "$latest_version" ]]; then
        version_num="${latest_version#v}"
        archive_file="mev-boost_${version_num}_linux_amd64.tar.gz"
        download_url="https://github.com/flashbots/mev-boost/releases/download/${latest_version}/${archive_file}"
    else
        download_url="$(get_github_release_asset_url "flashbots/mev-boost" "mev-boost_.*_linux_amd64\\.tar\\.gz" || true)"
        if [[ -z "$download_url" ]]; then
            fallback_version="${MEV_BOOST_FALLBACK_VERSION:-v1.12}"
            version_num="${fallback_version#v}"
            archive_file="mev-boost_${version_num}_linux_amd64.tar.gz"
            download_url="https://github.com/flashbots/mev-boost/releases/download/${fallback_version}/${archive_file}"
        fi
    fi

    [[ -n "$download_url" ]] || return 1
    check_http_code_200 "$download_url"
}

check_download_url_ethgas_repo() {
    check_http_code_200 "https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module.git"
}

check_download_url_fb_builder_geth() {
    check_http_code_200 "https://github.com/flashbots/builder.git"
}

check_download_url_fb_mev_prysm_repo() {
    check_http_code_200 "https://github.com/flashbots/prysm.git"
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
run_test "Commit-Boost linux_x86-64" get_github_release_asset_url "Commit-Boost/commit-boost-client" "commit-boost-v.*-linux_x86-64\.tar\.gz" || FAILED_TESTS+=("Commit-Boost linux_x86-64")
run_test "Lighthouse x86_64 linux" get_github_release_asset_url "sigp/lighthouse" "lighthouse-.*-x86_64-unknown-linux-gnu\.tar\.gz" || FAILED_TESTS+=("Lighthouse x86_64 linux")
run_test_any_pattern "Nimbus-eth1 linux-amd64" "status-im/nimbus-eth1" \
    "nimbus-eth1-linux-amd64-.*\\.tar\\.gz" \
    "nimbus-linux-amd64-.*\\.tar\\.gz" || FAILED_TESTS+=("Nimbus-eth1 linux-amd64")
run_test "Nethermind linux-x64" get_github_release_asset_url "NethermindEth/nethermind" "nethermind-.*-linux-x64\.zip" || FAILED_TESTS+=("Nethermind linux-x64")
run_test "Nimbus-eth2 Linux amd64" get_github_release_asset_url "status-im/nimbus-eth2" "nimbus-eth2_Linux_amd64" || FAILED_TESTS+=("Nimbus-eth2 Linux amd64")

echo ""
echo "=== install script download URL checks ==="
run_test "execution: Besu download URL" check_download_url_besu || FAILED_TESTS+=("execution: Besu download URL")
run_test "execution: Erigon download URL" check_download_url_erigon || FAILED_TESTS+=("execution: Erigon download URL")
run_test "execution: Ethrex download URL" check_download_url_ethrex || FAILED_TESTS+=("execution: Ethrex download URL")
run_test "execution: Nimbus-eth1 download URL" check_download_url_nimbus_eth1 || FAILED_TESTS+=("execution: Nimbus-eth1 download URL")
run_test "execution: Nethermind download URL" check_download_url_nethermind || FAILED_TESTS+=("execution: Nethermind download URL")
run_test "execution: Reth download URL" check_download_url_reth || FAILED_TESTS+=("execution: Reth download URL")
run_test "consensus: Grandine download URL" check_download_url_grandine || FAILED_TESTS+=("consensus: Grandine download URL")
run_test "consensus: Lighthouse download URL" check_download_url_lighthouse || FAILED_TESTS+=("consensus: Lighthouse download URL")
run_test "consensus: Nimbus download URL" check_download_url_nimbus_consensus || FAILED_TESTS+=("consensus: Nimbus download URL")
run_test "consensus: Prysm download URL" check_download_url_prysm || FAILED_TESTS+=("consensus: Prysm download URL")
run_test "consensus: Teku download URL" check_download_url_teku || FAILED_TESTS+=("consensus: Teku download URL")
run_test "mev: Commit-Boost download URL" check_download_url_commit_boost || FAILED_TESTS+=("mev: Commit-Boost download URL")
run_test "mev: MEV Boost download URL" check_download_url_mev_boost || FAILED_TESTS+=("mev: MEV Boost download URL")
run_test "mev: ETHGas source repo URL" check_download_url_ethgas_repo || FAILED_TESTS+=("mev: ETHGas source repo URL")
run_test "mev: Flashbots Builder Geth repo URL" check_download_url_fb_builder_geth || FAILED_TESTS+=("mev: Flashbots Builder Geth repo URL")
run_test "mev: Flashbots MEV Prysm repo URL" check_download_url_fb_mev_prysm_repo || FAILED_TESTS+=("mev: Flashbots MEV Prysm repo URL")

echo ""
if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
    echo "=== Summary: all passed ==="
    exit 0
fi

FAILURES=${#FAILED_TESTS[@]}
echo "=== Summary: $FAILURES checks failed ==="
printf ' - %s\n' "${FAILED_TESTS[@]}"
exit 1
