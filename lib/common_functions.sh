#!/bin/bash

# Common functions library for Ethereum client installation scripts
# This library contains shared functions to reduce code duplication

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as correct user
check_user() {
    local expected_user="$1"
    if [[ $(whoami) != "$expected_user" ]]; then
        log_error "This script should be run as user: $expected_user"
        exit 1
    fi
}

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_info "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Download file with retry logic
download_file() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if curl -fsSL "$url" -o "$output"; then
            log_info "Successfully downloaded: $output"
            return 0
        else
            ((retry_count++))
            log_warn "Download failed, attempt $retry_count/$max_retries"
            sleep 2
        fi
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

# Create systemd service file
create_systemd_service() {
    local service_name="$1"
    local description="$2"
    local exec_start="$3"
    local user="${4:-$(whoami)}"
    local restart="${5:-on-failure}"
    local timeout_stop="${6:-600}"
    local restart_sec="${7:-5}"
    local timeout_sec="${8:-300}"
    local wants="${9:-network-online.target}"
    local after="${10:-network-online.target}"
    
    local service_file="$HOME/${service_name}.service"
    
    cat > "$service_file" << EOF
[Unit]
Description=$description
Wants=$wants
After=$after

[Service]
User=$user
ExecStart=$exec_start
Restart=$restart
TimeoutStopSec=$timeout_stop
RestartSec=$restart_sec
TimeoutSec=$timeout_sec

[Install]
WantedBy=multi-user.target
EOF

    # Move to systemd directory and set permissions
    sudo mv "$service_file" "/etc/systemd/system/${service_name}.service"
    sudo chmod 644 "/etc/systemd/system/${service_name}.service"
    
    log_info "Created systemd service: ${service_name}.service"
}

# Enable and reload systemd service
enable_systemd_service() {
    local service_name="$1"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    
    log_info "Enabled systemd service: $service_name"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system compatibility
check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    # Check if we're on a supported system
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine operating system"
        return 1
    fi
    
    source /etc/os-release
    case "$ID" in
        ubuntu|debian)
            log_info "Detected $PRETTY_NAME - supported system"
            ;;
        *)
            log_warn "Detected $PRETTY_NAME - may not be fully supported"
            log_warn "Scripts are designed for Ubuntu/Debian systems"
            ;;
    esac
    
    # Check for required commands
    local required_commands=("sudo" "curl" "wget")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Please install missing commands and try again"
        return 1
    fi
    
    return 0
}

# Install dependencies with proper error handling
install_dependencies() {
    local packages=("$@")
    
    # Check if apt is available
    if ! command_exists apt; then
        log_error "apt package manager not found"
        log_error "This script requires Ubuntu/Debian system with apt"
        return 1
    fi
    
    log_info "Updating package lists..."
    if ! sudo apt update -y; then
        log_error "Failed to update package lists"
        log_error "Please check your internet connection and try again"
        return 1
    fi
    
    log_info "Installing dependencies: ${packages[*]}"
    if ! sudo apt install -y "${packages[@]}"; then
        log_error "Failed to install dependencies: ${packages[*]}"
        log_error "Please check package names and try again"
        return 1
    fi
    
    log_info "Dependencies installed successfully"
}

# Setup firewall rules with graceful degradation
setup_firewall_rules() {
    local ports=("$@")
    
    # Check if UFW is available
    if ! command_exists ufw; then
        log_warn "UFW not found - attempting to install..."
        if ! install_dependencies ufw; then
            log_warn "Failed to install UFW - firewall rules will not be configured"
            log_warn "Please manually configure firewall for ports: ${ports[*]}"
            return 0
        fi
    fi
    
    # Check if UFW is active
    if ! sudo ufw status | grep -q "Status: active"; then
        log_info "UFW is not active - enabling..."
        if ! sudo ufw --force enable; then
            log_warn "Failed to enable UFW - firewall rules will not be configured"
            log_warn "Please manually configure firewall for ports: ${ports[*]}"
            return 0
        fi
    fi
    
    # Configure firewall rules
    for port in "${ports[@]}"; do
        log_info "Opening firewall port: $port"
        if ! sudo ufw allow "$port"; then
            log_warn "Failed to open port $port - please configure manually"
        fi
    done
    
    log_info "Firewall configuration completed"
}

# Add PPA repository with graceful degradation
add_ppa_repository() {
    local ppa="$1"
    
    # Check if add-apt-repository is available
    if ! command_exists add-apt-repository; then
        log_warn "add-apt-repository not found - attempting to install..."
        if ! install_dependencies software-properties-common; then
            log_error "Failed to install software-properties-common"
            log_error "Cannot add PPA repository: $ppa"
            return 1
        fi
    fi
    
    log_info "Adding PPA repository: $ppa"
    if ! sudo add-apt-repository -y "$ppa"; then
        log_error "Failed to add PPA repository: $ppa"
        return 1
    fi
    
    log_info "PPA repository added successfully"
    return 0
}

# Create JWT secret if it doesn't exist
ensure_jwt_secret() {
    local jwt_path="$1"
    local jwt_dir
    jwt_dir=$(dirname "$jwt_path")
    
    ensure_directory "$jwt_dir"
    
    if [[ ! -f "$jwt_path" ]]; then
        log_info "Creating JWT secret at: $jwt_path"
        openssl rand -hex 32 > "$jwt_path"
        chmod 600 "$jwt_path"
    else
        log_info "JWT secret already exists at: $jwt_path"
    fi
}

# Clone or update git repository
clone_or_update_repo() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="${3:-main}"
    
    if [[ -d "$target_dir" ]]; then
        log_info "Updating existing repository: $target_dir"
        cd "$target_dir" || return
        git fetch origin
        git checkout "$branch"
        git pull origin "$branch"
    else
        log_info "Cloning repository: $repo_url"
        git clone --branch "$branch" "$repo_url" "$target_dir"
        cd "$target_dir" || return
    fi
}

# Check if service is running
check_service_status() {
    local service_name="$1"
    
    if systemctl is-active --quiet "$service_name"; then
        log_info "Service $service_name is running"
        return 0
    else
        log_warn "Service $service_name is not running"
        return 1
    fi
}

# Wait for service to be ready
wait_for_service() {
    local service_name="$1"
    local max_wait="${2:-60}"
    local wait_time=0
    
    log_info "Waiting for service $service_name to be ready..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        if check_service_status "$service_name"; then
            return 0
        fi
        sleep 5
        ((wait_time += 5))
    done
    
    log_error "Service $service_name did not start within ${max_wait} seconds"
    return 1
}

# Create configuration file from template
create_config_from_template() {
    local template_file="$1"
    local output_file="$2"
    local temp_file="$3"
    
    if [[ -f "$temp_file" ]]; then
        cat "$template_file" "$temp_file" > "$output_file"
        rm -f "$temp_file"
        log_info "Created configuration file: $output_file"
    else
        cp "$template_file" "$output_file"
        log_info "Copied template to: $output_file"
    fi
}

# Validate configuration file
validate_config() {
    local config_file="$1"
    local validator_cmd="$2"
    
    if [[ -n "$validator_cmd" ]]; then
        if eval "$validator_cmd '$config_file'"; then
            log_info "Configuration file is valid: $config_file"
            return 0
        else
            log_error "Configuration file is invalid: $config_file"
            return 1
        fi
    else
        if [[ -f "$config_file" ]]; then
            log_info "Configuration file exists: $config_file"
            return 0
        else
            log_error "Configuration file not found: $config_file"
            return 1
        fi
    fi
}

# Get latest release version from GitHub
get_latest_release() {
    local repo="$1"
    local version
    version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    echo "$version"
}

# Extract archive
extract_archive() {
    local archive_file="$1"
    local target_dir="$2"
    local strip_components="${3:-1}"
    
    ensure_directory "$target_dir"
    
    case "$archive_file" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive_file" -C "$target_dir" --strip-components="$strip_components"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xjf "$archive_file" -C "$target_dir" --strip-components="$strip_components"
            ;;
        *.zip)
            unzip -q "$archive_file" -d "$target_dir"
            ;;
        *)
            log_error "Unsupported archive format: $archive_file"
            return 1
            ;;
    esac
    
    log_info "Extracted archive: $archive_file"
}

# Check system requirements
check_system_requirements() {
    local min_memory_gb="$1"
    local min_disk_gb="$2"
    
    # Check memory
    local memory_gb
    memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ "$memory_gb" -lt "$min_memory_gb" ]]; then
        log_warn "System has ${memory_gb}GB RAM, recommended minimum is ${min_memory_gb}GB"
    else
        log_info "Memory check passed: ${memory_gb}GB RAM available"
    fi
    
    # Check disk space
    local disk_gb
    disk_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ "$disk_gb" -lt "$min_disk_gb" ]]; then
        log_warn "Available disk space: ${disk_gb}GB, recommended minimum is ${min_disk_gb}GB"
    else
        log_info "Disk space check passed: ${disk_gb}GB available"
    fi
}

# Service management functions
start_all_services() {
    local services=("eth1" "cl" "validator" "mev" "nginx")
    log_info "Starting all Ethereum services..."
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_info "Service $service is already running"
        else
            log_info "Starting $service..."
            if sudo systemctl start "$service"; then
                log_info "Successfully started $service"
            else
                log_error "Failed to start $service"
            fi
        fi
    done
    
    log_info "Service start process completed"
}

stop_all_services() {
    local services=("eth1" "cl" "validator" "mev" "nginx")
    log_info "Stopping all Ethereum services..."
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log_info "Stopping $service..."
            sudo systemctl stop "$service" || log_warn "Failed to stop $service"
        else
            log_info "Service $service is not running"
        fi
    done
    
    log_info "All services stopped"
}

restart_all_services() {
    local services=("eth1" "cl" "validator" "mev" "nginx")
    log_info "Restarting all Ethereum services..."
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            log_info "Restarting $service..."
            if sudo systemctl restart "$service"; then
                log_info "Successfully restarted $service"
            else
                log_error "Failed to restart $service"
            fi
        else
            log_warn "Service $service is not enabled, skipping"
        fi
    done
    
    log_info "Service restart process completed"
}

show_service_status() {
    local services=("eth1" "cl" "validator" "mev" "nginx")
    log_info "Checking service status..."
    
    for service in "${services[@]}"; do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            echo "=== $service Status ==="
            systemctl status "$service" --no-pager -l
            echo
        else
            log_warn "Service $service is not enabled"
        fi
    done
}

show_installation_complete() {
    local client_name="$1"
    local service_name="$2"
    local config_file="$3"
    local data_dir="$4"
    
    log_info "$client_name installation completed!"
    
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        log_info "Configuration file: $config_file"
    elif [[ -n "$config_file" ]]; then
        log_warn "Configuration file specified but not found: $config_file"
    fi
    
    if [[ -n "$data_dir" && -d "$data_dir" ]]; then
        log_info "Data directory: $data_dir"
    elif [[ -n "$data_dir" ]]; then
        log_warn "Data directory specified but not found: $data_dir"
    fi
    
    log_info "To start $client_name: sudo systemctl start $service_name"
    log_info "To check status: sudo systemctl status $service_name"
    log_info "To view logs: journalctl -fu $service_name"
}

# Input validation functions
require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Required command '$1' not found. Please install it and try again."
        exit 1
    fi
}

validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [[ "$port" -ge 1 ]] && [[ "$port" -le 65535 ]]; then
        return 0
    else
        return 1
    fi
}

validate_ethereum_address() {
    local address="$1"
    if [[ "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Enhanced error handling
check_service_health() {
    local service_name="$1"
    local max_wait="${2:-30}"
    local wait_time=0
    
    log_info "Checking health of service: $service_name"
    
    while [[ $wait_time -lt $max_wait ]]; do
        if systemctl is-active --quiet "$service_name"; then
            log_info "Service $service_name is healthy"
            return 0
        fi
        sleep 2
        ((wait_time += 2))
    done
    
    log_error "Service $service_name failed health check after ${max_wait} seconds"
    return 1
}