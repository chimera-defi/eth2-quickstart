#!/bin/bash

# Commit-Boost Installation Script
# Commit-Boost is a modular Ethereum validator sidecar that standardizes
# communication between validators and third-party protocols including MEV-Boost

source ../../exports.sh
source ../../lib/common_functions.sh

# Get script directories
get_script_directories

log_installation_start "Commit-Boost"

# Check system requirements
check_system_requirements 8 1000

# Setup firewall rules for Commit-Boost
setup_firewall_rules "$COMMIT_BOOST_PORT"

# Check if Docker is installed
if ! command_exists docker; then
    log_error "Docker is not installed. Installing Docker..."
    if ! curl -fsSL https://get.docker.com -o get-docker.sh; then
        log_error "Failed to download Docker installation script"
        exit 1
    fi
    
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Add current user to docker group
    sudo usermod -aG docker "$(whoami)"
    
    log_info "Docker installed successfully"
    log_warn "You may need to log out and back in for docker group changes to take effect"
fi

# Check if Docker Compose is installed
if ! command_exists docker-compose && ! docker compose version &>/dev/null; then
    log_error "Docker Compose is not installed. Installing Docker Compose..."
    
    # Install Docker Compose plugin
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    
    log_info "Docker Compose installed successfully"
fi

# Create Commit-Boost directory
COMMIT_BOOST_DIR="$HOME/commit-boost"
rm -rf "$COMMIT_BOOST_DIR"
ensure_directory "$COMMIT_BOOST_DIR"

cd "$COMMIT_BOOST_DIR" || exit

# Clone Commit-Boost repository
log_info "Cloning Commit-Boost repository..."
if ! git clone https://github.com/Commit-Boost/commit-boost-client.git .; then
    log_error "Failed to clone Commit-Boost repository"
    exit 1
fi

# Get the latest stable release tag
log_info "Fetching latest Commit-Boost release..."
LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "main")
if [[ "$LATEST_TAG" != "main" ]]; then
    log_info "Checking out version: $LATEST_TAG"
    git checkout "$LATEST_TAG"
else
    log_warn "No stable release found, using main branch"
fi

# Create configuration directory
CONFIG_DIR="$COMMIT_BOOST_DIR/config"
ensure_directory "$CONFIG_DIR"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create Commit-Boost configuration file
log_info "Creating Commit-Boost configuration..."
cat > "$CONFIG_DIR/commit-boost.toml" << EOF
# Commit-Boost Configuration File
# Generated on $(date)

[pbs]
# PBS (Proposer-Builder Separation) module
# This module is compatible with MEV-Boost relays
port = $COMMIT_BOOST_PORT

# MEV-Boost relay endpoints
relays = [
$(echo "$MEV_RELAYS" | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/')
]

# Minimum bid value (in ETH)
min_bid_eth = $MIN_BID

# Timeout settings (milliseconds)
timeout_get_header_ms = $MEVGETHEADERT
timeout_get_payload_ms = $MEVGETPAYLOADT
timeout_register_validator_ms = $MEVREGVALT

[signer]
# Signer module configuration
# Handles secure signing operations
address = "$COMMIT_BOOST_HOST:$((COMMIT_BOOST_PORT + 1))"

# Signer module path (optional - uses built-in signer if not specified)
# module_path = "/path/to/custom/signer"

[chain]
# Ethereum chain configuration
chain = "mainnet"

# Beacon node connection
beacon_node_url = "http://$CONSENSUS_HOST:5051"

# Execution client connection
execution_client_url = "http://$LH:$ENGINE_PORT"

# JWT secret for authenticated connections
jwt_secret = "$HOME/secrets/jwt.hex"

[metrics]
# Prometheus metrics endpoint
enabled = true
port = $((COMMIT_BOOST_PORT + 2))
address = "$COMMIT_BOOST_HOST"

[logging]
# Logging configuration
level = "info"
format = "json"

# Optional: additional modules can be configured here
# [modules.my_custom_module]
# enabled = true
# config = { key = "value" }
EOF

# Build Commit-Boost using Docker
log_info "Building Commit-Boost Docker image..."
if ! docker build -t commit-boost:latest .; then
    log_error "Failed to build Commit-Boost Docker image"
    exit 1
fi

log_info "Commit-Boost Docker image built successfully"

# Create systemd service for Commit-Boost
log_info "Creating systemd service..."

EXEC_START="docker run --rm --name commit-boost \
  -v $CONFIG_DIR:/config \
  -v $HOME/secrets:/secrets \
  -p $COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT:$COMMIT_BOOST_PORT \
  -p $COMMIT_BOOST_HOST:$((COMMIT_BOOST_PORT + 1)):$((COMMIT_BOOST_PORT + 1)) \
  -p $COMMIT_BOOST_HOST:$((COMMIT_BOOST_PORT + 2)):$((COMMIT_BOOST_PORT + 2)) \
  --network host \
  commit-boost:latest \
  --config /config/commit-boost.toml"

create_systemd_service "commit-boost" "Commit-Boost MEV Sidecar" "$EXEC_START" "$(whoami)" "always" "600" "5" "300"

# Enable and start the service
enable_and_start_systemd_service "commit-boost"

# Show completion information
log_installation_complete "Commit-Boost" "commit-boost" "$CONFIG_DIR/commit-boost.toml" "$COMMIT_BOOST_DIR"

# Display setup information
cat << EOF

=== Commit-Boost Setup Information ===

Commit-Boost has been installed with the following components:
1. PBS Module (MEV-Boost compatible) - Port $COMMIT_BOOST_PORT
2. Signer Module - Port $((COMMIT_BOOST_PORT + 1))
3. Metrics Endpoint - Port $((COMMIT_BOOST_PORT + 2))

Configuration File: $CONFIG_DIR/commit-boost.toml
Docker Image: commit-boost:latest

Key Features:
- MEV-Boost relay compatibility
- Modular architecture for custom protocols
- Support for preconfirmations and commitment protocols
- Metrics and monitoring enabled
- Audited by Sigma Prime

Service Management:
- Start: sudo systemctl start commit-boost
- Stop: sudo systemctl stop commit-boost
- Status: sudo systemctl status commit-boost
- Logs: journalctl -u commit-boost -f
- Docker logs: docker logs commit-boost -f

Verification:
- Check MEV-Boost compatibility: curl http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT/eth/v1/builder/status
- Check metrics: curl http://$COMMIT_BOOST_HOST:$((COMMIT_BOOST_PORT + 2))/metrics

Next Steps:
1. Update your consensus client configuration to use:
   - Prysm: http-mev-relay: http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT
   - Teku: builder-endpoint: "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
   - Lighthouse: --builder http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT
   - Lodestar: builder.urls: ["http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"]
   - Nimbus: payload-builder-url = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
   - Grandine: builder_endpoint = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"

2. Enable builder/MEV in your consensus client configuration
3. Restart your consensus client to apply changes

For more information:
- Documentation: https://commit-boost.github.io/commit-boost-client/
- Repository: https://github.com/Commit-Boost/commit-boost-client
- Twitter: https://x.com/Commit_Boost

EOF
