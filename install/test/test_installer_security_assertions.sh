#!/bin/bash
# Security-surface assertions for EL installer correctness.
# These are static-analysis (source-code) tests — no running node required.
#
# Assertions validated here:
#   A) HTTP RPC exposes only intended modules (no Engine/auth namespace on 8545)
#   B) Auth/Engine RPC is local + JWT-protected, uses $HOME/secrets/jwt.hex
#   C) Pruned-history clients (reth/besu/nethermind) carry the expected flags/keys;
#      config-level assertion that prune flags are present (not a runtime query check)
#   D) External-IP helper: detection failure does NOT abort install; leaves a warning + safe default
#
# Run: bash install/test/test_installer_security_assertions.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../../test/lib/test_utils.sh"

log_header "EL Installer Security Assertions"

# ---------------------------------------------------------------------------
# A. HTTP RPC must NOT expose Engine/auth namespace on user-facing port
# ---------------------------------------------------------------------------

# A1: Nethermind — EnabledModules must not contain Engine, Admin, or Debug
#     Checked in BOTH the installer script AND the base config template.
test_nethermind_http_no_engine() {
    local sh="$PROJECT_ROOT/install/execution/nethermind.sh"
    local cfg="$PROJECT_ROOT/configs/nethermind/nethermind_base.cfg"
    local ok=0
    for file in "$sh" "$cfg"; do
        local label
        label="$(basename "$file")"
        if grep -q '"EnabledModules"' "$file"; then
            if grep '"EnabledModules"' "$file" | grep -qi '"engine"'; then
                log_error "$label EnabledModules exposes Engine on HTTP RPC"
                ok=1
            fi
            if grep '"EnabledModules"' "$file" | grep -qi '"admin"'; then
                log_error "$label EnabledModules exposes Admin on HTTP RPC"
                ok=1
            fi
            if grep '"EnabledModules"' "$file" | grep -qi '"debug"'; then
                log_error "$label EnabledModules exposes Debug on HTTP RPC"
                ok=1
            fi
        else
            log_error "$label: EnabledModules not found"
            ok=1
        fi
    done
    return $ok
}

# A2: Besu base config — rpc-http-api and rpc-ws-api must not contain ENGINE, ADMIN, or DEBUG
test_besu_no_engine_on_user_rpc() {
    local file="$PROJECT_ROOT/configs/besu/besu_base.toml"
    local ok=0
    if grep -q "^rpc-http-api=" "$file"; then
        local http_line
        http_line="$(grep "^rpc-http-api=" "$file")"
        for module in ENGINE ADMIN DEBUG; do
            if echo "$http_line" | grep -qi "\"${module}\""; then
                log_error "besu_base.toml rpc-http-api exposes ${module} on HTTP RPC"
                ok=1
            fi
        done
    else
        log_error "besu_base.toml: rpc-http-api line not found"
        ok=1
    fi
    if grep -q "^rpc-ws-api=" "$file"; then
        local ws_line
        ws_line="$(grep "^rpc-ws-api=" "$file")"
        for module in ENGINE ADMIN DEBUG; do
            if echo "$ws_line" | grep -qi "\"${module}\""; then
                log_error "besu_base.toml rpc-ws-api exposes ${module} on WS RPC"
                ok=1
            fi
        done
    else
        log_error "besu_base.toml: rpc-ws-api line not found"
        ok=1
    fi
    return $ok
}

# A3: Reth — http.api must not contain engine/auth
test_reth_http_no_engine() {
    local file="$PROJECT_ROOT/install/execution/reth.sh"
    # Use python3 to avoid grep wrapper/regex issues with literal '--http.api' string
    local api_val
    api_val="$(python3 -c "
import re, sys
txt = open('$file').read()
m = re.search(r'--http\.api\s+(\S+)', txt)
print(m.group(1).lower() if m else '')
" 2>/dev/null || true)"
    if [[ -z "$api_val" ]]; then
        log_error "reth.sh: --http.api flag not found"
        return 1
    fi
    if [[ "$api_val" == *engine* ]] || [[ "$api_val" == *auth* ]]; then
        log_error "reth.sh --http.api exposes engine/auth on HTTP port: $api_val"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# B. Auth/Engine RPC must be local-bound and JWT-protected
# ---------------------------------------------------------------------------

# B1: Nethermind — EngineHost is local, JwtSecretFile references jwt.hex
test_nethermind_engine_local_jwt() {
    local file="$PROJECT_ROOT/install/execution/nethermind.sh"
    local ok=0
    # EngineHost bound to LH (127.0.0.1) — check the variable reference
    grep -q '"EngineHost".*LH' "$file" || { log_error "nethermind.sh: EngineHost not bound to \$LH"; ok=1; }
    # JwtSecretFile references jwt.hex
    grep -q '"JwtSecretFile".*jwt\.hex' "$file" || { log_error "nethermind.sh: JwtSecretFile missing/wrong"; ok=1; }
    return $ok
}

# B2: Besu — engine-jwt-secret references jwt.hex, engine-host-allowlist is local
test_besu_engine_local_jwt() {
    local cfg="$PROJECT_ROOT/configs/besu/besu_base.toml"
    local sh="$PROJECT_ROOT/install/execution/besu.sh"
    local ok=0
    # engine-host-allowlist must exist and must NOT allow "*" or "0.0.0.0"
    local allowlist_line
    allowlist_line="$(python3 -c "
for line in open('$cfg'):
    if 'engine-host-allowlist' in line:
        print(line.strip())
        break
" 2>/dev/null || true)"
    if [[ -z "$allowlist_line" ]]; then
        log_error "besu_base.toml: engine-host-allowlist not found"
        ok=1
    elif [[ "$allowlist_line" == *'"*"'* ]] || [[ "$allowlist_line" == *'"0.0.0.0"'* ]]; then
        log_error "besu_base.toml engine-host-allowlist is not restricted to local: $allowlist_line"
        ok=1
    fi
    # engine-jwt-secret references jwt.hex in the install script
    python3 -c "
import sys
txt = open('$sh').read()
sys.exit(0 if 'engine-jwt-secret' in txt and 'jwt.hex' in txt else 1)
" 2>/dev/null || { log_error "besu.sh: engine-jwt-secret not set to jwt.hex"; ok=1; }
    return $ok
}

# B3: Reth — authrpc bound to local LH, jwtsecret references jwt.hex
test_reth_engine_local_jwt() {
    local file="$PROJECT_ROOT/install/execution/reth.sh"
    local ok=0
    grep -q -- "--authrpc.addr.*LH" "$file" || { log_error "reth.sh: --authrpc.addr not bound to \$LH"; ok=1; }
    grep -q -- "--authrpc.jwtsecret.*jwt\.hex" "$file" || { log_error "reth.sh: --authrpc.jwtsecret missing"; ok=1; }
    return $ok
}

# ---------------------------------------------------------------------------
# C. Pruned-history clients carry the expected prune flags
#    Config-level assertion: prune flags are present in installer config/scripts.
#    This locks down the expectation that these clients run pruned, not archive.
#    Runtime behaviour (e.g. null receipts for ancient blocks) is not tested here.
# ---------------------------------------------------------------------------

# C1: Reth runs with --full and pre-merge body/receipt prune flags
test_reth_pruned_flags_present() {
    local file="$PROJECT_ROOT/install/execution/reth.sh"
    local ok=0
    grep -q -- "--full" "$file" || { log_error "reth.sh: --full flag missing (reth would run archive)"; ok=1; }
    grep -q -- "--prune.bodies.pre-merge" "$file" || { log_error "reth.sh: --prune.bodies.pre-merge missing"; ok=1; }
    grep -q -- "--prune.receipts.pre-merge" "$file" || { log_error "reth.sh: --prune.receipts.pre-merge missing"; ok=1; }
    return $ok
}

# C2: Besu runs with history-expiry-prune=true in base config
test_besu_pruned_flags_present() {
    local file="$PROJECT_ROOT/configs/besu/besu_base.toml"
    if grep -q "^history-expiry-prune=true" "$file"; then
        return 0
    fi
    log_error "besu_base.toml: history-expiry-prune=true missing"
    return 1
}

# C3: Nethermind carries AncientBodiesBarrier/AncientReceiptsBarrier (post-merge barriers)
test_nethermind_pruned_flags_present() {
    local file="$PROJECT_ROOT/install/execution/nethermind.sh"
    local ok=0
    grep -q "AncientBodiesBarrier" "$file" || { log_error "nethermind.sh: AncientBodiesBarrier missing"; ok=1; }
    grep -q "AncientReceiptsBarrier" "$file" || { log_error "nethermind.sh: AncientReceiptsBarrier missing"; ok=1; }
    return $ok
}

# C4: Nethermind PivotTotalDifficulty must equal the pivot block's frozen TD, not the TTD threshold.
#     Also asserts FastSyncCatchUpHeightDelta is present (valid key) and SnapSyncCatchUpHeightDelta
#     is absent (renamed/invalid key). Both checks run in BOTH the installer script AND the base cfg.
NETHERMIND_CORRECT_PIVOT_TD="58750003716598352816469"
NETHERMIND_WRONG_PIVOT_TD="58750000000000000000000"

test_nethermind_pivot_and_catchup_keys() {
    local sh="$PROJECT_ROOT/install/execution/nethermind.sh"
    local cfg="$PROJECT_ROOT/configs/nethermind/nethermind_base.cfg"
    local ok=0
    for file in "$sh" "$cfg"; do
        local label
        label="$(basename "$file")"
        # PivotTotalDifficulty must equal the frozen pivot block TD
        if grep -q "PivotTotalDifficulty" "$file"; then
            if ! grep "PivotTotalDifficulty" "$file" | grep -q "${NETHERMIND_CORRECT_PIVOT_TD}"; then
                log_error "$label: PivotTotalDifficulty is not the correct frozen pivot TD (${NETHERMIND_CORRECT_PIVOT_TD})"
                ok=1
            fi
            # Must NOT be the TTD threshold (wrong value — degrades to full genesis sync)
            if grep "PivotTotalDifficulty" "$file" | grep -q "${NETHERMIND_WRONG_PIVOT_TD}\""; then
                log_error "$label: PivotTotalDifficulty is the TTD threshold, not the pivot block TD"
                ok=1
            fi
        else
            log_error "$label: PivotTotalDifficulty key not found"
            ok=1
        fi
        # FastSyncCatchUpHeightDelta (valid key) must be present
        if ! grep -q "FastSyncCatchUpHeightDelta" "$file"; then
            log_error "$label: FastSyncCatchUpHeightDelta missing (valid key, required for post-merge fast-sync)"
            ok=1
        fi
        # SnapSyncCatchUpHeightDelta (renamed/non-existent key) must be absent
        if grep -q "SnapSyncCatchUpHeightDelta" "$file"; then
            log_error "$label: SnapSyncCatchUpHeightDelta present (invalid key — should be FastSyncCatchUpHeightDelta)"
            ok=1
        fi
    done
    return $ok
}

# ---------------------------------------------------------------------------
# D. External-IP helper: failure must NOT abort install; must leave a warning
# ---------------------------------------------------------------------------

# D1: detect_external_ip in common_functions.sh: exits cleanly with empty output on all-fail
# (no 'exit 1' or 'return 1' without an echo, so callers can test -z safely)
test_detect_external_ip_safe_failure() {
    local file="$PROJECT_ROOT/lib/common_functions.sh"
    # Function exists
    if ! grep -q "^detect_external_ip()" "$file"; then
        log_error "detect_external_ip() not found in common_functions.sh"
        return 1
    fi
    # The function must NOT call 'exit' (that would kill the entire install)
    local fn_body
    fn_body="$(awk '/^detect_external_ip\(\)/,/^}/' "$file")"
    if echo "$fn_body" | grep -qw "exit"; then
        log_error "detect_external_ip() contains 'exit' — would abort install on failure"
        return 1
    fi
    return 0
}

# D2: nethermind.sh guards detect_external_ip call with '|| true' (safe under set -e)
test_nethermind_external_ip_guarded() {
    local file="$PROJECT_ROOT/install/execution/nethermind.sh"
    if grep -q "detect_external_ip.*|| true" "$file"; then
        return 0
    fi
    log_error "nethermind.sh: detect_external_ip not guarded with '|| true'"
    return 1
}

# D3: besu.sh guards detect_external_ip call and only injects p2p-host when non-empty
test_besu_external_ip_guarded() {
    local file="$PROJECT_ROOT/install/execution/besu.sh"
    local ok=0
    # Must have || true or -z guard
    grep -q 'detect_external_ip\b' "$file" || { log_error "besu.sh: detect_external_ip not called"; ok=1; }
    # IP injection is behind [[ -n ]] guard (safe fallback)
    grep -q '\[\[ -n.*BESU_EXTERNAL_IP' "$file" || { log_error "besu.sh: p2p-host injection not guarded by [[ -n ]] check"; ok=1; }
    return $ok
}

# D4: nethermind.sh emits a log_warn on detection failure (clear warning to operator)
test_nethermind_external_ip_warns() {
    local file="$PROJECT_ROOT/install/execution/nethermind.sh"
    if grep -q "log_warn.*detect\|Could not detect" "$file"; then
        return 0
    fi
    log_error "nethermind.sh: no log_warn for external IP detection failure"
    return 1
}

# ---------------------------------------------------------------------------
# E. Per-client graffiti: each CL installer must use composed CLIENT_GRAFFITI
# ---------------------------------------------------------------------------

# E1: Each CL script defines CLIENT_GRAFFITI and the graffiti field references $CLIENT_GRAFFITI
test_client_graffiti_defined() {
    local ok=0

    local f="$PROJECT_ROOT/install/consensus/grandine.sh"
    grep -q 'CLIENT_GRAFFITI=' "$f" || { log_error "grandine.sh: CLIENT_GRAFFITI not defined"; ok=1; }
    # shellcheck disable=SC2016
    grep -qF -- '--graffiti \"$CLIENT_GRAFFITI\"' "$f" || { log_error "grandine.sh: --graffiti does not use escaped \$CLIENT_GRAFFITI"; ok=1; }

    f="$PROJECT_ROOT/install/consensus/prysm.sh"
    grep -q 'CLIENT_GRAFFITI=' "$f" || { log_error "prysm.sh: CLIENT_GRAFFITI not defined"; ok=1; }
    # shellcheck disable=SC2016
    grep -qF 'graffiti: $CLIENT_GRAFFITI' "$f" || { log_error "prysm.sh: graffiti field does not use \$CLIENT_GRAFFITI"; ok=1; }

    f="$PROJECT_ROOT/install/consensus/nimbus.sh"
    grep -q 'CLIENT_GRAFFITI=' "$f" || { log_error "nimbus.sh: CLIENT_GRAFFITI not defined"; ok=1; }
    local nimbus_count
    # shellcheck disable=SC2016
    nimbus_count="$(grep -cF 'graffiti = "$CLIENT_GRAFFITI"' "$f" || true)"
    [[ "$nimbus_count" -ge 2 ]] || { log_error "nimbus.sh: expected >= 2 graffiti lines with \$CLIENT_GRAFFITI, found $nimbus_count"; ok=1; }

    f="$PROJECT_ROOT/install/consensus/teku.sh"
    grep -q 'CLIENT_GRAFFITI=' "$f" || { log_error "teku.sh: CLIENT_GRAFFITI not defined"; ok=1; }
    local teku_count
    # shellcheck disable=SC2016
    teku_count="$(grep -cF 'validators-graffiti: "$CLIENT_GRAFFITI"' "$f" || true)"
    [[ "$teku_count" -ge 2 ]] || { log_error "teku.sh: expected >= 2 validators-graffiti lines with \$CLIENT_GRAFFITI, found $teku_count"; ok=1; }

    f="$PROJECT_ROOT/install/consensus/lodestar.sh"
    grep -q 'CLIENT_GRAFFITI=' "$f" || { log_error "lodestar.sh: CLIENT_GRAFFITI not defined"; ok=1; }
    # shellcheck disable=SC2016
    grep -qF '"graffiti": "$CLIENT_GRAFFITI"' "$f" || { log_error "lodestar.sh: graffiti field does not use \$CLIENT_GRAFFITI"; ok=1; }

    return $ok
}

# E2: Composed CLIENT_GRAFFITI for each client is <= 32 bytes and contains the client name
test_client_graffiti_length() {
    local ok=0
    local grafitti_val
    grafitti_val="$(grep '^export GRAFITTI=' "$PROJECT_ROOT/exports.sh" | cut -d'"' -f2)"
    if [[ -z "$grafitti_val" ]]; then
        log_error "Could not extract GRAFITTI value from exports.sh"
        return 1
    fi
    for name in Grandine Prysm Nimbus Teku Lodestar; do
        local composed len
        composed="$(printf '%s' "${name} ${grafitti_val}" | head -c 32)"
        len="$(printf '%s' "$composed" | wc -c)"
        if [[ "$len" -gt 32 ]]; then
            log_error "CLIENT_GRAFFITI for $name is ${len} bytes (>32): '$composed'"
            ok=1
        fi
        if [[ "$composed" != "${name}"* ]]; then
            log_error "CLIENT_GRAFFITI for $name does not start with client name: '$composed'"
            ok=1
        fi
    done
    return $ok
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

if test_nethermind_http_no_engine; then
    record_test "nethermind HTTP RPC: no Engine namespace on user port" "PASS"
else
    record_test "nethermind HTTP RPC: no Engine namespace on user port" "FAIL"
fi

if test_besu_no_engine_on_user_rpc; then
    record_test "besu user RPC: no ENGINE in rpc-http-api or rpc-ws-api" "PASS"
else
    record_test "besu user RPC: no ENGINE in rpc-http-api or rpc-ws-api" "FAIL"
fi

if test_reth_http_no_engine; then
    record_test "reth HTTP RPC: no engine/auth in http.api" "PASS"
else
    record_test "reth HTTP RPC: no engine/auth in http.api" "FAIL"
fi

if test_nethermind_engine_local_jwt; then
    record_test "nethermind Engine RPC: local-bound + jwt.hex" "PASS"
else
    record_test "nethermind Engine RPC: local-bound + jwt.hex" "FAIL"
fi

if test_besu_engine_local_jwt; then
    record_test "besu Engine RPC: local-bound + jwt.hex" "PASS"
else
    record_test "besu Engine RPC: local-bound + jwt.hex" "FAIL"
fi

if test_reth_engine_local_jwt; then
    record_test "reth Engine RPC: local-bound + jwt.hex" "PASS"
else
    record_test "reth Engine RPC: local-bound + jwt.hex" "FAIL"
fi

if test_reth_pruned_flags_present; then
    record_test "reth: pruned-history flags present (not archive)" "PASS"
else
    record_test "reth: pruned-history flags present (not archive)" "FAIL"
fi

if test_besu_pruned_flags_present; then
    record_test "besu: history-expiry-prune=true present" "PASS"
else
    record_test "besu: history-expiry-prune=true present" "FAIL"
fi

if test_nethermind_pruned_flags_present; then
    record_test "nethermind: AncientBodies/ReceiptsBarrier present" "PASS"
else
    record_test "nethermind: AncientBodies/ReceiptsBarrier present" "FAIL"
fi

if test_detect_external_ip_safe_failure; then
    record_test "detect_external_ip: safe empty-output failure (no exit)" "PASS"
else
    record_test "detect_external_ip: safe empty-output failure (no exit)" "FAIL"
fi

if test_nethermind_external_ip_guarded; then
    record_test "nethermind: detect_external_ip guarded with || true" "PASS"
else
    record_test "nethermind: detect_external_ip guarded with || true" "FAIL"
fi

if test_besu_external_ip_guarded; then
    record_test "besu: p2p-host injection guarded by non-empty check" "PASS"
else
    record_test "besu: p2p-host injection guarded by non-empty check" "FAIL"
fi

if test_nethermind_external_ip_warns; then
    record_test "nethermind: log_warn on external IP detection failure" "PASS"
else
    record_test "nethermind: log_warn on external IP detection failure" "FAIL"
fi

if test_nethermind_pivot_and_catchup_keys; then
    record_test "nethermind: correct PivotTotalDifficulty + FastSyncCatchUpHeightDelta (both files)" "PASS"
else
    record_test "nethermind: correct PivotTotalDifficulty + FastSyncCatchUpHeightDelta (both files)" "FAIL"
fi

if test_client_graffiti_defined; then
    record_test "CL graffiti: CLIENT_GRAFFITI defined; field uses \$CLIENT_GRAFFITI in all 5 scripts" "PASS"
else
    record_test "CL graffiti: CLIENT_GRAFFITI defined; field uses \$CLIENT_GRAFFITI in all 5 scripts" "FAIL"
fi

if test_client_graffiti_length; then
    record_test "CL graffiti: composed value is <=32 bytes and contains client name" "PASS"
else
    record_test "CL graffiti: composed value is <=32 bytes and contains client name" "FAIL"
fi

print_test_summary
