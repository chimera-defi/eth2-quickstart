#!/bin/bash
# Security-surface assertions for EL installer correctness.
# These are static-analysis (source-code) tests — no running node required.
#
# Assertions validated here:
#   A) HTTP RPC exposes only intended modules (no Engine/auth namespace on 8545)
#   B) Auth/Engine RPC is local + JWT-protected, uses $HOME/secrets/jwt.hex
#   C) Pruned-history clients (reth/besu/nethermind) carry the expected flags/keys;
#      an archive-only state query would fail — documented expectation asserted via config
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

# A1: Nethermind — EnabledModules must not contain Engine
test_nethermind_http_no_engine() {
    local file="$PROJECT_ROOT/install/execution/nethermind.sh"
    # Extract the EnabledModules line and check it doesn't contain "Engine"
    if grep -q '"EnabledModules"' "$file"; then
        if grep '"EnabledModules"' "$file" | grep -qi '"engine"'; then
            log_error "nethermind.sh EnabledModules exposes Engine on HTTP RPC"
            return 1
        fi
        return 0
    fi
    log_error "nethermind.sh: EnabledModules not found"
    return 1
}

# A2: Besu base config — rpc-http-api must not contain ENGINE
test_besu_http_no_engine() {
    local file="$PROJECT_ROOT/configs/besu/besu_base.toml"
    if grep -q "^rpc-http-api=" "$file"; then
        if grep "^rpc-http-api=" "$file" | grep -qi '"ENGINE"'; then
            log_error "besu_base.toml rpc-http-api exposes ENGINE on HTTP RPC"
            return 1
        fi
        return 0
    fi
    log_error "besu_base.toml: rpc-http-api line not found"
    return 1
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
# C. Pruned-history clients carry the expected prune flags (negative archive assertion)
#    These clients do NOT store full pre-merge history; an eth_getBlockByNumber on an
#    ancient pre-merge block would return null (not an error, but no state/receipts).
#    We assert the prune flags are present so the expectation is explicit and locked down.
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
# Run all tests
# ---------------------------------------------------------------------------

if test_nethermind_http_no_engine; then
    record_test "nethermind HTTP RPC: no Engine namespace on user port" "PASS"
else
    record_test "nethermind HTTP RPC: no Engine namespace on user port" "FAIL"
fi

if test_besu_http_no_engine; then
    record_test "besu HTTP RPC: no ENGINE in rpc-http-api" "PASS"
else
    record_test "besu HTTP RPC: no ENGINE in rpc-http-api" "FAIL"
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

print_test_summary
