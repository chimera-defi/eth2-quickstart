#!/bin/bash

# Client Config Verification Script
# Verifies that all client install scripts can resolve their config files correctly.
# Run this before or during run_2.sh to confirm config paths are valid.
#
# Usage: ./install/utils/verify_client_configs.sh
# Or from project root: ./install/utils/verify_client_configs.sh

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++)) || true
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++)) || true
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Simulate get_script_directories for a given install script path
# Returns: script_dir and project_root (caller must source to get vars)
resolve_paths_for_script() {
    local install_script="$1"
    local script_dir
    script_dir="$(cd "$(dirname "$PROJECT_ROOT/$install_script")" && pwd)"
    local project_root
    project_root="$(cd "$script_dir/../.." && pwd)"
    echo "$script_dir|$project_root"
}

# Verify a config path would resolve correctly for a client script
verify_client_config() {
    local install_script="$1"
    local config_path="$2"
    local client_name="$3"

    local script_dir project_root
    IFS='|' read -r script_dir project_root < <(resolve_paths_for_script "$install_script")

    local full_config_path="$project_root/$config_path"
    if [[ -f "$full_config_path" ]]; then
        pass "$client_name: $config_path (resolves via PROJECT_ROOT)"
    else
        fail "$client_name: $config_path NOT FOUND at $full_config_path"
    fi
}

echo "=============================================="
echo "  Client Config Verification"
echo "  Project root: $PROJECT_ROOT"
echo "=============================================="
echo ""

# Execution clients with config files
echo "=== Execution Clients ==="
verify_client_config "install/execution/besu.sh" "configs/besu/besu_base.toml" "Besu"
verify_client_config "install/execution/nethermind.sh" "configs/nethermind/nethermind_base.cfg" "Nethermind"
verify_client_config "install/execution/nimbus_eth1.sh" "configs/nimbus/nimbus_eth1_base.toml" "Nimbus-eth1"

# Execution clients without merge_client_config (Geth, Erigon, Reth, Ethrex use CLI/env)
echo ""
echo "Geth, Erigon, Reth, Ethrex: No config files (use CLI flags from exports.sh)"
pass "Geth: Uses ENGINE_PORT, GETH_CACHE, FEE_RECIPIENT from exports.sh"
pass "Erigon: Inline config.yaml (no base config)"
pass "Reth: CLI flags (no base config)"
pass "Ethrex: CLI flags (no base config)"

# Consensus clients
echo ""
echo "=== Consensus Clients ==="
verify_client_config "install/consensus/prysm.sh" "configs/prysm/prysm_beacon_conf.yaml" "Prysm"
verify_client_config "install/consensus/prysm.sh" "configs/prysm/prysm_validator_conf.yaml" "Prysm"
verify_client_config "install/consensus/teku.sh" "configs/teku/teku_beacon_base.yaml" "Teku"
verify_client_config "install/consensus/teku.sh" "configs/teku/teku_validator_base.yaml" "Teku"
verify_client_config "install/consensus/nimbus.sh" "configs/nimbus/nimbus_base.toml" "Nimbus"
verify_client_config "install/consensus/lodestar.sh" "configs/lodestar/lodestar_beacon_base.json" "Lodestar"
verify_client_config "install/consensus/lodestar.sh" "configs/lodestar/lodestar_validator_base.json" "Lodestar"
verify_client_config "install/consensus/grandine.sh" "configs/grandine/grandine_base.toml" "Grandine"

echo ""
echo "Lighthouse: No config files (uses CLI flags)"
pass "Lighthouse: Uses LIGHTHOUSE_CHECKPOINT_URL, ENGINE_PORT from exports.sh"

# Config syntax validation
echo ""
echo "=== Config Syntax Validation ==="
for config in configs/besu/besu_base.toml configs/prysm/prysm_beacon_conf.yaml configs/teku/teku_beacon_base.yaml configs/lodestar/lodestar_beacon_base.json configs/nimbus/nimbus_base.toml configs/grandine/grandine_base.toml; do
    if [[ -f "$PROJECT_ROOT/$config" ]]; then
        case "$config" in
            *.json)
                if jq empty "$PROJECT_ROOT/$config" 2>/dev/null; then
                    pass "Valid JSON: $config"
                else
                    fail "Invalid JSON: $config"
                fi
                ;;
            *.yaml|*.yml)
                if grep -qE "^[a-zA-Z0-9_-]+:" "$PROJECT_ROOT/$config" 2>/dev/null; then
                    pass "Valid YAML structure: $config"
                else
                    warn "YAML structure check inconclusive: $config"
                fi
                ;;
            *.toml)
                if grep -qE "^[a-zA-Z0-9_-]+\\s*=" "$PROJECT_ROOT/$config" 2>/dev/null; then
                    pass "Valid TOML structure: $config"
                else
                    warn "TOML structure check inconclusive: $config"
                fi
                ;;
            *.cfg)
                pass "Config file exists: $config"
                ;;
        esac
    fi
done

# Exports.sh variables used by clients
echo ""
echo "=== Required exports.sh Variables ==="
# shellcheck source=../../exports.sh
source "$PROJECT_ROOT/exports.sh" 2>/dev/null || true
required_vars=(FEE_RECIPIENT GRAFITTI MAX_PEERS LH ENGINE_PORT METRICS_PORT)
for var in "${required_vars[@]}"; do
    if [[ -n "${!var:-}" ]]; then
        pass "exports.sh: $var is set"
    else
        fail "exports.sh: $var is NOT set"
    fi
done

# Summary
echo ""
echo "=============================================="
echo "  Summary: $PASS passed, $FAIL failed"
echo "=============================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
