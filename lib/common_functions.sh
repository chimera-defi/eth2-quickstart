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

# Install dependencies
install_dependencies() {
    local packages=("$@")
    
    log_info "Updating package lists..."
    sudo apt update -y
    
    log_info "Installing dependencies: ${packages[*]}"
    sudo apt install -y "${packages[@]}"
}

# Setup firewall rules
setup_firewall_rules() {
    local ports=("$@")
    
    for port in "${ports[@]}"; do
        log_info "Opening firewall port: $port"
        sudo ufw allow "$port"
    done
}

# Create JWT secret if it doesn't exist
ensure_jwt_secret() {
    local jwt_path="$1"
    local jwt_dir=$(dirname "$jwt_path")
    
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
        cd "$target_dir"
        git fetch origin
        git checkout "$branch"
        git pull origin "$branch"
    else
        log_info "Cloning repository: $repo_url"
        git clone --branch "$branch" "$repo_url" "$target_dir"
        cd "$target_dir"
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
    local version=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
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
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $memory_gb -lt $min_memory_gb ]]; then
        log_warn "System has ${memory_gb}GB RAM, recommended minimum is ${min_memory_gb}GB"
    else
        log_info "Memory check passed: ${memory_gb}GB RAM available"
    fi
    
    # Check disk space
    local disk_gb=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ $disk_gb -lt $min_disk_gb ]]; then
        log_warn "Available disk space: ${disk_gb}GB, recommended minimum is ${min_disk_gb}GB"
    else
        log_info "Disk space check passed: ${disk_gb}GB available"
    fi
}