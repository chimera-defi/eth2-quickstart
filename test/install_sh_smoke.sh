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
REPO_SOURCE="$TMP_DIR/repo-src"

echo "[INFO] Running install.sh smoke test"
echo "[INFO] Project root: $PROJECT_ROOT"
echo "[INFO] Temp install dir: $INSTALL_DIR"
echo "[INFO] Creating temporary git repo for deterministic bootstrap input"

mkdir -p "$REPO_SOURCE"
tar -C "$PROJECT_ROOT" --exclude=.git -cf - . | tar -C "$REPO_SOURCE" -xf -
chown -R "$(id -u):$(id -g)" "$REPO_SOURCE"
git -C "$REPO_SOURCE" init -q
git -C "$REPO_SOURCE" checkout -q -b smoke-test
git -C "$REPO_SOURCE" add .
git -C "$REPO_SOURCE" -c user.name="eth2qs-smoke" -c user.email="smoke@example.invalid" commit -q -m "smoke snapshot"

REF="$(git -C "$REPO_SOURCE" rev-parse HEAD)"

ETH2_REPO_URL="$REPO_SOURCE" \
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
