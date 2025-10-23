#!/bin/bash

# Strict mode and safe defaults for sourced scripts

log_info()  { printf "[INFO] %s\n" "$*"; }
log_warn()  { printf "[WARN] %s\n" "$*"; }
log_error() { printf "[ERROR] %s\n" "$*" 1>&2; }

require_root() {
	if [ "${EUID:-$(id -u)}" -ne 0 ]; then
		log_error "This script must be run as root."; exit 1;
	fi
}

require_non_root() {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		log_error "Do not run this script as root. Use the non-root user (e.g., 'eth')."; exit 1;
	fi
}

ensure_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		log_error "Required command not found: $1"; exit 1;
	fi
}

append_once() {
	# append_once FILE STRING
	local file="$1"; shift
	local text="$*"
	if [ ! -f "$file" ] || ! grep -Fqx -- "$text" "$file"; then
		echo "$text" | sudo tee -a "$file" >/dev/null
	fi
}

