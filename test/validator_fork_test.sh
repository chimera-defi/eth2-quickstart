#!/bin/bash
# Validator system-contract verification against mainnet (live RPC or Foundry fork).
#
# Guards the "wrong system-contract address" bug class (e.g. a consolidation
# address with no code) and confirms the EIP-7002 / EIP-7251 fee mechanism the
# validator_manage.sh flows depend on. Network-gated: skips cleanly if cast or
# the RPC is unavailable.
#
# Usage: ETH_RPC_URL=<url> ./test/validator_fork_test.sh
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RPC="${ETH_RPC_URL:-https://rpc.sharedtools.org/rpc}"
CAST="${CAST_BIN:-$HOME/.foundry/bin/cast}"
[[ -x "$CAST" ]] || CAST="$(command -v cast 2>/dev/null || true)"

# Canonical mainnet (post-Pectra) system contracts.
DEPOSIT_CONTRACT="0x00000000219ab540356cBB839Cbe05303d7705Fa"
EIP7002_CONTRACT="0x00000961Ef480Eb55e80D19ad83579A64c007002"   # triggerable withdrawals/exits
EIP7251_CONTRACT="0x0000BBdDc7CE488642fb579F8B00f3a590007251"   # consolidation

PASS=0; FAIL=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

if [[ -z "$CAST" ]]; then
    echo "SKIP: cast (Foundry) not found; install via foundryup. Skipping fork test."
    exit 0
fi
if ! $CAST chain-id --rpc-url "$RPC" >/dev/null 2>&1; then
    echo "SKIP: RPC $RPC unreachable; skipping fork test."
    exit 0
fi

CHAIN_ID="$($CAST chain-id --rpc-url "$RPC" 2>/dev/null || echo 0)"
echo "RPC=$RPC chain-id=$CHAIN_ID"
if [[ "$CHAIN_ID" == "1" ]]; then ok "RPC is mainnet (chain-id 1)"; else bad "expected mainnet chain-id 1, got $CHAIN_ID"; fi

has_code() {
    local code
    code="$($CAST code "$1" --rpc-url "$RPC" 2>/dev/null || echo 0x)"
    [[ -n "$code" && "$code" != "0x" ]]
}

# 1) Canonical system contracts must have code.
for pair in "deposit:$DEPOSIT_CONTRACT" "EIP-7002:$EIP7002_CONTRACT" "EIP-7251:$EIP7251_CONTRACT"; do
    name="${pair%%:*}"; addr="${pair#*:}"
    if has_code "$addr"; then ok "$name contract has code ($addr)"; else bad "$name contract has NO code ($addr)"; fi
done

# 2) Fee mechanism: empty-calldata eth_call returns the current fee (uint256 wei).
for pair in "EIP-7002:$EIP7002_CONTRACT" "EIP-7251:$EIP7251_CONTRACT"; do
    name="${pair%%:*}"; addr="${pair#*:}"
    fee="$($CAST call "$addr" --rpc-url "$RPC" 2>/dev/null || true)"
    if [[ -n "$fee" && "$fee" =~ ^0x[0-9a-fA-F]+$ ]]; then
        ok "$name fee query (empty calldata) returns a value: $((fee)) wei"
    else
        bad "$name fee query returned no value (got '$fee')"
    fi
done

# 3) Regression guard: every 0x-address referenced in validator_manage.sh as a
#    system contract must have code on mainnet (catches the 0x00431F26... class).
MANAGE="$PROJECT_ROOT/install/utils/validator_manage.sh"
if [[ -f "$MANAGE" ]]; then
    mapfile -t addrs < <(grep -oE '0x[0-9a-fA-F]{40}' "$MANAGE" | sort -u)
    for addr in "${addrs[@]}"; do
        if has_code "$addr"; then
            ok "validator_manage address has code: $addr"
        else
            bad "validator_manage references address with NO code: $addr"
        fi
    done
fi

echo "=== validator_fork_test: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]]
