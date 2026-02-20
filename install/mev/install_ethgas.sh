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

# Verify Commit-Boost services exist
if ! systemctl list-unit-files | grep -q "commit-boost-pbs.service"; then
    log_error "Commit-Boost PBS service not found. Please install Commit-Boost first."
    exit 1
fi

# ETHGas requires the signer — ensure it's enabled and started
if [[ -f /etc/systemd/system/commit-boost-signer.service ]]; then
    if ! systemctl is-active --quiet commit-boost-signer 2>/dev/null; then
        log_info "Starting Commit-Boost Signer (required by ETHGas)..."
        sudo systemctl enable --now commit-boost-signer 2>/dev/null || true
    fi
    if ! systemctl is-active --quiet commit-boost-signer 2>/dev/null; then
        log_warn "Commit-Boost Signer not running. ETHGas needs it for validator key operations."
        log_warn "Configure [signer] in ~/commit-boost/config/cb-config.toml, then:"
        log_warn "  sudo systemctl enable --now commit-boost-signer"
    fi
else
    log_error "Commit-Boost Signer service not found. Please install Commit-Boost first."
    exit 1
fi

log_info "Commit-Boost dependency verified"

# Verify Rust is available (installed centrally via install_dependencies.sh)
[[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:${PATH:-}"

if ! command -v cargo &> /dev/null; then
    log_error "Rust/Cargo not found. Please run install_dependencies.sh first."
    log_error "Or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    exit 1
fi

log_info "Using Rust: $(rustc --version)"

setup_firewall_rules "$ETHGAS_PORT"

ETHGAS_DIR="$HOME/ethgas"
ensure_directory "$ETHGAS_DIR"

cd "$ETHGAS_DIR" || exit

log_info "Cloning ETHGas repository..."
if [[ -d ".git" ]]; then
    log_info "Updating existing ETHGas repository..."
    git fetch origin
    git checkout main
    git pull origin main
else
    if ! git clone https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module.git .; then
        log_error "Failed to clone ETHGas repository"
        exit 1
    fi
fi

log_info "Fetching latest ETHGas release..."
LATEST_TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "main")
if [[ "$LATEST_TAG" != "main" ]]; then
    log_info "Checking out version: $LATEST_TAG"
    git checkout "$LATEST_TAG"
else
    log_warn "No stable release tag found, using main branch"
fi

log_info "Building ETHGas (may take 2-5 minutes)..."

if ! cargo build --release --bin ethgas_commit; then
    log_error "Failed to build ETHGas binary"
    log_error "Please check your Rust installation and build logs above"
    exit 1
fi

if [[ ! -f "$ETHGAS_DIR/target/release/ethgas_commit" ]]; then
    log_error "ETHGas binary not found at $ETHGAS_DIR/target/release/ethgas_commit"
    exit 1
fi

log_info "ETHGas binary built successfully"
chmod +x "$ETHGAS_DIR/target/release/ethgas_commit"

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

# Create systemd service
ETHGAS_EXEC_START="$ETHGAS_DIR/target/release/ethgas_commit --config $CONFIG_DIR/ethgas.toml"

# Create service with dependency on Commit-Boost
create_systemd_service "ethgas" "ETHGas Preconfirmation Protocol" "$ETHGAS_EXEC_START" "$(whoami)" "always" "600" "5" "300" "network-online.target commit-boost-pbs.service commit-boost-signer.service" "network-online.target commit-boost-pbs.service commit-boost-signer.service"

# Add environment variables to [Service] section
sudo sed -i '/^\[Service\]/a Environment="CB_SIGNER_URL=http://'"$COMMIT_BOOST_HOST"':'"$COMMIT_BOOST_SIGNER_PORT"'"\nEnvironment="CB_CONFIG='"$CONFIG_DIR"'/ethgas.toml"\nEnvironment="RUST_LOG=info"' /etc/systemd/system/ethgas.service
sudo systemctl daemon-reload

# Enable and start the service
enable_and_start_systemd_service "ethgas"

log_installation_complete "ETHGas" "ethgas" "$CONFIG_DIR/ethgas.toml" "$ETHGAS_DIR"

echo ""
log_info "ETHGas installed — network: $ETHGAS_NETWORK, contract: $ETHGAS_COLLATERAL_CONTRACT"
echo ""
log_warn "You must deposit collateral to participate in preconfirmations."
log_warn "  Deposit: https://app.ethgas.com/my-portfolio/accounts"
log_warn "  Docs:    https://docs.ethgas.com/"
