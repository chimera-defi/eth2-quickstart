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
        local client_type=$(basename "$(dirname "$config_file")")
        configure_network_restrictions "$client_type" "$config_file"
    done
}

# Secure error handling functions
secure_error_handling() {
    local error_msg="$1"
    local log_level="${2:-error}"
    local show_details="${3:-false}"
    
    # Sanitize error message to prevent information disclosure
    local sanitized_msg=$(echo "$error_msg" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 100)
    
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
        apt install -y aide
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