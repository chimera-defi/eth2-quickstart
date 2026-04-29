#!/bin/bash

# ETHGas Installation Script  
# ETHGas is a preconfirmation protocol module for Commit-Boost
# Enables validators to sell preconfirmations (precons) for additional revenue
# REQUIRES: Commit-Boost must be installed first

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT" || exit 1
source "$PROJECT_ROOT/exports.sh"
source "$PROJECT_ROOT/lib/common_functions.sh"

# Get script directories
get_script_directories

log_installation_start "ETHGas"

# Check system requirements
check_system_requirements 8 2000

# Verify Commit-Boost is installed (REQUIRED)
if [[ ! -d "$HOME/commit-boost" ]]; then
    log_error "Commit-Boost is not installed. ETHGas requires Commit-Boost."
    log_error "Please run ./install/mev/install_commit_boost.sh first"
    exit 1
fi

# Verify Commit-Boost services are registered in systemd
daemon_reload_systemd || exit 1
require_systemd_unit_registered "commit-boost-pbs" || exit 1
require_systemd_unit_registered "commit-boost-signer" || exit 1

# ETHGas requires the signer — ensure it's enabled and started.
if ! systemctl is-active --quiet commit-boost-signer 2>/dev/null; then
    log_info "Starting Commit-Boost Signer (required by ETHGas)..."
    sudo systemctl enable --now commit-boost-signer 2>/dev/null || true
fi
if ! systemctl is-active --quiet commit-boost-signer 2>/dev/null; then
    log_warn "Commit-Boost Signer not running. ETHGas needs it for validator key operations."
    log_warn "Configure [signer] in ~/commit-boost/config/cb-config.toml, then:"
    log_warn "  sudo systemctl enable --now commit-boost-signer"
fi

log_info "Commit-Boost dependency verified"

# ETHGas installation method:
# - auto   (default): require prebuilt Docker image (no source fallback)
# - docker: require prebuilt Docker image
# - source: explicit source build (last resort)
ETHGAS_INSTALL_METHOD="${ETHGAS_INSTALL_METHOD:-auto}"
ETHGAS_INSTALL_METHOD="${ETHGAS_INSTALL_METHOD,,}"
case "$ETHGAS_INSTALL_METHOD" in
    auto|docker|source) ;;
    *)
        log_error "Invalid ETHGAS_INSTALL_METHOD: $ETHGAS_INSTALL_METHOD"
        log_error "Valid values: auto, docker, source"
        exit 1
        ;;
esac

detect_latest_ethgas_tag() {
    local tag
    tag=$(get_latest_release "ethgas-developer/ethgas-preconf-commit-boost-module")
    if [[ -n "$tag" ]]; then
        echo "$tag"
        return 0
    fi
    return 1
}

can_use_docker() {
    command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

install_ethgas_source() {
    local src_dir="$ETHGAS_DIR/src"
    local install_bin_dir="$ETHGAS_DIR/bin"

    # Source build requires a C toolchain and protoc for crates/build scripts.
    if ! command -v cc >/dev/null 2>&1; then
        log_info "C compiler not found, installing build-essential..."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential pkg-config
    fi
    if ! command -v protoc >/dev/null 2>&1 || [[ ! -f /usr/include/google/protobuf/descriptor.proto ]]; then
        log_info "protoc/headers missing, installing protobuf toolchain..."
        sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
        sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends protobuf-compiler libprotobuf-dev
    fi

    # Verify Rust is available (installed centrally via install_dependencies.sh)
    [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:${PATH:-}"
    if ! command -v cargo &> /dev/null; then
        log_error "Rust/Cargo not found. Please run install_dependencies.sh first."
        log_error "Or set ETHGAS_INSTALL_METHOD=auto/docker and install Docker."
        return 1
    fi
    log_info "✓ Using Rust: $(rustc --version)"

    # Clone ETHGas repository into a dedicated source directory.
    log_info "Preparing ETHGas source directory..."
    ensure_directory "$src_dir"
    cd "$src_dir" || return 1
    if [[ -d ".git" ]]; then
        log_info "Updating existing ETHGas repository..."
        git fetch origin
        git checkout main
        git pull origin main
    else
        log_info "Cloning ETHGas repository..."
        if ! git clone https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module.git .; then
            log_error "Failed to clone ETHGas repository"
            return 1
        fi
    fi

    # Get the latest stable release tag
    log_info "Fetching latest ETHGas release..."
    LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "main")
    if [[ "$LATEST_TAG" != "main" ]]; then
        log_info "Checking out version: $LATEST_TAG"
        git checkout "$LATEST_TAG"
    else
        log_warn "No stable release tag found, using main branch"
    fi

    # Build ETHGas binary
    log_info "Building ETHGas binary... This may take 2-5 minutes."
    if ! cargo build --release --bin ethgas_commit; then
        log_error "Failed to build ETHGas binary"
        return 1
    fi

    if [[ ! -f "$src_dir/target/release/ethgas_commit" ]]; then
        log_error "ETHGas binary not found at $src_dir/target/release/ethgas_commit"
        return 1
    fi
    ensure_directory "$install_bin_dir"
    cp "$src_dir/target/release/ethgas_commit" "$install_bin_dir/ethgas_commit"
    chmod +x "$install_bin_dir/ethgas_commit"
    ETHGAS_RUNTIME_MODE="source"
    ETHGAS_BIN_PATH="$install_bin_dir/ethgas_commit"
    log_info "✓ ETHGas source build completed"
    return 0
}

install_ethgas_docker() {
    local latest_tag image repo
    repo="ghcr.io/ethgas-developer/commitboost_ethgas_commit"
    latest_tag=""
    if latest_tag=$(detect_latest_ethgas_tag); then
        :
    fi

    # Try official release tag first, then "latest" for forward compatibility.
    ETHGAS_IMAGE_TAG=""
    for candidate in "${latest_tag:-}" latest; do
        [[ -z "$candidate" ]] && continue
        image="${repo}:${candidate}"
        log_info "Trying ETHGas Docker image: $image"
        if docker pull "$image" >/dev/null 2>&1; then
            ETHGAS_IMAGE_TAG="$candidate"
            break
        fi
    done

    if [[ -z "$ETHGAS_IMAGE_TAG" ]]; then
        log_error "Could not pull ETHGas Docker image from $repo"
        return 1
    fi

    ETHGAS_RUNTIME_MODE="docker"
    ETHGAS_DOCKER_IMAGE="${repo}:${ETHGAS_IMAGE_TAG}"
    log_info "✓ ETHGas Docker image ready: $ETHGAS_DOCKER_IMAGE"
    return 0
}

setup_firewall_rules "$ETHGAS_PORT"

ETHGAS_DIR="$HOME/ethgas"
ensure_directory "$ETHGAS_DIR"
ensure_directory "$ETHGAS_DIR/logs"
ensure_directory "$ETHGAS_DIR/records"

cd "$ETHGAS_DIR" || exit

# Resolve runtime mode
ETHGAS_RUNTIME_MODE=""
if [[ "$ETHGAS_INSTALL_METHOD" == "docker" ]]; then
    if ! can_use_docker; then
        log_error "ETHGAS_INSTALL_METHOD=docker but Docker daemon is not available."
        exit 1
    fi
    install_ethgas_docker || exit 1
elif [[ "$ETHGAS_INSTALL_METHOD" == "source" ]]; then
    install_ethgas_source || exit 1
else
    if ! can_use_docker; then
        log_error "ETHGas prebuilt install requires Docker daemon, but Docker is unavailable."
        log_error "Use ETHGAS_INSTALL_METHOD=source only if you explicitly want source compilation."
        exit 1
    fi
    install_ethgas_docker || exit 1
fi

# ============================================================================
# CONFIGURATION
# ============================================================================

# Ensure JWT secret exists
ensure_jwt_secret "$HOME/secrets/jwt.hex"

CONFIG_DIR="$ETHGAS_DIR/config"
ensure_directory "$CONFIG_DIR"

log_info "Creating ETHGas configuration..."
cat > "$CONFIG_DIR/ethgas.toml" << EOF
# ETHGas Preconfirmation Protocol Configuration — generated $(date +%Y-%m-%d)

[chain]
chain = "$ETHGAS_NETWORK"
beacon_node_url = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT"

[signer]
signer_url = "http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_SIGNER_PORT"
jwt_secret = "$HOME/secrets/jwt.hex"

[ethgas]
api_endpoint = "$ETHGAS_API_ENDPOINT"
collateral_contract = "$ETHGAS_COLLATERAL_CONTRACT"
registration_mode = "$ETHGAS_REGISTRATION_MODE"
fee_recipient = "$FEE_RECIPIENT"
min_preconf_value = "$ETHGAS_MIN_PRECONF_VALUE"
enable_registration = true
collateral_per_slot = 0.1
overall_wait_interval_in_second = 60

[logging]
level = "info"

[metrics]
enabled = true
port = $ETHGAS_METRICS_PORT
address = "$ETHGAS_HOST"
EOF

log_info "Configuration: $CONFIG_DIR/ethgas.toml"

# ============================================================================
# SYSTEMD SERVICE
# ============================================================================

# Create systemd service for ETHGas
log_info "Creating systemd service..."

# Set runtime command for systemd
if [[ "$ETHGAS_RUNTIME_MODE" == "docker" ]]; then
    ETHGAS_EXEC_START="docker run --rm --name ethgas --network host -e CB_MODULE_ID=ETHGAS_COMMIT -e CB_CONFIG=/etc/ethgas/ethgas.toml -e CB_SIGNER_URL=http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_SIGNER_PORT -e CB_METRICS_PORT=$ETHGAS_METRICS_PORT -e CB_LOGS_DIR=/var/log/ethgas -v $CONFIG_DIR/ethgas.toml:/etc/ethgas/ethgas.toml:ro -v $ETHGAS_DIR/logs:/var/log/ethgas -v $ETHGAS_DIR/records:/app $ETHGAS_DOCKER_IMAGE"
else
    ETHGAS_EXEC_START="$ETHGAS_BIN_PATH --config $CONFIG_DIR/ethgas.toml"
fi

# Create service with dependency on Commit-Boost
create_systemd_service "ethgas" "ETHGas Preconfirmation Protocol" "$ETHGAS_EXEC_START" "$(whoami)" "always" "600" "5" "300" "network-online.target commit-boost-pbs.service commit-boost-signer.service" "network-online.target commit-boost-pbs.service commit-boost-signer.service"
if [[ "$ETHGAS_RUNTIME_MODE" == "source" ]]; then
    sudo sed -i '/^\[Service\]/a Environment="CB_MODULE_ID=ETHGAS_COMMIT"' /etc/systemd/system/ethgas.service
    sudo sed -i '/^\[Service\]/a Environment="CB_CONFIG='"$CONFIG_DIR"'/ethgas.toml"' /etc/systemd/system/ethgas.service
    sudo sed -i '/^\[Service\]/a Environment="CB_SIGNER_URL=http://'"$COMMIT_BOOST_HOST:$COMMIT_BOOST_SIGNER_PORT"'"' /etc/systemd/system/ethgas.service
    sudo sed -i '/^\[Service\]/a Environment="CB_METRICS_PORT='"$ETHGAS_METRICS_PORT"'"' /etc/systemd/system/ethgas.service
    sudo sed -i '/^\[Service\]/a Environment="CB_LOGS_DIR='"$ETHGAS_DIR"'/logs"' /etc/systemd/system/ethgas.service
fi

# Enable and start the service
enable_and_start_systemd_service "ethgas"

log_installation_complete "ETHGas" "ethgas" "$CONFIG_DIR/ethgas.toml" "$ETHGAS_DIR"

# Display setup information
cat << EOF

=== ETHGas Setup Information ===

ETHGas has been installed with the following configuration:

Installation Directory: $ETHGAS_DIR
Runtime Mode: $ETHGAS_RUNTIME_MODE
Binary (source mode): ${ETHGAS_BIN_PATH:-N/A}
Docker image (docker mode): ${ETHGAS_DOCKER_IMAGE:-N/A}
Configuration: $CONFIG_DIR/ethgas.toml
Network: $ETHGAS_NETWORK
Collateral Contract: $ETHGAS_COLLATERAL_CONTRACT

Key Features:
- Preconfirmation (precon) protocol for real-time transactions
- ETHGas Exchange integration for buying/selling precons
- Collateral-based security model
- Support for standard, SSV, and Obol validators
- Audited by Sigma Prime

Service Management:
- Start:  sudo systemctl start ethgas
- Stop:   sudo systemctl stop ethgas
- Status: sudo systemctl status ethgas
- Logs:   journalctl -u ethgas -f

Dependencies (REQUIRED):
- ✓ Commit-Boost PBS:    systemctl status commit-boost-pbs
- ✓ Commit-Boost Signer: systemctl status commit-boost-signer

Verification:
- Check service: sudo systemctl status ethgas
- Check logs:    journalctl -u ethgas -n 50
- Check metrics: curl http://$ETHGAS_HOST:$ETHGAS_METRICS_PORT/metrics

⚠️  IMPORTANT NOTES:

1. **ETHGas requires Commit-Boost** to be running
   - PBS module must be active: sudo systemctl status commit-boost-pbs
   - Signer module must be active: sudo systemctl status commit-boost-signer

2. **Collateral Contract**
   - Mainnet: $ETHGAS_COLLATERAL_CONTRACT_MAINNET
   - Holesky:  $ETHGAS_COLLATERAL_CONTRACT_HOLESKY
   - Current:  $ETHGAS_COLLATERAL_CONTRACT
   - You must deposit collateral to participate

3. **Registration Mode: $ETHGAS_REGISTRATION_MODE**
   - standard: Most typical validators
   - ssv: SSV validators (requires additional config)
   - obol: Obol validators  
   - skip: Skip registration

4. **Validator Keys**
   - ETHGas uses Commit-Boost signer for validator key management
   - Ensure your validator keys are properly configured in Commit-Boost

5. **Consensus Client Configuration**
   - Your consensus client should point to Commit-Boost PBS:
   - Endpoint: http://$COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT

Next Steps:
1. Deposit collateral to contract (if not already done)
   - Visit: https://app.ethgas.com/my-portfolio/accounts
2. Verify Commit-Boost is running: sudo systemctl status commit-boost-pbs
3. Check ETHGas service: sudo systemctl status ethgas
4. Monitor logs: journalctl -u ethgas -f
5. Verify registration: Check logs for "registration successful"

For more information:
- Documentation: https://docs.ethgas.com/
- API Documentation: https://developers.ethgas.com/
- Repository: https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module
- Twitter: https://x.com/ETHGASofficial

EOF
