#!/bin/bash

# Common functions library for Ethereum client installation scripts
# This reduces code duplication across all install scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user."
        exit 1
    fi
}

# Check if running as root (for scripts that need root)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root."
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt update -y
    sudo apt dist-upgrade -y
    log_success "System packages updated"
}

# Install common dependencies
install_common_deps() {
    log_info "Installing common dependencies..."
    sudo apt install -y curl wget git build-essential pkg-config libssl-dev
    log_success "Common dependencies installed"
}

# Install Go
install_go() {
    log_info "Installing Go..."
    if ! command -v go &> /dev/null; then
        sudo snap install --classic go
        sudo ln -sf /snap/bin/go /usr/bin/go
        log_success "Go installed"
    else
        log_info "Go already installed"
    fi
}

# Install Rust
install_rust() {
    log_info "Installing Rust..."
    if ! command -v cargo &> /dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        log_success "Rust installed"
    else
        log_info "Rust already installed"
    fi
}

# Install Java (for Teku)
install_java() {
    log_info "Installing Java..."
    if ! command -v java &> /dev/null; then
        sudo apt install -y openjdk-17-jdk
        log_success "Java installed"
    else
        log_info "Java already installed"
    fi
}

# Install Node.js (for Lodestar)
install_nodejs() {
    log_info "Installing Node.js..."
    if ! command -v node &> /dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt install -y nodejs
        log_success "Node.js installed"
    else
        log_info "Node.js already installed"
    fi
}

# Create systemd service
create_systemd_service() {
    local service_name="$1"
    local description="$2"
    local exec_start="$3"
    local user="$4"
    local wants="${5:-network-online.target}"
    local after="${6:-network-online.target}"
    local restart="${7:-on-failure}"
    local restart_sec="${8:-5}"
    local timeout_stop_sec="${9:-600}"
    local timeout_sec="${10:-300}"

    log_info "Creating systemd service: $service_name"
    
    cat > "$HOME/${service_name}.service" << EOF
[Unit]
Description     = $description
Wants           = $wants
After           = $after

[Service]
User            = $user
ExecStart       = $exec_start
Restart         = $restart
RestartSec      = $restart_sec
TimeoutStopSec  = $timeout_stop_sec
TimeoutSec      = $timeout_sec

[Install]
WantedBy        = multi-user.target
EOF

    sudo mv "$HOME/${service_name}.service" "/etc/systemd/system/${service_name}.service"
    sudo chmod 644 "/etc/systemd/system/${service_name}.service"
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    
    log_success "Systemd service $service_name created and enabled"
}

# Start and check service
start_service() {
    local service_name="$1"
    
    log_info "Starting service: $service_name"
    sudo systemctl start "$service_name"
    
    if sudo systemctl is-active --quiet "$service_name"; then
        log_success "Service $service_name started successfully"
    else
        log_error "Failed to start service $service_name"
        sudo systemctl status "$service_name"
        return 1
    fi
}

# Check service status
check_service_status() {
    local service_name="$1"
    
    log_info "Checking status of service: $service_name"
    sudo systemctl status "$service_name" --no-pager
}

# Create JWT secret
create_jwt_secret() {
    local jwt_path="$1"
    
    if [[ ! -f "$jwt_path" ]]; then
        log_info "Creating JWT secret at $jwt_path"
        mkdir -p "$(dirname "$jwt_path")"
        openssl rand -hex 32 > "$jwt_path"
        chmod 600 "$jwt_path"
        log_success "JWT secret created"
    else
        log_info "JWT secret already exists at $jwt_path"
    fi
}

# Create secrets directory
create_secrets_dir() {
    local secrets_dir="$HOME/secrets"
    
    if [[ ! -d "$secrets_dir" ]]; then
        log_info "Creating secrets directory: $secrets_dir"
        mkdir -p "$secrets_dir"
        chmod 700 "$secrets_dir"
        log_success "Secrets directory created"
    else
        log_info "Secrets directory already exists"
    fi
}

# Download and extract binary
download_binary() {
    local url="$1"
    local output_file="$2"
    local extract_dir="$3"
    
    log_info "Downloading binary from $url"
    wget -O "$output_file" "$url"
    
    if [[ -n "$extract_dir" ]]; then
        log_info "Extracting to $extract_dir"
        mkdir -p "$extract_dir"
        tar -xzf "$output_file" -C "$extract_dir" --strip-components=1
        rm "$output_file"
    fi
    
    log_success "Binary downloaded and extracted"
}

# Clone and build from source
clone_and_build() {
    local repo_url="$1"
    local repo_name="$2"
    local build_dir="$3"
    local build_cmd="$4"
    local branch="${5:-main}"
    
    log_info "Cloning repository: $repo_name"
    
    if [[ -d "$build_dir" ]]; then
        log_info "Repository already exists, updating..."
        cd "$build_dir"
        git pull
    else
        git clone --branch "$branch" --single-branch "$repo_url" "$build_dir"
        cd "$build_dir"
    fi
    
    log_info "Building $repo_name..."
    eval "$build_cmd"
    
    log_success "$repo_name built successfully"
}

# Open firewall ports
open_firewall_ports() {
    local ports=("$@")
    
    for port in "${ports[@]}"; do
        log_info "Opening firewall port: $port"
        sudo ufw allow "$port"
    done
    
    log_success "Firewall ports opened"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get latest release from GitHub
get_latest_release() {
    local repo="$1"
    curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Get system architecture
get_arch() {
    case "$(uname -m)" in
        x86_64) echo "x86_64" ;;
        aarch64) echo "aarch64" ;;
        arm64) echo "aarch64" ;;
        *) echo "unsupported" ;;
    esac
}

# Get OS
get_os() {
    case "$(uname -s)" in
        Linux*) echo "linux" ;;
        Darwin*) echo "darwin" ;;
        *) echo "unsupported" ;;
    esac
}

# Create configuration file
create_config_file() {
    local config_path="$1"
    local config_content="$2"
    
    log_info "Creating configuration file: $config_path"
    mkdir -p "$(dirname "$config_path")"
    cat > "$config_path" << EOF
$config_content
EOF
    log_success "Configuration file created: $config_path"
}

# Backup existing file
backup_file() {
    local file_path="$1"
    
    if [[ -f "$file_path" ]]; then
        local backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backing up $file_path to $backup_path"
        cp "$file_path" "$backup_path"
        log_success "File backed up"
    fi
}

# Validate configuration
validate_config() {
    local required_vars=("$@")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            log_error "Required configuration variable $var is not set"
            return 1
        fi
    done
    
    log_success "Configuration validation passed"
    return 0
}

# Print installation summary
print_installation_summary() {
    local client_name="$1"
    local services=("${@:2}")
    
    echo
    log_success "=== $client_name Installation Complete ==="
    echo
    log_info "Installed services:"
    for service in "${services[@]}"; do
        echo "  - $service"
    done
    echo
    log_info "To start services:"
    for service in "${services[@]}"; do
        echo "  sudo systemctl start $service"
    done
    echo
    log_info "To check status:"
    for service in "${services[@]}"; do
        echo "  sudo systemctl status $service"
    done
    echo
    log_info "To view logs:"
    for service in "${services[@]}"; do
        echo "  sudo journalctl -u $service -f"
    done
    echo
}