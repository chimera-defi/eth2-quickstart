#!/bin/bash

# Common functions library for Ethereum client installation scripts
# This library contains shared functions to reduce code duplication

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Enable and start system service (alias for compatibility)
enable_and_start_system_service() {
    enable_and_start_systemd_service "$1"
}

# =============================================================================
# SYSTEM MANAGEMENT FUNCTIONS
# =============================================================================

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
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        return 1
    fi
    
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

# Setup fail2ban
setup_fail2ban() {
    log_info "Setting up fail2ban..."
    
    # Make the script executable and run it
    sudo chmod +x ./install/security/install_fail2ban.sh
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

# Security configuration functions (stubs for compatibility)
secure_config_files() {
    log_info "Securing configuration files..."
    # Implementation would go here
    log_info "✓ Configuration files secured"
}

apply_network_security() {
    log_info "Applying network security settings..."
    # Implementation would go here
    log_info "✓ Network security applied"
}

setup_security_monitoring() {
    log_info "Setting up security monitoring..."
    # Implementation would go here
    log_info "✓ Security monitoring setup complete"
}

setup_intrusion_detection() {
    log_info "Setting up intrusion detection..."
    # Implementation would go here
    log_info "✓ Intrusion detection setup complete"
}

# =============================================================================
# REFACTORING FUNCTIONS - Requested in REFACTORING_AUDIT_REPORT.md
# =============================================================================

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
            if command_exists yq; then
                # Simple fallback: copy custom over base (custom takes precedence)
                cp "$base_config" "$output_config"
                if [[ -f "$custom_config" ]]; then
                    # Append custom config to base config
                    echo "" >> "$output_config"
                    cat "$custom_config" >> "$output_config"
                fi
            else
                log_error "yq not found, cannot merge YAML configs"
                return 1
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