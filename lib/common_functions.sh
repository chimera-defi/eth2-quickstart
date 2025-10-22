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

# Download file with retry logic and security validation
download_file() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    
    # Use secure download function
    secure_download "$url" "$output" "$max_retries"
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

# Add PPA repository
add_ppa_repository() {
    local ppa="$1"
    
    if [[ -z "$ppa" ]]; then
        log_error "PPA repository not specified"
        return 1
    fi
    
    log_info "Adding PPA repository: $ppa"
    if ! sudo add-apt-repository "$ppa" -y; then
        log_error "Failed to add PPA repository: $ppa"
        return 1
    fi
    
    log_info "Successfully added PPA repository: $ppa"
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
    
    # Note: For initial setup, consider using the centralized dependency installer:
    # ./install/utils/install_dependencies.sh
    # This installs all common dependencies in one place to avoid duplicates
    
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
        log_error "UFW not found - dependencies should be installed centrally first"
        log_error "Please run install_dependencies.sh before setting up firewall rules"
        return 1
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

# Check system compatibility for Ethereum node setup
check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    # Check if running as root (only critical check)
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        return 1
    fi
    
    # Basic OS check (just warn if not Ubuntu/Debian)
    if [[ -f /etc/os-release ]]; then
        local os_id
        os_id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        case "$os_id" in
            "ubuntu"|"debian")
                log_info "✓ Running on $os_id"
                ;;
            *)
                log_warn "⚠ Unsupported OS: $os_id (designed for Ubuntu/Debian)"
                ;;
        esac
    fi
    
    # Check if system is 64-bit (critical for Ethereum clients)
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_error "Unsupported architecture: $arch (requires x86_64)"
        return 1
    fi
    
    log_info "✓ System compatibility check passed"
    return 0
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
# Removed unused functions: require_command, validate_ip, validate_port, validate_ethereum_address
# These duplicate existing functionality or are never used

# Enhanced input validation functions for security
validate_user_input() {
    local input="$1"
    local pattern="$2"
    local max_length="${3:-255}"
    
    # Check if input is empty
    if [[ -z "$input" ]]; then
        log_error "Input cannot be empty"
        return 1
    fi
    
    # Check input length
    if [[ ${#input} -gt "$max_length" ]]; then
        log_error "Input too long (max: $max_length characters)"
        return 1
    fi
    
    # Check pattern if provided
    if [[ -n "$pattern" && ! "$input" =~ $pattern ]]; then
        log_error "Invalid input format"
        return 1
    fi
    
    return 0
}

validate_menu_choice() {
    local choice="$1"
    local max_options="$2"
    
    # Check if choice is numeric
    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
        log_error "Invalid choice: $choice (must be a number)"
        return 1
    fi
    
    # Check if choice is within range
    if [[ "$choice" -lt 1 || "$choice" -gt "$max_options" ]]; then
        log_error "Choice out of range: $choice (valid range: 1-$max_options)"
        return 1
    fi
    
    return 0
}

# Removed unused functions: validate_filename, validate_url, sanitize_input

# Security functions
secure_file_permissions() {
    local file="$1"
    local permissions="${2:-600}"
    
    if [[ -f "$file" ]]; then
        chmod "$permissions" "$file"
        log_info "Secured file permissions for: $file"
    else
        log_warn "File not found for permission setting: $file"
    fi
}

secure_directory_permissions() {
    local directory="$1"
    local permissions="${2:-700}"
    
    if [[ -d "$directory" ]]; then
        chmod "$permissions" "$directory"
        log_info "Secured directory permissions for: $directory"
    else
        log_warn "Directory not found for permission setting: $directory"
    fi
}

secure_config_files() {
    log_info "Securing configuration files..."
    
    # Find and secure all configuration files
    find . -name "*.yaml" -o -name "*.toml" -o -name "*.cfg" -o -name "*.json" | while read -r file; do
        secure_file_permissions "$file" 600
    done
    
    # Secure secrets directory
    if [[ -d "$HOME/secrets" ]]; then
        secure_directory_permissions "$HOME/secrets" 700
        find "$HOME/secrets" -type f -exec chmod 600 {} \;
    fi
    
    # Secure SSH directory
    if [[ -d "$HOME/.ssh" ]]; then
        secure_directory_permissions "$HOME/.ssh" 700
        find "$HOME/.ssh" -type f -exec chmod 600 {} \;
    fi
}

# Network security functions
configure_network_restrictions() {
    local client_type="$1"
    local config_file="$2"
    
    log_info "Configuring network restrictions for $client_type..."
    
    case "$client_type" in
        "prysm")
            # Prysm already has p2p-allowlist: public which is good
            log_info "Prysm network restrictions already configured (p2p-allowlist: public)"
            ;;
        "teku"|"lighthouse"|"nimbus"|"lodestar"|"grandine")
            # Add consistent network restrictions for other clients
            if [[ -f "$config_file" ]]; then
                # Ensure all clients bind to localhost for API endpoints
                sed -i 's/0\.0\.0\.0/127.0.0.1/g' "$config_file"
                log_info "Updated $client_type configuration to use localhost binding"
            fi
            ;;
        "geth"|"besu"|"nethermind"|"erigon"|"reth")
            # Execution clients should bind to localhost for RPC endpoints
            if [[ -f "$config_file" ]]; then
                sed -i 's/0\.0\.0\.0/127.0.0.1/g' "$config_file"
                log_info "Updated $client_type configuration to use localhost binding"
            fi
            ;;
    esac
}

apply_network_security() {
    log_info "Applying network security configurations..."
    
    # Apply to all client configuration files
    find configs/ -name "*.yaml" -o -name "*.toml" -o -name "*.cfg" -o -name "*.json" | while read -r config_file; do
        local client_type
        client_type=$(basename "$(dirname "$config_file")")
        configure_network_restrictions "$client_type" "$config_file"
    done
}

# Secure error handling functions
secure_error_handling() {
    local error_msg="$1"
    local log_level="${2:-error}"
    local show_details="${3:-false}"
    
    # Sanitize error message to prevent information disclosure
    local sanitized_msg
    sanitized_msg=$(echo "$error_msg" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
    
    case "$log_level" in
        "error")
            if [[ "$show_details" == "true" ]]; then
                log_error "Operation failed: $sanitized_msg"
            else
                log_error "Operation failed. Check logs for details."
            fi
            ;;
        "warn")
            log_warn "Warning: $sanitized_msg"
            ;;
        *)
            log_info "Info: $sanitized_msg"
            ;;
    esac
}

safe_command_execution() {
    local command="$1"
    local error_msg="${2:-Command execution failed}"
    local show_output="${3:-false}"
    
    if [[ "$show_output" == "true" ]]; then
        if eval "$command" 2>&1; then
            return 0
        else
            secure_error_handling "$error_msg" "error" "true"
            return 1
        fi
    else
        if eval "$command" >/dev/null 2>&1; then
            return 0
        else
            secure_error_handling "$error_msg" "error" "false"
            return 1
        fi
    fi
}

secure_download() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    
    # Basic URL validation
    if [[ ! "$url" =~ ^https?:// ]]; then
        log_error "Invalid download URL: $url"
        return 1
    fi
    
    # Attempt download with retries
    local retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if curl -fsSL "$url" -o "$output" >/dev/null 2>&1; then
            log_info "Successfully downloaded: $output"
            return 0
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                log_warn "Download failed, attempt $retry_count/$max_retries"
                sleep 2
            fi
        fi
    done
    
    log_error "Failed to download after $max_retries attempts"
    return 1
}

# Rate limiting functions
add_rate_limiting() {
    local config_file="/etc/nginx/sites-available/default"
    
    log_info "Adding rate limiting to nginx configuration..."
    
    # Check if rate limiting is already configured
    if grep -q "limit_req_zone" "$config_file" 2>/dev/null; then
        log_info "Rate limiting already configured"
        return 0
    fi
    
    # Create backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add rate limiting configuration
    cat >> "$config_file" << 'EOF'

# Rate limiting for RPC endpoints
limit_req_zone $binary_remote_addr zone=rpc_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=ws_limit:10m rate=5r/s;
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=20r/s;

server {
    # Apply rate limiting to RPC endpoints
    location /rpc {
        limit_req zone=rpc_limit burst=20 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8545;
    }
    
    location /ws {
        limit_req zone=ws_limit burst=10 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8546;
    }
    
    location /api {
        limit_req zone=api_limit burst=30 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:5051;
    }
}
EOF

    # Test nginx configuration
    if nginx -t >/dev/null 2>&1; then
        log_info "Rate limiting configuration added successfully"
        systemctl reload nginx
    else
        log_error "Invalid nginx configuration, restoring backup"
        mv "${config_file}.backup.$(date +%Y%m%d_%H%M%S)" "$config_file"
        return 1
    fi
}

configure_ddos_protection() {
    log_info "Configuring DDoS protection..."
    
    # Add connection limiting
    cat > /etc/nginx/conf.d/security.conf << 'EOF'
# DDoS protection
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
limit_conn_zone $server_name zone=conn_limit_per_server:10m;

# Rate limiting
limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=10r/s;

# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

# Hide nginx version
server_tokens off;

# Connection limits
limit_conn conn_limit_per_ip 10;
limit_conn conn_limit_per_server 1000;
EOF

    log_info "DDoS protection configured"
}

# Comprehensive security monitoring
setup_security_monitoring() {
    log_info "Setting up comprehensive security monitoring..."
    
    # Create security monitoring script
    cat > /usr/local/bin/security_monitor.sh << 'EOF'
#!/bin/bash
# Comprehensive security monitoring script

LOG_FILE="/var/log/security_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting security monitoring check..." >> "$LOG_FILE"

# Check for suspicious processes
ps aux | grep -E "(nc|netcat|nmap|masscan|hydra|john)" | grep -v grep && echo "[$DATE] Suspicious process detected" >> "$LOG_FILE"

# Check for failed SSH attempts
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 >> "$LOG_FILE"

# Check for root login attempts
grep "root.*ssh" /var/log/auth.log 2>/dev/null | tail -3 >> "$LOG_FILE"

# Check disk usage
df -h | awk '$5 > 90 {print "[$DATE] Disk usage warning: " $0}' >> "$LOG_FILE"

# Check memory usage
free -m | awk 'NR==2{if($3/$2*100 > 90) print "[$DATE] Memory usage warning: " $3/$2*100 "%"}' >> "$LOG_FILE"

# Check for unusual network connections
ss -tuln | grep -E ":(22|80|443|8545|8546)" >> "$LOG_FILE" 2>/dev/null

# Check system load
uptime >> "$LOG_FILE"

# Check for failed systemd services
systemctl --failed --no-pager >> "$LOG_FILE" 2>/dev/null

echo "[$DATE] Security monitoring check completed" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/security_monitor.sh
    
    # Setup log rotation for security logs
    cat > /etc/logrotate.d/security_monitor << 'EOF'
/var/log/security_monitor.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    # Add to crontab for regular monitoring
    if ! grep -q "security_monitor" /etc/crontab; then
        echo "*/15 * * * * root /usr/local/bin/security_monitor.sh" >> /etc/crontab
    fi

    log_info "Comprehensive security monitoring configured"
}

setup_intrusion_detection() {
    log_info "Setting up intrusion detection..."
    
    # Install and configure AIDE (Advanced Intrusion Detection Environment)
    if ! command_exists aide; then
        log_error "AIDE not found - dependencies should be installed centrally first"
        log_error "Please run install_dependencies.sh before setting up intrusion detection"
        return 1
    fi
    
    # Initialize AIDE database
    if [[ ! -f /var/lib/aide/aide.db ]]; then
        aideinit
    fi
    
    # Create AIDE check script
    cat > /usr/local/bin/aide_check.sh << 'EOF'
#!/bin/bash
# AIDE intrusion detection check

LOG_FILE="/var/log/aide_check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Starting AIDE check..." >> "$LOG_FILE"

if aide --check >> "$LOG_FILE" 2>&1; then
    echo "[$DATE] AIDE check completed - no changes detected" >> "$LOG_FILE"
else
    echo "[$DATE] AIDE check completed - changes detected" >> "$LOG_FILE"
    # Send alert (you can customize this)
    echo "File system changes detected on $(hostname)" | mail -s "AIDE Alert" root
fi
EOF

    chmod +x /usr/local/bin/aide_check.sh
    
    # Add to crontab for daily checks
    if ! grep -q "aide_check" /etc/crontab; then
        echo "0 2 * * * root /usr/local/bin/aide_check.sh" >> /etc/crontab
    fi
    
    log_info "Intrusion detection configured"
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

# Secure password generation
generate_secure_password() {
    local length="${1:-16}"
    local password
    
    # Generate a secure random password with mixed case, numbers, and symbols
    password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-"$length")
    
    # Ensure password has at least one of each required character type
    while [[ ! "$password" =~ [A-Z] ]] || [[ ! "$password" =~ [a-z] ]] || [[ ! "$password" =~ [0-9] ]]; do
        password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-"$length")
    done
    
    echo "$password"
}

# Secure user creation and setup
setup_secure_user() {
    local username="$1"
    local password="$2"
    local ssh_key_file="${3:-}"
    
    log_info "Setting up secure user: $username"
    
    # Create user if it doesn't exist
    if ! id -u "$username" >/dev/null 2>&1; then
        log_info "Creating user: $username"
        if ! useradd -m -d "/home/$username" -s /bin/bash "$username"; then
            log_error "Failed to create user: $username"
            return 1
        fi
    else
        log_info "User $username already exists"
    fi
    
    # Set password
    if [[ -n "$password" ]]; then
        log_info "Setting password for user: $username"
        if ! echo "$username:$password" | chpasswd; then
            log_error "Failed to set password for user: $username"
            return 1
        fi
    fi
    
    # Setup SSH directory
    local ssh_dir="/home/$username/.ssh"
    mkdir -p "$ssh_dir"
    chown "$username:$username" "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Copy SSH keys if provided
    if [[ -n "$ssh_key_file" && -f "$ssh_key_file" ]]; then
        log_info "Copying SSH keys for user: $username"
        if ! cp "$ssh_key_file" "$ssh_dir/authorized_keys"; then
            log_error "Failed to copy SSH keys for user: $username"
            return 1
        fi
        chown "$username:$username" "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
    elif [[ -f /root/.ssh/authorized_keys ]]; then
        log_info "Copying root's SSH keys for user: $username"
        if ! cp /root/.ssh/authorized_keys "$ssh_dir/authorized_keys"; then
            log_error "Failed to copy root's SSH keys for user: $username"
            return 1
        fi
        chown "$username:$username" "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
    fi
    
    # Add to sudo group
    if ! groups "$username" | grep -q sudo; then
        log_info "Adding user to sudo group: $username"
        usermod -aG sudo "$username"
    fi
    
    # Copy repository to user's home
    local repo_name="${REPO_NAME:-eth2-quickstart}"
    if [[ -d "../$repo_name" ]]; then
        log_info "Copying repository to user's home: $username"
        if ! cp -r "../$repo_name" "/home/$username/"; then
            log_error "Failed to copy repository for user: $username"
            return 1
        fi
        chown -R "$username:$username" "/home/$username/$repo_name"
        chmod -R +x "/home/$username/$repo_name"
    else
        log_warn "Repository directory not found: ../$repo_name"
    fi
    
    log_info "✓ User setup completed: $username"
    return 0
}

# Configure sudo for user without password
configure_sudo_nopasswd() {
    local username="$1"
    
    log_info "Configuring sudo without password for user: $username"
    
    # Create sudoers file for the user
    local sudoers_file="/etc/sudoers.d/$username"
    
    if [[ -f "$sudoers_file" ]]; then
        log_info "Sudoers file already exists for $username"
        return 0
    fi
    
    # Create sudoers entry
    echo "$username ALL=(ALL) NOPASSWD: ALL" > "$sudoers_file"
    chmod 440 "$sudoers_file"
    
    # Verify sudoers syntax
    if ! visudo -c -f "$sudoers_file" >/dev/null 2>&1; then
        log_error "Invalid sudoers syntax for $username"
        rm -f "$sudoers_file"
        return 1
    fi
    
    log_info "✓ Sudo configuration completed for $username"
    return 0
}

# Configure SSH with security hardening
configure_ssh() {
    local ssh_port="$1"
    
    # Validate parameter
    if [[ -z "$ssh_port" ]]; then
        log_error "SSH port parameter is required"
        return 1
    fi
    
    log_info "Configuring SSH with security hardening..."
    
    # Backup existing SSH config
    [[ -f /etc/ssh/sshd_config ]] && mv /etc/ssh/sshd_config /etc/ssh/sshd_config.bkup
    
    # Copy new SSH config and banner
    cp ./configs/sshd_config /etc/ssh/sshd_config
    cp ./configs/ssh_banner /etc/ssh/ssh_banner
    
    # Update SSH port in configuration
    sed -i "s/^Port 22/Port $ssh_port/" /etc/ssh/sshd_config
    
    # Copy back for version control
    cp /etc/ssh/sshd_config ./configs/ || log_warn "Could not copy SSH config back"
    
    # Quick SSH config validation
    if sshd -t; then
        log_info "SSH configuration is valid"
    else
        log_error "SSH configuration is invalid, restoring backup"
        mv /etc/ssh/sshd_config.bkup /etc/ssh/sshd_config
        exit 1
    fi
    
    log_info "✓ SSH configured"
}

# Setup fail2ban with security configurations
setup_fail2ban() {
    log_info "Setting up fail2ban..."
    
    # Make the script executable and run it
    chmod +x ./install/security/install_fail2ban.sh
    if ! ./install/security/install_fail2ban.sh; then
        log_error "Failed to setup fail2ban"
        return 1
    fi
    
    log_info "✓ Fail2ban setup complete"
}

# Generate and display secure handoff information
generate_handoff_info() {
    local username="$1"
    local password="$2"
    local server_ip="$3"
    
    log_info "Generating secure handoff information..."
    
    cat << EOF

=== SECURE HANDOFF INFORMATION ===

User: $username
Password: $password
Server IP: $server_ip

SSH Connection:
ssh $username@$server_ip

IMPORTANT SECURITY NOTES:
1. Change the password immediately after first login
2. Consider setting up SSH key authentication
3. The user has sudo privileges without password prompt
4. All Ethereum client data will be stored in /home/$username

Next Steps:
1. SSH to the server: ssh $username@$server_ip
2. Change password: passwd
3. Run the second phase: ./run_2.sh

=== END HANDOFF INFORMATION ===

EOF
}