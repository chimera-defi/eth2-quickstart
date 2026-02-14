#!/bin/bash

# Grandine Consensus Client Installation Script
# Language: Rust (pre-built binaries from GitHub releases)
# Grandine is a Rust-based Ethereum consensus client focused on performance
# Usage: ./grandine.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

# Start installation
log_installation_start "Grandine"


# Check system requirements
check_system_requirements 16 1000

# Setup firewall rules for Grandine
setup_firewall_rules 9000 5052

# Create Grandine directory
GRANDINE_DIR="$HOME/grandine"
ensure_directory "$GRANDINE_DIR"

cd "$GRANDINE_DIR" || exit

# Get latest release (pre-built binary, no tarball - raw binary)
log_info "Fetching latest Grandine release..."
LATEST_VERSION=$(get_latest_release "grandinetech/grandine")
if [[ -z "$LATEST_VERSION" ]]; then
    log_error "Could not fetch latest Grandine version from GitHub"
    exit 1
fi

# Grandine releases: grandine-2.0.1-amd64 (raw binary, no extension)
DOWNLOAD_URL="https://github.com/grandinetech/grandine/releases/download/${LATEST_VERSION}/grandine-${LATEST_VERSION}-amd64"
BINARY_FILE="grandine-${LATEST_VERSION}-amd64"

log_info "Downloading Grandine ${LATEST_VERSION}..."
if ! download_file "$DOWNLOAD_URL" "$BINARY_FILE"; then
    log_error "Failed to download Grandine"
    exit 1
fi

mv "$BINARY_FILE" "$GRANDINE_DIR/grandine"
chmod +x "$GRANDINE_DIR/grandine"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create Grandine data directory
GRANDINE_DATA_DIR="$HOME/.local/share/grandine"
ensure_directory "$GRANDINE_DATA_DIR"

# Create validator data directory
VALIDATOR_DATA_DIR="$GRANDINE_DATA_DIR/validators"
ensure_directory "$VALIDATOR_DATA_DIR"

# Create temporary directory for custom configuration
create_temp_config_dir

# Create custom configuration variables file
cat > ./tmp/grandine_custom.toml << EOF
# Grandine Custom Configuration Variables

# Network settings
target_peers = $MAX_PEERS

# Data directory
data_dir = "$GRANDINE_DATA_DIR"

# Execution layer
jwt_secret_path = "$HOME/secrets/jwt.hex"

# HTTP API
http_api_listen_address = "$CONSENSUS_HOST:${GRANDINE_REST_PORT}"

# Checkpoint sync
checkpoint_sync_url = "$GRANDINE_CHECKPOINT_URL"

# Metrics
metrics_listen_address = "$CONSENSUS_HOST:8008"

# Validator settings
suggested_fee_recipient = "$FEE_RECIPIENT"
graffiti = "$GRAFITTI"
EOF

# Merge base configuration with custom settings
merge_client_config "Grandine" "main" "$PROJECT_ROOT/configs/grandine/grandine_base.toml" "./tmp/grandine_custom.toml" "$GRANDINE_DIR/grandine.toml"

# Clean up temporary files
rm -rf ./tmp/


# Create systemd service for beacon node
BEACON_EXEC_START="$GRANDINE_DIR/grandine --config $GRANDINE_DIR/grandine.toml"

create_systemd_service "cl" "Grandine Ethereum Consensus Client" "$BEACON_EXEC_START" "$(whoami)" "on-failure" "600" "5" "300"

# Enable and start service
enable_and_start_systemd_service "cl"

log_installation_complete "Grandine" "cl"
log_info "To view logs: journalctl -fu cl"

# Display setup information
display_client_setup_info "Grandine" "cl" "" "Beacon Node" ""
