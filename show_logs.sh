#!/bin/bash

# Show Ethereum Setup Logs
# Displays the location and contents of the latest log file

source ./lib/common_functions.sh

echo "=== Ethereum Setup Logs ==="
echo

# Check if log directory exists
if [[ -d "$HOME/ethereum-setup-logs" ]]; then
    echo "Log directory: $HOME/ethereum-setup-logs"
    echo
    
    # Find the latest log file
    latest_log=$(ls -t "$HOME/ethereum-setup-logs"/ethereum-setup-*.log 2>/dev/null | head -1)
    
    if [[ -n "$latest_log" ]]; then
        echo "Latest log file: $latest_log"
        echo
        echo "Last 20 lines of the log:"
        echo "========================="
        tail -20 "$latest_log"
        echo
        echo "To view the full log: cat '$latest_log'"
        echo "To follow the log in real-time: tail -f '$latest_log'"
    else
        echo "No log files found in $HOME/ethereum-setup-logs"
    fi
else
    echo "Log directory not found: $HOME/ethereum-setup-logs"
    echo "Run the installation scripts to generate logs."
fi

echo
echo "All log files:"
ls -la "$HOME/ethereum-setup-logs"/ethereum-setup-*.log 2>/dev/null || echo "No log files found"