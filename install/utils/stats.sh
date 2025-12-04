#!/bin/bash

# System Statistics Script
# Displays comprehensive system and client statistics
# Usage: ./stats.sh
# Shows: Error logs, client versions, service status

# Source required files
# shellcheck source=../../exports.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../exports.sh"
# shellcheck source=../../lib/common_functions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common_functions.sh"
get_script_directories

echo "=== Error Scan ==="
echo "Checking eth1 logs..."
journalctl -u eth1 -n 200 2>/dev/null | grep -i error || echo "No recent errors in eth1"
echo ""
echo "Checking cl logs..."
journalctl -u cl -n 200 2>/dev/null | grep -i error || echo "No recent errors in cl"
echo ""
echo "Checking validator logs..."
journalctl -u validator -n 200 2>/dev/null | grep -i error || echo "No recent errors in validator"
echo ""
echo "Checking mev logs..."
journalctl -u mev -n 200 2>/dev/null | grep -i error || echo "No recent errors in mev"
echo "--- End error scan ---"
echo ""

echo "=== Time Till Duty Check ==="
journalctl -u validator -n 1000 2>/dev/null | grep -i timeTillDuty || echo "No duty information found"
echo ""

echo "=== Client Versions ==="
if command_exists mev-boost; then
    echo "MEV-Boost:"
    mev-boost -version 2>/dev/null || echo "  Could not get version"
elif [[ -f "$HOME/mev-boost/mev-boost" ]]; then
    echo "MEV-Boost:"
    "$HOME/mev-boost/mev-boost" -version 2>/dev/null || echo "  Could not get version"
else
    echo "MEV-Boost: Not installed"
fi
echo ""

# Check for Prysm
if [[ -f "$HOME/prysm/prysm.sh" ]]; then
    echo "Prysm Beacon Chain:"
    "$HOME/prysm/prysm.sh" beacon-chain --version 2>/dev/null || echo "  Could not get version"
    echo "Prysm Validator:"
    "$HOME/prysm/prysm.sh" validator --version 2>/dev/null || echo "  Could not get version"
elif command_exists prysm.sh; then
    echo "Prysm Beacon Chain:"
    prysm.sh beacon-chain --version 2>/dev/null || echo "  Could not get version"
else
    echo "Prysm: Not installed"
fi
echo ""

if command_exists geth; then
    echo "Geth:"
    geth version 2>/dev/null | head -5 || echo "  Could not get version"
else
    echo "Geth: Not installed"
fi
echo ""

if command_exists nginx; then
    echo "Nginx:"
    nginx -v 2>&1 || echo "  Could not get version"
else
    echo "Nginx: Not installed"
fi
echo "--- End version output ---"
echo ""

# Show service status
show_service_status
