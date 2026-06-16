#!/bin/bash
source ./exports.sh

# ---------------------------------------------------------------------------
# clean_geth_history.sh - reclaim disk by pruning geth's ancient freezer
# ---------------------------------------------------------------------------
# WHY THIS EXISTS (see HANDOFF_diskcleanup.md for the full story):
#
#   `geth snapshot prune-state` DOES NOT WORK on this node and never will.
#   Our geth runs the path-based state scheme (PBSS), and geth refuses
#   offline state pruning under PBSS:
#       CRIT  Offline pruning is not required for path scheme
#   PBSS prunes live state online/automatically, so there is nothing for
#   prune-state to do.
#
#   The disk hog is the ANCIENT FREEZER (~1.2T of the ~1.6T geth dir):
#   block bodies + receipts back to genesis. prune-state never touches that.
#   The right tool is `geth prune-history`, which drops PRE-MERGE bodies
#   and receipts (keeping headers + everything post-merge). A staking node
#   does not need pre-merge history.
#
# WHAT THIS DOES:
#   1. stops geth (eth1) - this is an OFFLINE op; the validator misses
#      attestations until geth is back and caught up. Run in a low-duty window.
#   2. runs `geth prune-history --history.chain postmerge` as the eth user
#      (must match the datadir owner - do NOT sudo this, it would use the
#       wrong /root/.ethereum datadir).
#   3. patches /etc/systemd/system/eth1.service to add `--history.chain
#      postmerge` so the freezer stays pruned and pre-merge history is not
#      re-fetched (idempotent).
#   4. restarts geth and reports disk reclaimed.
#
# Run inside screen/tmux - the prune on ~1.2T takes a while:
#   screen -S geth-prune ./clean_geth_history.sh
# ---------------------------------------------------------------------------

set -euo pipefail

GETH_DATADIR="${GETH_DATADIR:-$HOME/.ethereum}"
SERVICE_FILE="/etc/systemd/system/eth1.service"

echo "=== disk BEFORE ==="
df -hT /
du -sh "$GETH_DATADIR/geth/chaindata/ancient" 2>/dev/null || true

echo "=== stopping geth (eth1) - validator will miss attestations until restart ==="
sudo systemctl stop eth1

echo "=== pruning pre-merge history from the freezer (this takes a while) ==="
# NOTE: run as the eth user (no sudo) so it uses the eth-owned datadir.
geth prune-history --history.chain postmerge --datadir "$GETH_DATADIR"

echo "=== patching $SERVICE_FILE to keep history pruned (--history.chain postmerge) ==="
if ! grep -q -- '--history.chain' "$SERVICE_FILE"; then
  # append the flag to the geth ExecStart line
  sudo sed -i -E 's#(ExecStart\s*=\s*/usr/bin/geth)#\1 --history.chain postmerge#' "$SERVICE_FILE"
  sudo systemctl daemon-reload
  echo "added --history.chain postmerge to ExecStart"
else
  echo "--history.chain already present, leaving service file as-is"
fi

echo "=== restarting geth (eth1) ==="
sudo systemctl start eth1

echo "=== disk AFTER ==="
df -hT /
du -sh "$GETH_DATADIR/geth/chaindata/ancient" 2>/dev/null || true

echo "Done. Tail geth with: sudo journalctl -fu eth1"
echo "Confirm CL reconnects to EL once geth finishes catching up the gap."
