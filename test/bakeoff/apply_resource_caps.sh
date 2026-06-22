#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"

action="${1:?usage: apply_resource_caps.sh <apply|clear>}"

cap_unit() {
  local unit="$1"; shift
  if ! systemctl cat "$unit" >/dev/null 2>&1; then
    log_warn "Unit $unit not present; skipping caps"
    return 0
  fi
  sudo systemctl set-property --runtime "$unit" "$@"
}

case "$action" in
  apply)
    log_info "Applying runtime resource caps (node stack <= 8 cores / 36G)"
    cap_unit eth1.service CPUQuota=600% MemoryMax=24G MemoryHigh=22G IOWeight=50 Nice=10
    cap_unit cl.service   CPUQuota=200% MemoryMax=12G MemoryHigh=11G IOWeight=50 Nice=10
    ;;
  clear)
    log_info "Clearing runtime resource caps"
    for unit in eth1.service cl.service; do
      if systemctl cat "$unit" >/dev/null 2>&1; then
        sudo systemctl revert "$unit" >/dev/null 2>&1 || true
      fi
    done
    ;;
  *)
    echo "Unknown action: $action (use apply|clear)" >&2
    exit 1
    ;;
esac
