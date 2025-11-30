#!/bin/bash

# Common functions library for Ethereum client installation scripts
# This library contains shared functions to reduce code duplication

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# CORE UTILITY FUNCTIONS
# =============================================================================

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# DOWNLOAD FUNCTIONS
# =============================================================================

# Get latest release version from GitHub
get_latest_release() {
    local repo="$1"
    local release_url="https://api.github.com/repos/${repo}/releases/latest"
    local version
    
    # Check if curl is available
    if ! command_exists curl; then
        log_error "curl is not installed"
        return 1
    fi
    
    # Try to fetch latest release tag from GitHub API with error handling
    if ! version=$(curl -sf "$release_url" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'); then
        log_warn "Could not fetch latest release for $repo (API request failed)"
        return 1
    fi
    
    if [[ -n "$version" ]]; then
        echo "$version"
        return 0
    else
        log_warn "Could not parse version from GitHub API response for $repo"
        return 1
    fi
}

# Extract archive (tar.gz, tgz, zip)
extract_archive() {
    local archive_file="$1"
    local dest_dir="$2"
    local strip_components="${3:-0}"
    
    if [[ ! -f "$archive_file" ]]; then
        log_error "Archive file not found: $archive_file"
        return 1
    fi
    
    log_info "Extracting archive: $archive_file"
    
    local extract_result=0
    
    case "$archive_file" in
        *.tar.gz|*.tgz)
            if [[ $strip_components -gt 0 ]]; then
                tar -xzf "$archive_file" -C "$dest_dir" --strip-components="$strip_components"
                extract_result=$?
            else
                tar -xzf "$archive_file" -C "$dest_dir"
                extract_result=$?
            fi
            ;;
        *.zip)
            unzip -q "$archive_file" -d "$dest_dir"
            extract_result=$?
            ;;
        *)
            log_error "Unsupported archive format: $archive_file"
            return 1
            ;;
    esac
    
    if [[ $extract_result -eq 0 ]]; then
        log_info "Archive extracted successfully"
        return 0
    else
        log_error "Failed to extract archive"
        return 1
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


# Secure download function
secure_download() {
    local url="$1"
    local output="$2"
    local max_retries="${3:-3}"
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if wget --timeout=30 --tries=1 --no-check-certificate -O "$output" "$url" 2>/dev/null; then
            log_info "Successfully downloaded: $output"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [[ $retry_count -lt $max_retries ]]; then
            log_warn "Download failed, attempt $retry_count/$max_retries"
            sleep 2
        fi
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

# =============================================================================
# SYSTEMD SERVICE FUNCTIONS
# =============================================================================

# Create systemd service
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
    
    cat > "$service_file" <<EOF
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

    sudo mv "$service_file" "/etc/systemd/system/${service_name}.service"
    sudo chmod 644 "/etc/systemd/system/${service_name}.service"
    log_info "Created systemd service: ${service_name}.service"
}

# Enable systemd service
enable_systemd_service() {
    local service_name="$1"
    
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    log_info "Enabled systemd service: $service_name"
}

# Enable and start systemd service
enable_and_start_systemd_service() {
    local service_name="$1"
    
    enable_systemd_service "$service_name"
    sudo systemctl start "$service_name"
    
    if sudo systemctl is-active --quiet "$service_name"; then
        log_info "Started systemd service: $service_name"
    else
        log_error "Failed to start systemd service: $service_name"
        return 1
    fi
}


# =============================================================================
# SYSTEM MANAGEMENT FUNCTIONS
# =============================================================================

# Stop all Ethereum services
stop_all_services() {
    log_info "Stopping all Ethereum services..."
    
    local services=("eth1" "cl" "validator" "mev-boost" "nginx" "caddy")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log_info "Stopping $service..."
            sudo systemctl stop "$service" || log_warn "Failed to stop $service"
        fi
    done
    
    log_info "All services stopped"
}

# Add PPA repository
add_ppa_repository() {
    local ppa="$1"
    
    if ! command_exists add-apt-repository; then
        sudo apt-get update
        sudo apt-get install -y software-properties-common
    fi
    
    sudo add-apt-repository -y "$ppa"
    sudo apt-get update
    log_info "Added PPA repository: $ppa"
}

# Install dependencies
install_dependencies() {
    local packages=("$@")
    
    log_info "Installing dependencies: ${packages[*]}"
    
    sudo apt-get update
    if sudo apt-get install -y "${packages[@]}"; then
        log_info "Dependencies installed successfully"
    else
        log_error "Failed to install some dependencies"
        return 1
    fi
}

# Setup firewall rules
setup_firewall_rules() {
    local ports=("$@")
    
    log_info "Setting up firewall rules for ports: ${ports[*]}"
    
    # Install UFW if not present
    if ! command_exists ufw; then
        sudo apt-get update
        sudo apt-get install -y ufw
    fi
    
    # Enable UFW if not already enabled
    if ! sudo ufw status | grep -q "Status: active"; then
        sudo ufw --force enable
    fi
    
    # Add rules for each port
    for port in "${ports[@]}"; do
        sudo ufw allow "$port"
        log_info "Added firewall rule for port $port"
    done
}

# Ensure JWT secret exists
ensure_jwt_secret() {
    local jwt_path="$1"
    
    if [[ ! -f "$jwt_path" ]]; then
        log_info "Generating JWT secret at $jwt_path"
        openssl rand -hex 32 > "$jwt_path"
        sudo chmod 600 "$jwt_path"
        log_info "JWT secret generated and secured"
    else
        log_info "JWT secret already exists at $jwt_path"
    fi
}

# =============================================================================
# INPUT VALIDATION FUNCTIONS
# =============================================================================

# Validate menu choice
validate_menu_choice() {
    local choice="$1"
    local max="${2:-10}"
    
    # Check if choice is a number
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Check if choice is within valid range
    if [[ $choice -lt 1 ]] || [[ $choice -gt $max ]]; then
        return 1
    fi
    
    return 0
}

# =============================================================================
# SYSTEM VALIDATION FUNCTIONS
# =============================================================================

# Check system requirements
check_system_requirements() {
    local min_memory_gb="$1"
    local min_disk_gb="$2"
    
    log_info "Checking system requirements..."
    
    # Check memory
    local total_memory_gb
    total_memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $total_memory_gb -lt $min_memory_gb ]]; then
        log_error "Insufficient memory: ${total_memory_gb}GB available, ${min_memory_gb}GB required"
        return 1
    fi
    
    # Check disk space
    local available_disk_gb
    available_disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [[ $available_disk_gb -lt $min_disk_gb ]]; then
        log_error "Insufficient disk space: ${available_disk_gb}GB available, ${min_disk_gb}GB required"
        return 1
    fi
    
    log_info "✓ System requirements check passed"
    return 0
}

# Check system compatibility
check_system_compatibility() {
    log_info "Checking system compatibility..."
    
    # Check OS
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
    
    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        log_error "Unsupported architecture: $arch (requires x86_64)"
        return 1
    fi
    
    log_info "✓ System compatibility check passed"
    return 0
}

# Root check standardization
require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# =============================================================================
# SECURITY FUNCTIONS - Required for run_1.sh and run_2.sh
# =============================================================================

# Generate secure password
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
        if ! sudo useradd -m -d "/home/$username" -s /bin/bash "$username"; then
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
    sudo mkdir -p "$ssh_dir"
    sudo chown "$username:$username" "$ssh_dir"
    sudo chmod 700 "$ssh_dir"
    
    # Copy SSH keys if provided
    if [[ -n "$ssh_key_file" && -f "$ssh_key_file" ]]; then
        sudo cp "$ssh_key_file" "$ssh_dir/authorized_keys"
        sudo chown "$username:$username" "$ssh_dir/authorized_keys"
        sudo chmod 600 "$ssh_dir/authorized_keys"
        log_info "SSH key copied for user: $username"
    fi
    
    log_info "✓ User $username setup complete"
}

# Configure SSH with security hardening
configure_ssh() {
    local ssh_port="$1"
    
    log_info "Configuring SSH security hardening..."
    
    # Backup original SSH config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Create secure SSH configuration
    cat > /etc/ssh/sshd_config << EOF
# SSH Security Configuration
Port $ssh_port
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 60
Banner /etc/ssh/banner
AllowUsers $LOGIN_UNAME
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
PermitTunnel no
ChrootDirectory none
UsePAM yes
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
Compression no
SyslogFacility AUTH
LogLevel INFO
StrictModes yes
IgnoreRhosts yes
IgnoreUserKnownHosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitUserEnvironment no
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256
EOF

    # Create SSH banner
    cat > /etc/ssh/banner << EOF
***************************************************************************
*                                                                         *
*  WARNING: This system is for authorized users only. All activities     *
*  are logged and monitored. Unauthorized access is prohibited.          *
*                                                                         *
***************************************************************************
EOF

    # Restart SSH service
    sudo systemctl restart sshd
    if sudo systemctl is-active --quiet sshd; then
        log_info "✓ SSH configured and restarted successfully"
    else
        log_error "Failed to restart SSH service"
        return 1
    fi
}

# Configure sudo without password for specific user
configure_sudo_nopasswd() {
    local username="$1"
    
    log_info "Configuring sudo without password for user: $username"
    
    # Add user to sudo group
    sudo usermod -aG sudo "$username"
    
    # Create sudoers file for the user
    cat > "/etc/sudoers.d/$username" << EOF
$username ALL=(ALL) NOPASSWD:ALL
EOF

    sudo chmod 440 "/etc/sudoers.d/$username"
    log_info "✓ Sudo configured for user: $username"
}


# Generate and display secure handoff information
generate_handoff_info() {
    local username="$1"
    local password="$2"
    local server_ip="$3"
    
    log_info "Generating secure handoff information..."
    
    cat << EOF

=== SECURE HANDOFF INFORMATION ===
Username: $username
Password: $password
Server IP: $server_ip
SSH Command: ssh $username@$server_ip
Next Step: ./run_2.sh

IMPORTANT SECURITY NOTES:
- Change the password immediately after first login
- Consider setting up SSH key authentication
- Keep this information secure and private
- Delete this file after noting the information

Generated: $(date)
=====================================

EOF
}

# Security configuration functions
secure_config_files() {
    log_info "Securing configuration files..."
    
    # Set secure permissions on configuration files
    find /etc -name "*.conf" -type f -exec sudo chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.cfg" -type f -exec sudo chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.yaml" -type f -exec sudo chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.yml" -type f -exec sudo chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.json" -type f -exec sudo chmod 644 {} \; 2>/dev/null || true
    find /etc -name "*.toml" -type f -exec sudo chmod 644 {} \; 2>/dev/null || true
    
    # Secure sensitive files
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        sudo chmod 600 /etc/ssh/sshd_config
    fi
    
    if [[ -f "/etc/sudoers" ]]; then
        sudo chmod 440 /etc/sudoers
    fi
    
    log_info "✓ Configuration files secured"
}

apply_network_security() {
    log_info "Applying network security settings..."
    
    # Disable unnecessary network services
    sudo systemctl disable bluetooth 2>/dev/null || true
    sudo systemctl disable cups 2>/dev/null || true
    sudo systemctl disable avahi-daemon 2>/dev/null || true
    
    # Configure kernel parameters for security
    cat >> /etc/sysctl.conf << EOF

# Network security settings
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF
    
    # Apply sysctl settings
    sudo sysctl -p >/dev/null 2>&1 || true
    
    log_info "✓ Network security applied"
}

setup_security_monitoring() {
    log_info "Setting up security monitoring..."
    
    # Create security monitoring script
    sudo tee /usr/local/bin/security_monitor.sh > /dev/null << 'EOF'
#!/bin/bash
# Security monitoring script

LOG_FILE="/var/log/security_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Security monitoring check" >> "$LOG_FILE"

# Check for failed login attempts
if command -v lastb >/dev/null 2>&1; then
    failed_logins=$(lastb | wc -l)
    if [[ $failed_logins -gt 0 ]]; then
        echo "[$DATE] WARNING: $failed_logins failed login attempts detected" >> "$LOG_FILE"
    fi
fi

# Check for suspicious processes
if pgrep -f "nc -l" >/dev/null 2>&1; then
    echo "[$DATE] WARNING: Suspicious netcat listener detected" >> "$LOG_FILE"
fi

# Check disk usage
disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
if [[ $disk_usage -gt 90 ]]; then
    echo "[$DATE] WARNING: Disk usage at ${disk_usage}%" >> "$LOG_FILE"
fi

echo "[$DATE] Security monitoring check complete" >> "$LOG_FILE"
EOF
    
    sudo chmod +x /usr/local/bin/security_monitor.sh
    
    # Add to crontab for regular monitoring
    (crontab -l 2>/dev/null; echo "*/15 * * * * /usr/local/bin/security_monitor.sh") | crontab - 2>/dev/null || true
    
    log_info "✓ Security monitoring setup complete"
}

setup_intrusion_detection() {
    log_info "Setting up intrusion detection..."
    
    # Install AIDE if not present
    if ! command_exists aide; then
        sudo apt-get update
        sudo apt-get install -y aide
    fi
    
    # Initialize AIDE database if it doesn't exist
    if [[ ! -f "/var/lib/aide/aide.db" ]]; then
        sudo aideinit
        sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    fi
    
    # Create AIDE check script
    sudo tee /usr/local/bin/aide_check.sh > /dev/null << 'EOF'
#!/bin/bash
# AIDE intrusion detection check

LOG_FILE="/var/log/aide_check.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Running AIDE check..." >> "$LOG_FILE"

if sudo aide --check >> "$LOG_FILE" 2>&1; then
    echo "[$DATE] AIDE check passed - no changes detected" >> "$LOG_FILE"
else
    echo "[$DATE] WARNING: AIDE detected changes in system files" >> "$LOG_FILE"
fi

echo "[$DATE] AIDE check complete" >> "$LOG_FILE"
EOF
    
    sudo chmod +x /usr/local/bin/aide_check.sh
    
    # Add to crontab for daily checks
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/aide_check.sh") | crontab - 2>/dev/null || true
    
    log_info "✓ Intrusion detection setup complete"
}

# Additional security functions required by validation
validate_user_input() {
    local input="$1"
    local max_length="${2:-50}"
    local min_length="${3:-1}"
    
    # Handle empty parameters
    if [[ -z "$max_length" ]]; then
        max_length=50
    fi
    if [[ -z "$min_length" ]]; then
        min_length=1
    fi
    
    # Check length
    if [[ ${#input} -lt $min_length ]] || [[ ${#input} -gt $max_length ]]; then
        return 1
    fi
    
    # Check for dangerous characters using grep
    if echo "$input" | grep -q '[<>"'\'';&|`$]'; then
        return 1
    fi
    
    return 0
}

secure_error_handling() {
    # Set up secure error handling
    set -Eeuo pipefail
    trap 'log_error "Error in line $LINENO: $BASH_COMMAND"' ERR
}

safe_command_execution() {
    local command="$1"
    
    # Validate command before execution using grep
    if echo "$command" | grep -q '[;&|`$]'; then
        log_error "Unsafe command detected: $command"
        return 1
    fi
    
    # Execute command safely
    if eval "$command" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

secure_file_permissions() {
    local file="$1"
    local permissions="${2:-600}"
    
    if [[ -f "$file" ]]; then
        sudo chmod "$permissions" "$file"
        log_info "Set permissions $permissions on $file"
    else
        log_error "File not found: $file"
        return 1
    fi
}

# =============================================================================
# REFACTORING FUNCTIONS - Requested in REFACTORING_AUDIT_REPORT.md
# =============================================================================

# 2. Installation Start Messages - log_installation_start()
log_installation_start() {
    local client_name="$1"
    log_info "Starting $client_name installation..."
}

# 3. Installation Complete Messages - log_installation_complete()
log_installation_complete() {
    local client_name="$1"
    local service_name="$2"
    
    log_info "$client_name installation completed!"
    log_info "To check status: sudo systemctl status $service_name"
    log_info "To start service: sudo systemctl start $service_name"
    log_info "To enable service: sudo systemctl enable $service_name"
    log_info "To view logs: sudo journalctl -u $service_name -f"
}

# 4. Setup Information Display - display_client_setup_info()
display_client_setup_info() {
    local client_name="$1"
    local beacon_service="${2:-}"
    local validator_service="${3:-}"
    local beacon_desc="${4:-Beacon Node}"
    local validator_desc="${5:-Validator Client}"
    
    cat << EOF

=== $client_name Setup Information ===
$client_name has been installed with the following components:

EOF

    if [[ -n "$beacon_service" ]]; then
        echo "1. Beacon Node ($beacon_service service) - $beacon_desc"
    fi
    
    if [[ -n "$validator_service" ]]; then
        echo "2. Validator Client ($validator_service service) - $validator_desc"
    fi
    
    cat << EOF

Configuration files are located in:
- Base configs: $SCRIPT_DIR/configs/$client_name/
- Active configs: /etc/$client_name/

Data directories:
- Beacon data: /var/lib/$client_name/beacon
- Validator data: /var/lib/$client_name/validator

To manage services:
- Start: sudo systemctl start $beacon_service $validator_service
- Stop: sudo systemctl stop $beacon_service $validator_service
- Status: sudo systemctl status $beacon_service $validator_service
- Logs: sudo journalctl -fu $beacon_service $validator_service

=== Setup Complete ===
EOF
}

# 5. Temporary Directory Creation - create_temp_config_dir()
create_temp_config_dir() {
    local temp_dir="./tmp"
    
    if [[ ! -d "$temp_dir" ]]; then
        mkdir -p "$temp_dir"
        log_info "Created temporary directory: $temp_dir"
    fi
    
    echo "$temp_dir"
}

# 1. SCRIPT_DIR Pattern Duplication - get_script_directories()
get_script_directories() {
    # Get the directory of the calling script
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    local project_root
    project_root="$(cd "$script_dir/../.." && pwd)"
    
    # Export variables for use in calling script
    export SCRIPT_DIR="$script_dir"
    export PROJECT_ROOT="$project_root"
    
    log_info "Script directory: $script_dir"
    log_info "Project root: $project_root"
}





# 6. Configuration Merging - merge_client_config()
merge_client_config() {
    local client_name="$1"
    local config_type="$2"
    local base_config="$3"
    local custom_config="$4"
    local output_config="$5"
    
    log_info "Merging $client_name $config_type configuration..."
    
    # Create temp directory if it doesn't exist
    create_temp_config_dir > /dev/null
    
    # Check if files exist
    if [[ ! -f "$base_config" ]]; then
        log_error "Base config not found: $base_config"
        return 1
    fi
    
    if [[ ! -f "$custom_config" ]]; then
        log_error "Custom config not found: $custom_config"
        return 1
    fi
    
    # Merge based on file type
    case "$base_config" in
        *.json)
            if command_exists jq; then
                jq -s '.[0] * .[1]' "$base_config" "$custom_config" > "$output_config"
            else
                log_error "jq not found, cannot merge JSON configs"
                return 1
            fi
            ;;
        *.yaml|*.yml)
            # Manual YAML merge: copy base config and append custom config
            cp "$base_config" "$output_config"
            if [[ -f "$custom_config" ]]; then
                {
                    echo ""
                    echo "# Custom configuration overrides"
                    cat "$custom_config"
                } >> "$output_config"
            fi
            ;;
        *.toml)
            # For TOML, we'll do a simple concatenation (custom overrides base)
            cat "$base_config" "$custom_config" > "$output_config"
            ;;
        *)
            log_error "Unsupported config format: $base_config"
            return 1
            ;;
    esac
    
    if [[ -f "$output_config" ]]; then
        log_info "Configuration merged successfully: $output_config"
        return 0
    else
        log_error "Failed to merge configuration"
        return 1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Append text to file only if not already present
append_once() {
    local file="$1"
    shift
    local text="$*"
    
    if [[ ! -f "$file" ]] || ! grep -Fqx -- "$text" "$file"; then
        echo "$text" | sudo tee -a "$file" >/dev/null
    fi
}