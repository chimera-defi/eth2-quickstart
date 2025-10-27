# Common Functions Reference Guide

**File:** `lib/common_functions.sh`  
**Purpose:** Centralized library of reusable shell functions  
**Status:** ✅ **COMPLETE** - All 35 functions implemented and tested

## Overview

This document provides a comprehensive reference for all functions available in the common functions library. These functions eliminate code duplication and provide consistent behavior across all installation scripts.

## Function Categories

### 🔍 **Logging Functions**

#### `log_info(message)`
**Purpose:** Display informational messages with consistent formatting  
**Parameters:** `message` - The message to display  
**Usage:** `log_info "Starting installation process"`  
**Output:** `[INFO] Starting installation process`

#### `log_warn(message)`
**Purpose:** Display warning messages with consistent formatting  
**Parameters:** `message` - The warning message to display  
**Usage:** `log_warn "This operation requires root privileges"`  
**Output:** `[WARN] This operation requires root privileges`

#### `log_error(message)`
**Purpose:** Display error messages with consistent formatting  
**Parameters:** `message` - The error message to display  
**Usage:** `log_error "Installation failed"`  
**Output:** `[ERROR] Installation failed`

### 🚀 **Installation Functions**

#### `log_installation_start(client_name)`
**Purpose:** Log the start of client installation  
**Parameters:** `client_name` - Name of the client being installed  
**Usage:** `log_installation_start "Prysm"`  
**Output:** `[INFO] Starting Prysm installation...`

#### `log_installation_complete(client_name, service_name)`
**Purpose:** Log successful installation completion with service information  
**Parameters:** 
- `client_name` - Name of the installed client
- `service_name` - Name of the systemd service
**Usage:** `log_installation_complete "Prysm" "prysm-beacon"`  
**Output:** Installation completion message with service management instructions

#### `display_client_setup_info(client_name, beacon_service, validator_service, beacon_desc, validator_desc)`
**Purpose:** Display comprehensive setup information for consensus clients  
**Parameters:**
- `client_name` - Name of the client
- `beacon_service` - Beacon node service name
- `validator_service` - Validator service name
- `beacon_desc` - Description of beacon node
- `validator_desc` - Description of validator client
**Usage:** `display_client_setup_info "Prysm" "prysm-beacon" "prysm-validator" "Beacon Node" "Validator Client"`

### 📁 **Directory Management Functions**

#### `get_script_directories()`
**Purpose:** Set SCRIPT_DIR and PROJECT_ROOT variables based on script location  
**Parameters:** None  
**Usage:** `get_script_directories`  
**Sets:** `$SCRIPT_DIR` and `$PROJECT_ROOT` variables

#### `ensure_directory(path)`
**Purpose:** Create directory if it doesn't exist  
**Parameters:** `path` - Directory path to create  
**Usage:** `ensure_directory "/etc/ethereum"`  
**Output:** Creates directory and logs action

#### `create_temp_config_dir()`
**Purpose:** Create temporary directory for configuration files  
**Parameters:** None  
**Usage:** `create_temp_config_dir`  
**Returns:** Path to temporary directory

### ⚙️ **Configuration Functions**

#### `merge_client_config(client_name, config_type, base_config, custom_config, output_config)`
**Purpose:** Merge base and custom configuration files  
**Parameters:**
- `client_name` - Name of the client
- `config_type` - Type of configuration (e.g., "beacon", "validator")
- `base_config` - Path to base configuration file
- `custom_config` - Path to custom configuration file
- `output_config` - Path to output merged configuration
**Usage:** `merge_client_config "Prysm" "beacon" "/configs/base.yaml" "/configs/custom.yaml" "/etc/prysm/config.yaml"`  
**Supports:** JSON, YAML, and TOML formats

### 🔒 **Security Functions**

#### `setup_secure_user(username, home_dir)`
**Purpose:** Create secure user account with proper permissions  
**Parameters:**
- `username` - Username to create
- `home_dir` - Home directory path
**Usage:** `setup_secure_user "ethereum" "/home/ethereum"`

#### `configure_ssh(port, disable_password_auth, disable_root_login)`
**Purpose:** Configure SSH security settings  
**Parameters:**
- `port` - SSH port number
- `disable_password_auth` - Disable password authentication (true/false)
- `disable_root_login` - Disable root login (true/false)
**Usage:** `configure_ssh 2222 true true`

#### `setup_fail2ban(ssh_port)`
**Purpose:** Install and configure fail2ban for SSH protection  
**Parameters:** `ssh_port` - SSH port number  
**Usage:** `setup_fail2ban 2222`

#### `generate_secure_password(length)`
**Purpose:** Generate secure random password  
**Parameters:** `length` - Password length (default: 32)  
**Usage:** `generate_secure_password 24`  
**Returns:** Secure random password

### 🖥️ **System Service Functions**

#### `create_systemd_service(service_name, description, exec_start, user, working_directory)`
**Purpose:** Create systemd service file  
**Parameters:**
- `service_name` - Name of the service
- `description` - Service description
- `exec_start` - Command to execute
- `user` - User to run service as
- `working_directory` - Working directory
**Usage:** `create_systemd_service "prysm-beacon" "Prysm Beacon Node" "/usr/local/bin/prysm" "ethereum" "/home/ethereum"`

#### `enable_and_start_systemd_service(service_name)`
**Purpose:** Enable and start systemd service  
**Parameters:** `service_name` - Name of the service  
**Usage:** `enable_and_start_systemd_service "prysm-beacon"`

#### `enable_and_start_system_service(service_name)`
**Purpose:** Alias for enable_and_start_systemd_service  
**Parameters:** `service_name` - Name of the service  
**Usage:** `enable_and_start_system_service "prysm-beacon"`

#### `enable_systemd_service(service_name)`
**Purpose:** Enable systemd service without starting  
**Parameters:** `service_name` - Name of the service  
**Usage:** `enable_systemd_service "prysm-beacon"`

### 📥 **File Operations Functions**

#### `download_file(url, output, max_retries)`
**Purpose:** Download file with retry logic and security validation  
**Parameters:**
- `url` - URL to download from
- `output` - Output file path
- `max_retries` - Maximum retry attempts (default: 3)
**Usage:** `download_file "https://example.com/file.tar.gz" "/tmp/file.tar.gz" 5`

#### `secure_download(url, output, max_retries)`
**Purpose:** Secure file download with validation  
**Parameters:**
- `url` - URL to download from
- `output` - Output file path
- `max_retries` - Maximum retry attempts
**Usage:** `secure_download "https://example.com/file.tar.gz" "/tmp/file.tar.gz" 3`

### 🔍 **System Check Functions**

#### `check_system_requirements()`
**Purpose:** Check if system meets minimum requirements  
**Parameters:** None  
**Usage:** `check_system_requirements`  
**Checks:** CPU, RAM, disk space, OS version

#### `check_system_compatibility()`
**Purpose:** Check system compatibility for Ethereum node  
**Parameters:** None  
**Usage:** `check_system_compatibility`  
**Checks:** Architecture, OS compatibility, required tools

#### `check_user(username)`
**Purpose:** Check if user exists and has proper permissions  
**Parameters:** `username` - Username to check  
**Usage:** `check_user "ethereum"`

#### `command_exists(command)`
**Purpose:** Check if command exists in PATH  
**Parameters:** `command` - Command to check  
**Usage:** `command_exists "jq"`  
**Returns:** 0 if exists, 1 if not

### 🔧 **System Configuration Functions**

#### `install_dependencies()`
**Purpose:** Install required system dependencies  
**Parameters:** None  
**Usage:** `install_dependencies`  
**Installs:** curl, wget, jq, systemd, ufw, fail2ban

#### `setup_firewall_rules(ssh_port, rpc_port, p2p_port)`
**Purpose:** Configure firewall rules  
**Parameters:**
- `ssh_port` - SSH port number
- `rpc_port` - RPC port number
- `p2p_port` - P2P port number
**Usage:** `setup_firewall_rules 2222 8545 30303`

#### `add_ppa_repository(ppa)`
**Purpose:** Add PPA repository  
**Parameters:** `ppa` - PPA repository string  
**Usage:** `add_ppa_repository "ppa:ethereum/ethereum"`

#### `configure_sudo_nopasswd(username)`
**Purpose:** Configure sudo without password for user  
**Parameters:** `username` - Username to configure  
**Usage:** `configure_sudo_nopasswd "ethereum"`

### 🔐 **Security Monitoring Functions**

#### `setup_security_monitoring()`
**Purpose:** Set up security monitoring and logging  
**Parameters:** None  
**Usage:** `setup_security_monitoring`

#### `setup_intrusion_detection()`
**Purpose:** Set up intrusion detection system  
**Parameters:** None  
**Usage:** `setup_intrusion_detection`

#### `apply_network_security()`
**Purpose:** Apply network security configurations  
**Parameters:** None  
**Usage:** `apply_network_security`

#### `secure_config_files(path)`
**Purpose:** Secure configuration files with proper permissions  
**Parameters:** `path` - Path to configuration files  
**Usage:** `secure_config_files "/etc/ethereum"`

### 🔑 **Authentication Functions**

#### `ensure_jwt_secret(path)`
**Purpose:** Ensure JWT secret file exists and is secure  
**Parameters:** `path` - Path to JWT secret file  
**Usage:** `ensure_jwt_secret "/etc/ethereum/jwt.hex"`

#### `generate_handoff_info()`
**Purpose:** Generate handoff information for client setup  
**Parameters:** None  
**Usage:** `generate_handoff_info`

### 🛡️ **Privilege Functions**

#### `require_root()`
**Purpose:** Check if script is running as root  
**Parameters:** None  
**Usage:** `require_root`  
**Exits:** Script if not running as root

## Usage Examples

### Basic Installation Script Pattern
```bash
#!/bin/bash
set -Eeuo pipefail

# Source required files
source ./exports.sh
source ./lib/common_functions.sh

# Check if running as root
require_root

# Get script directories
get_script_directories

# Log installation start
log_installation_start "ClientName"

# Check system requirements
check_system_requirements

# Install dependencies
install_dependencies

# Create secure user
setup_secure_user "ethereum" "/home/ethereum"

# Download and install client
download_file "https://example.com/client.tar.gz" "/tmp/client.tar.gz"

# Create systemd service
create_systemd_service "client-service" "Client Service" "/usr/local/bin/client" "ethereum" "/home/ethereum"

# Enable and start service
enable_and_start_systemd_service "client-service"

# Log installation complete
log_installation_complete "ClientName" "client-service"
```

### Configuration Merging Example
```bash
# Merge JSON configurations
merge_client_config "Prysm" "beacon" "/configs/prysm_base.json" "/configs/prysm_custom.json" "/etc/prysm/config.json"

# Merge YAML configurations
merge_client_config "Lodestar" "validator" "/configs/lodestar_base.yaml" "/configs/lodestar_custom.yaml" "/etc/lodestar/config.yaml"

# Merge TOML configurations
merge_client_config "Nimbus" "beacon" "/configs/nimbus_base.toml" "/configs/nimbus_custom.toml" "/etc/nimbus/config.toml"
```

## Best Practices

1. **Always source common functions**: `source ./lib/common_functions.sh`
2. **Use consistent logging**: Use `log_info`, `log_warn`, `log_error` for all messages
3. **Check system requirements**: Call `check_system_requirements` early
4. **Use centralized configuration**: Use `merge_client_config` for all config merging
5. **Follow security practices**: Use security functions for user setup and SSH configuration
6. **Test functions**: Always test new functions before committing
7. **Maintain consistency**: Use the same patterns across all scripts

## Dependencies

The common functions library requires:
- `jq` - For JSON processing
- `curl` - For file downloads
- `wget` - For file downloads
- `systemd` - For service management
- `ufw` - For firewall management
- `fail2ban` - For intrusion detection

## Error Handling

All functions include proper error handling:
- Functions exit on critical errors
- Non-critical errors are logged as warnings
- Return codes indicate success/failure
- Detailed error messages are provided

## Testing

All functions have been tested with:
- Shellcheck compliance
- Multiple pass review process
- Integration testing with install scripts
- Error condition testing
- Edge case validation

---

**Last Updated:** December 2024  
**Status:** ✅ **COMPLETE** - All functions implemented and tested
