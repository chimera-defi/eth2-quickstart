#!/bin/bash

# ETHGas Installation Script
# ETHGas is a preconfirmation protocol that integrates with Commit-Boost
# Enables validators to sell preconfirmations (precons) for additional revenue
# REQUIRES: Commit-Boost must be installed first

source ../../exports.sh
source ../../lib/common_functions.sh

# Get script directories
get_script_directories

log_installation_start "ETHGas"

# Check system requirements
check_system_requirements 8 2000

# Verify Commit-Boost is installed
if [[ ! -d "$HOME/commit-boost" ]]; then
    log_error "Commit-Boost is not installed. ETHGas requires Commit-Boost."
    log_error "Please run ./install/mev/install_commit_boost.sh first"
    exit 1
fi

# Verify Commit-Boost service exists
if ! systemctl list-unit-files | grep -q "commit-boost.service"; then
    log_error "Commit-Boost service not found. Please install Commit-Boost first."
    exit 1
fi

log_info "Commit-Boost installation verified"

# Setup firewall rules for ETHGas
setup_firewall_rules "$ETHGAS_PORT" "$((ETHGAS_PORT + 1))" "$((ETHGAS_PORT + 2))"

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

# Create ETHGas directory
ETHGAS_DIR="$HOME/ethgas"
rm -rf "$ETHGAS_DIR"
ensure_directory "$ETHGAS_DIR"

cd "$ETHGAS_DIR" || exit

# Clone ETHGas repository
log_info "Cloning ETHGas repository..."
if ! git clone https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module.git .; then
    log_error "Failed to clone ETHGas repository"
    exit 1
fi

# Get the latest stable release tag
log_info "Fetching latest ETHGas release..."
LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "main")
if [[ "$LATEST_TAG" != "main" ]]; then
    log_info "Checking out version: $LATEST_TAG"
    git checkout "$LATEST_TAG"
else
    log_warn "No stable release found, using main branch"
fi

# Create configuration directory
CONFIG_DIR="$ETHGAS_DIR/config"
ensure_directory "$CONFIG_DIR"

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

# Create ETHGas configuration file
log_info "Creating ETHGas configuration..."
cat > "$CONFIG_DIR/ethgas.toml" << EOF
# ETHGas Preconfirmation Protocol Configuration
# Generated on $(date)

[cb_pbs]
# PBS module - serves block proposals to validators
# Similar to MEV-Boost functionality
port = $ETHGAS_PORT
address = "$ETHGAS_HOST"

# MEV-Boost relay endpoints (inherited from Commit-Boost)
relays = [
$(echo "$MEV_RELAYS" | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/')
]

[cb_signer]
# Signer module - securely generates signatures from validator BLS keys
port = $((ETHGAS_PORT + 1))
address = "$ETHGAS_HOST"

# Keystore configuration
keystore_path = "$HOME/.eth2/validators"
keystore_password_path = "$HOME/secrets/pass.txt"

[cb_ethgas_commit]
# ETHGas commitment module - handles registration and precon selling
port = $((ETHGAS_PORT + 2))
address = "$ETHGAS_HOST"

# ETHGas Exchange API endpoint
api_endpoint = "$ETHGAS_API_ENDPOINT"

# Collateral contract address
collateral_contract = "$ETHGAS_COLLATERAL_CONTRACT"

# Registration mode: 'standard', 'ssv', 'obol', or 'skip'
registration_mode = "$ETHGAS_REGISTRATION_MODE"

# Fee recipient for preconfirmation rewards
fee_recipient = "$FEE_RECIPIENT"

# Minimum preconfirmation value (in wei)
min_preconf_value = "$ETHGAS_MIN_PRECONF_VALUE"

[chain]
# Ethereum chain configuration
chain = "$ETHGAS_NETWORK"

# Beacon node connection
beacon_node_url = "http://$CONSENSUS_HOST:5051"

# Execution client connection  
execution_client_url = "http://$LH:$ENGINE_PORT"

# JWT secret for authenticated connections
jwt_secret = "$HOME/secrets/jwt.hex"

[commit_boost]
# Commit-Boost integration
commit_boost_url = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"
commit_boost_signer_url = "http://$COMMIT_BOOST_HOST:$((COMMIT_BOOST_PORT + 1))"

[metrics]
# Prometheus metrics endpoint
enabled = true
port = $((ETHGAS_PORT + 3))
address = "$ETHGAS_HOST"

[logging]
# Logging configuration
level = "info"
format = "json"
file_path = "$ETHGAS_DIR/logs/ethgas.log"

[security]
# Security settings
enable_slashing_protection = true
doppelganger_detection = true

# Rate limiting for preconfirmation requests
rate_limit_per_second = 100
EOF

# Create Docker Compose file
log_info "Creating Docker Compose configuration..."
cat > "$ETHGAS_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  cb_pbs:
    image: ethgas/cb_pbs:latest
    container_name: ethgas_pbs
    restart: always
    ports:
      - "$ETHGAS_HOST:$ETHGAS_PORT:$ETHGAS_PORT"
    volumes:
      - $CONFIG_DIR:/config:ro
      - $HOME/secrets:/secrets:ro
    networks:
      - ethgas_network
    environment:
      - RUST_LOG=info
    command: ["--config", "/config/ethgas.toml"]

  cb_signer:
    image: ethgas/cb_signer:latest
    container_name: ethgas_signer
    restart: always
    ports:
      - "$ETHGAS_HOST:$((ETHGAS_PORT + 1)):$((ETHGAS_PORT + 1))"
    volumes:
      - $CONFIG_DIR:/config:ro
      - $HOME/secrets:/secrets:ro
      - $HOME/.eth2/validators:/validators:ro
    networks:
      - ethgas_network
    environment:
      - RUST_LOG=info
    command: ["--config", "/config/ethgas.toml"]
    depends_on:
      - cb_pbs

  cb_ethgas_commit:
    image: ethgas/cb_ethgas_commit:latest
    container_name: ethgas_commit
    restart: always
    ports:
      - "$ETHGAS_HOST:$((ETHGAS_PORT + 2)):$((ETHGAS_PORT + 2))"
      - "$ETHGAS_HOST:$((ETHGAS_PORT + 3)):$((ETHGAS_PORT + 3))"
    volumes:
      - $CONFIG_DIR:/config:ro
      - $HOME/secrets:/secrets:ro
      - $ETHGAS_DIR/logs:/logs
    networks:
      - ethgas_network
    environment:
      - RUST_LOG=info
    command: ["--config", "/config/ethgas.toml"]
    depends_on:
      - cb_pbs
      - cb_signer

networks:
  ethgas_network:
    driver: bridge
EOF

# Create logs directory
ensure_directory "$ETHGAS_DIR/logs"

# Pull Docker images
log_info "Pulling ETHGas Docker images..."
if ! docker compose -f "$ETHGAS_DIR/docker-compose.yml" pull; then
    log_warn "Failed to pull pre-built images. Will build from source..."
    
    # Build Docker images from source
    log_info "Building ETHGas Docker images from source..."
    if ! docker compose -f "$ETHGAS_DIR/docker-compose.yml" build; then
        log_error "Failed to build ETHGas Docker images"
        exit 1
    fi
fi

# Create systemd service for ETHGas Docker Compose
log_info "Creating systemd service..."

EXEC_START="docker compose -f $ETHGAS_DIR/docker-compose.yml up"
EXEC_STOP="docker compose -f $ETHGAS_DIR/docker-compose.yml down"

cat > /tmp/ethgas.service << EOF
[Unit]
Description=ETHGas Preconfirmation Protocol
After=docker.service commit-boost.service network-online.target
Wants=network-online.target
Requires=docker.service commit-boost.service

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$ETHGAS_DIR
ExecStart=$EXEC_START
ExecStop=$EXEC_STOP
Restart=always
RestartSec=10
TimeoutStartSec=600
TimeoutStopSec=300

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/ethgas.service /etc/systemd/system/ethgas.service
sudo systemctl daemon-reload

# Enable and start the service
enable_and_start_systemd_service "ethgas"

# Show completion information
log_installation_complete "ETHGas" "ethgas" "$CONFIG_DIR/ethgas.toml" "$ETHGAS_DIR"

# Display setup information
cat << EOF

=== ETHGas Setup Information ===

ETHGas has been installed with the following components:
1. cb_pbs - Block proposal service - Port $ETHGAS_PORT
2. cb_signer - Secure signing service - Port $((ETHGAS_PORT + 1))
3. cb_ethgas_commit - Preconfirmation service - Port $((ETHGAS_PORT + 2))
4. Metrics endpoint - Port $((ETHGAS_PORT + 3))

Configuration File: $CONFIG_DIR/ethgas.toml
Docker Compose File: $ETHGAS_DIR/docker-compose.yml
Network: $ETHGAS_NETWORK
Collateral Contract: $ETHGAS_COLLATERAL_CONTRACT

Key Features:
- Preconfirmation (precon) protocol for real-time transactions
- ETHGas Exchange integration for buying/selling precons
- Collateral-based security model
- Support for standard, SSV, and Obol validators
- Audited by Sigma Prime

Service Management:
- Start: sudo systemctl start ethgas
- Stop: sudo systemctl stop ethgas
- Status: sudo systemctl status ethgas
- Logs: journalctl -u ethgas -f
- Docker logs: docker compose -f $ETHGAS_DIR/docker-compose.yml logs -f

Container Management:
- List containers: docker ps | grep ethgas
- Individual logs:
  - PBS: docker logs ethgas_pbs -f
  - Signer: docker logs ethgas_signer -f
  - Commit: docker logs ethgas_commit -f

Verification:
- Check PBS service: curl http://$ETHGAS_HOST:$ETHGAS_PORT/health
- Check metrics: curl http://$ETHGAS_HOST:$((ETHGAS_PORT + 3))/metrics
- Check ETHGas Exchange connectivity: curl $ETHGAS_API_ENDPOINT/status

Important Notes:
1. ETHGas requires Commit-Boost to be running
2. Ensure your validator keys are in $HOME/.eth2/validators
3. Create password file: $HOME/secrets/pass.txt
4. Monitor collateral balance on contract: $ETHGAS_COLLATERAL_CONTRACT
5. Registration mode is set to: $ETHGAS_REGISTRATION_MODE

Collateral Management:
- Mainnet Contract: 0x3314Fb492a5d205A601f2A0521fAFbD039502Fc3
- Holesky Contract: 0x104Ef4192a97E0A93aBe8893c8A2d2484DFCBAF1
- Monitor your collateral balance and top up as needed

For more information:
- Documentation: https://docs.ethgas.com/
- API Documentation: https://developers.ethgas.com/
- Repository: https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module
- Twitter: https://x.com/ETHGASofficial

EOF
