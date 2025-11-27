#!/bin/bash

# Legacy Utils Library
# NOTE: All functions have been migrated to lib/common_functions.sh
# This file is kept for backward compatibility but is no longer needed
# if common_functions.sh is sourced.

# The following functions are now in common_functions.sh:
# - log_info(), log_warn(), log_error() - Logging functions
# - require_root() - Check if running as root
# - require_non_root() - Check if NOT running as root
# - ensure_cmd() - Verify command exists
# - append_once() - Append to file if not present

# If this file is sourced before common_functions.sh, provide basic functions
# to avoid errors. These will be overridden by common_functions.sh.

if ! declare -f log_info >/dev/null 2>&1; then
    log_info()  { printf "[INFO] %s\n" "$*"; }
    log_warn()  { printf "[WARN] %s\n" "$*"; }
    log_error() { printf "[ERROR] %s\n" "$*" 1>&2; }
fi

if ! declare -f require_root >/dev/null 2>&1; then
    require_root() {
        if [ "${EUID:-$(id -u)}" -ne 0 ]; then
            log_error "This script must be run as root."
            exit 1
        fi
    }
fi

if ! declare -f require_non_root >/dev/null 2>&1; then
    require_non_root() {
        if [ "${EUID:-$(id -u)}" -eq 0 ]; then
            log_error "Do not run this script as root. Use the non-root user (e.g., 'eth')."
            exit 1
        fi
    }
fi

if ! declare -f ensure_cmd >/dev/null 2>&1; then
    ensure_cmd() {
        if ! command -v "$1" >/dev/null 2>&1; then
            log_error "Required command not found: $1"
            exit 1
        fi
    }
fi

if ! declare -f append_once >/dev/null 2>&1; then
    append_once() {
        local file="$1"; shift
        local text="$*"
        if [ ! -f "$file" ] || ! grep -Fqx -- "$text" "$file"; then
            echo "$text" | sudo tee -a "$file" >/dev/null
        fi
    }
fi
