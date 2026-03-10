#!/bin/bash
# End-to-end smoke harness for install.sh (non-interactive path).
# Runs bootstrap installer against current workspace ref and validates
# generated phase scripts/config without executing phase installers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ "$(id -u)" -ne 0 ]]; then
    echo "[ERROR] install_sh_smoke.sh must run as root"
    exit 1
fi

TMP_DIR="$(mktemp -d /tmp/eth2-install-smoke.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

INSTALL_DIR="$TMP_DIR/install-under-test"
LOG_FILE="$TMP_DIR/install.log"
REPO_MIRROR="$TMP_DIR/repo.git"
REF="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"

echo "[INFO] Running install.sh smoke test"
echo "[INFO] Project root: $PROJECT_ROOT"
echo "[INFO] Temp install dir: $INSTALL_DIR"
echo "[INFO] Creating bare repo mirror for deterministic bootstrap input"

git clone --bare "$PROJECT_ROOT" "$REPO_MIRROR" >/dev/null 2>&1

ETH2_REPO_URL="$REPO_MIRROR" \
ETH2_REF="$REF" \
ETH2_INSTALL_DIR="$INSTALL_DIR" \
ETH2_NON_INTERACTIVE=1 \
bash "$PROJECT_ROOT/install.sh" --non-interactive >"$LOG_FILE" 2>&1

echo "[INFO] install.sh completed, validating outputs"

required_files=(
    "$INSTALL_DIR/config/user_config.env"
    "$INSTALL_DIR/install_phase1.sh"
    "$INSTALL_DIR/install_phase2.sh"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "[ERROR] Missing expected file: $file"
        echo "---- install log ----"
        cat "$LOG_FILE"
        exit 1
    fi
done

if [[ ! -x "$INSTALL_DIR/install_phase1.sh" || ! -x "$INSTALL_DIR/install_phase2.sh" ]]; then
    echo "[ERROR] Generated phase scripts are not executable"
    exit 1
fi

if ! grep -q "export EXEC_CLIENT=" "$INSTALL_DIR/config/user_config.env"; then
    echo "[ERROR] user_config.env missing EXEC_CLIENT export"
    exit 1
fi

if ! grep -q "export CONS_CLIENT=" "$INSTALL_DIR/config/user_config.env"; then
    echo "[ERROR] user_config.env missing CONS_CLIENT export"
    exit 1
fi

if ! grep -q "Configuration Complete" "$LOG_FILE"; then
    echo "[ERROR] install.sh did not reach completion banner"
    echo "---- install log ----"
    cat "$LOG_FILE"
    exit 1
fi

echo "[INFO] install.sh smoke test passed"
