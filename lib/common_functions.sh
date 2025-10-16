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


# Enable and start systemd service (standard pattern for install scripts)
enable_and_start_systemd_service() {
    local service_name="$1"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    
    # Check if service is already running
    if systemctl is-active --quiet "$service_name"; then
        log_info "Service $service_name is already running, restarting to apply changes..."
        if sudo systemctl restart "$service_name"; then
            log_info "Restarted systemd service: $service_name"
            return 0
        else
            log_error "Failed to restart systemd service: $service_name"
            return 1
        fi
    else
        # Service is not running, start it
        if sudo systemctl start "$service_name"; then
            log_info "Started systemd service: $service_name"
            return 0
        else
            # Check if service exists
            if ! systemctl list-unit-files | grep -q "^${service_name}.service"; then
                log_error "Service $service_name does not exist - cannot start"
                return 1
            else
                log_error "Failed to start systemd service: $service_name"
                return 1
            fi
        fi
    fi
}


# Enable and start system service (for system services like nginx, fail2ban)
enable_and_start_system_service() {
    local service_name="$1"
    
    sudo systemctl daemon-reload
    
    if ! sudo systemctl enable "$service_name"; then
        log_error "Failed to enable system service: $service_name"
        return 1
    fi
    
    if ! sudo systemctl start "$service_name"; then
        log_error "Failed to start system service: $service_name"
        return 1
    fi
    
    log_info "Enabled and started system service: $service_name"
    return 0
}



# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system compatibility

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
