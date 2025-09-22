#!/bin/bash

# Common helper functions for install scripts

set -e

ensure_jwt_secret() {
	# Ensures $HOME/secrets/jwt.hex exists
	if [ ! -f "$HOME/secrets/jwt.hex" ]; then
		mkdir -p "$HOME/secrets"
		if command -v openssl >/dev/null 2>&1; then
			openssl rand -hex 32 | tr -d '\n' > "$HOME/secrets/jwt.hex"
		else
			# Fallback if openssl is not available
			head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$HOME/secrets/jwt.hex"
		fi
		chmod 600 "$HOME/secrets/jwt.hex"
	fi
}

create_systemd_service() {
	# Usage: create_systemd_service <service_name> <description> <exec_start> [type] [user] [restart] [restart_sec] [timeout_stop_sec] [timeout_sec]
	local service_name="$1"
	local description="$2"
	local exec_start="$3"
	local service_type="${4:-simple}"
	local run_user="${5:-$(whoami)}"
	local restart_policy="${6:-on-failure}"
	local restart_sec="${7:-5}"
	local timeout_stop_sec="${8:-600}"
	local timeout_sec="${9:-300}"

	local tmp_file
	tmp_file="$HOME/${service_name}.service"
	cat > "$tmp_file" << EOF 
[Unit]
Description     = ${description}
Wants           = network-online.target
After           = network-online.target 

[Service]
Type            = ${service_type}
User            = ${run_user}
ExecStart       = $(echo ${exec_start})
Restart         = ${restart_policy}
TimeoutStopSec  = ${timeout_stop_sec}
RestartSec      = ${restart_sec}
TimeoutSec      = ${timeout_sec}

[Install]
WantedBy    = multi-user.target
EOF

	sudo mv "$tmp_file" "/etc/systemd/system/${service_name}.service"
	sudo chmod 644 "/etc/systemd/system/${service_name}.service"
	sudo systemctl daemon-reload
	sudo systemctl enable "${service_name}"
}

allow_ufw_ports() {
	# Usage: allow_ufw_ports 30303 30304 8551/tcp
	for port in "$@"; do
		sudo ufw allow "$port" || true
	done
}

ensure_apt_packages() {
	# Usage: ensure_apt_packages pkg1 pkg2 ...
	sudo apt-get update -y
	sudo apt-get install -y "$@"
}

