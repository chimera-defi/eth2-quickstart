# Standalone Server Hardening

This document describes the standalone server hardening capability that allows you to harden existing servers without going through the full Phase 1 setup process.

## Overview

The standalone hardening script (`install/security/harden_server.sh`) provides a modular, non-destructive way to apply security hardening to existing servers. This is particularly useful for:

- Hardening servers that already have users configured
- Applying security updates without changing SSH ports or hostnames
- Running hardening on servers with custom configurations
- Automated security hardening in CI/CD pipelines

## Key Features

- **Independent Execution**: Runs without requiring Phase 1 setup
- **Non-Destructive**: Optional SSH port preservation to prevent lockout
- **Modular Components**: Enable/disable specific hardening modules
- **Safety Features**: Dry-run mode, configuration validation, and backups
- **Idempotent**: Safe to run multiple times without side effects

## Usage

### Basic Usage

```bash
# Interactive mode with all hardening components
sudo ./install/security/harden_server.sh

# Non-interactive mode (automated)
sudo ./install/security/harden_server.sh --non-interactive
```

### Common Scenarios

#### Harden Existing Server Without Changing SSH Port

```bash
sudo ./install/security/harden_server.sh --preserve-port --non-interactive
```

This is the **recommended** approach for existing servers to prevent lockout.

#### Preview Changes Without Applying

```bash
sudo ./install/security/harden_server.sh --dry-run
```

#### Skip Specific Components

```bash
# Skip SSH hardening entirely
sudo ./install/security/harden_server.sh --skip-ssh --preserve-port

# Skip firewall hardening
sudo ./install/security/harden_server.sh --skip-firewall --preserve-port

# Skip multiple components
sudo ./install/security/harden_server.sh --skip-ssh --skip-snort --preserve-port
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without applying them |
| `--preserve-port` | Keep current SSH port (don't change it) |
| `--skip-ssh` | Skip SSH hardening |
| `--skip-firewall` | Skip firewall hardening |
| `--skip-fail2ban` | Skip fail2ban hardening |
| `--skip-snort` | Skip Snort IDS installation |
| `--skip-aide` | Skip AIDE file integrity monitoring |
| `--skip-network` | Skip network security hardening |
| `--skip-monitoring` | Skip security monitoring setup |
| `--non-interactive` | Run without confirmation prompts |
| `--help, -h` | Show help message |

## Configuration

The hardening behavior can be configured via:

1. **Environment Variables**: Set before running the script
2. **Configuration File**: `install/security/harden_config.env`

### Environment Variables

```bash
# SSH Configuration
export HARDEN_SSH=true              # Enable/disable SSH hardening
export PRESERVE_SSH_PORT=false      # Keep current SSH port
export SSH_PORT=22                  # Target SSH port

# Firewall Configuration
export HARDEN_FIREWALL=true         # Enable firewall hardening
export FIREWALL_CHAIN=ethereum      # Chain: ethereum | monad

# Fail2ban Configuration
export HARDEN_FAIL2BAN=true         # Enable fail2ban
export FAIL2BAN_MAXRETRY=3          # Max failed login attempts

# Snort IDS Configuration
export HARDEN_SNORT=true            # Enable Snort IDS
export SNORT_INTERFACE=auto         # Network interface
export SNORT_STARTUP=boot           # Startup mode: boot | manual

# AIDE Configuration
export HARDEN_AIDE=true             # Enable AIDE monitoring

# Network Security Configuration
export HARDEN_NETWORK=true          # Enable network security
export DISABLE_SERVICES=true        # Disable unnecessary services

# Safety Options
export DRY_RUN=false                # Preview mode
export INTERACTIVE=true             # Interactive prompts
export BACKUP_CONFIGS=true          # Backup configs before changes
```

## Integration with run_1.sh

The standalone hardening can also be invoked via `run_1.sh` for integration with the existing Phase 1 workflow:

```bash
# Standard Phase 1 setup with modular hardening
sudo ./run_1.sh --use-modular-hardening --preserve-ssh-port

# Harden existing server without user creation
sudo ./run_1.sh --use-modular-hardening --skip-user-creation --preserve-ssh-port
```

### run_1.sh Options

| Option | Description |
|--------|-------------|
| `--use-modular-hardening` | Use the standalone modular hardening script |
| `--preserve-ssh-port` | Keep current SSH port (for use with modular hardening) |
| `--skip-user-creation` | Skip user creation (for hardening existing servers) |

## Hardening Components

### SSH Hardening
- Deploys hardened SSH configuration
- Sets SSH banner
- Configures secure SSH settings
- **Optional**: Port change (can be preserved)

### Firewall Hardening
- Configures UFW with security rules
- Opens necessary ports for Ethereum/Monad clients
- Blocks problematic ports and outbound to private networks
- Chain-specific port configuration

### Fail2ban Hardening
- Configures fail2ban for SSH intrusion prevention
- Sets ban time and retry limits
- Monitors authentication logs

### Snort IDS
- Installs and configures Snort intrusion detection
- Configures network interface and home network
- Optional promiscuous mode disable
- Boot or manual startup modes

### AIDE File Integrity Monitoring
- Installs AIDE package
- Initializes integrity database
- Schedules daily integrity checks
- Configures alerting

### Network Security Hardening
- Restricts shared memory via fstab
- Disables unnecessary services (bluetooth, cups, avahi-daemon)
- Configures kernel security parameters via sysctl
- Applies network hardening settings

### Security Monitoring
- Creates security monitoring script
- Sets up periodic cron jobs
- Configures log rotation
- Monitors failed logins, suspicious processes, and disk usage

## Safety Features

### Backup Before Changes
All configuration files are backed up before modification:
```bash
/root/backups/hardening_YYYYMMDD_HHMMSS/
```

### Dry-Run Mode
Preview all changes without applying them:
```bash
sudo ./install/security/harden_server.sh --dry-run
```

### Configuration Validation
All configurations are validated after application:
- SSH configuration validation (`sshd -t`)
- Service status checks
- Configuration file syntax checks

### Rollback Capability
Backups can be used to restore previous configurations if needed.

## Troubleshooting

### SSH Lockout Prevention
Always use `--preserve-port` when hardening existing servers:
```bash
sudo ./install/security/harden_server.sh --preserve-port --non-interactive
```

### Check Applied Hardening
```bash
# Check UFW status
sudo ufw status verbose

# Check fail2ban status
sudo systemctl status fail2ban

# Check AIDE status
sudo aide --config=/etc/aide/aide.conf --check

# Check security monitoring log
sudo tail -f /var/log/security_monitor.log
```

### Restore from Backup
If something goes wrong, restore from backup:
```bash
# Find backup directory
ls -la /root/backups/

# Restore specific configuration
sudo cp /root/backups/hardening_YYYYMMDD_HHMMSS/sshd_config.backup /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## Examples

### Example 1: Harden New Server with Full Setup
```bash
# Standard Phase 1 setup
sudo ./run_1.sh
sudo reboot
```

### Example 2: Harden Existing Server (Recommended)
```bash
# Preserve SSH port to prevent lockout
sudo ./install/security/harden_server.sh --preserve-port --non-interactive
```

### Example 3: Harden Specific Components Only
```bash
# Only apply firewall and fail2ban
sudo ./install/security/harden_server.sh \
  --skip-ssh \
  --skip-snort \
  --skip-aide \
  --skip-network \
  --skip-monitoring \
  --preserve-port \
  --non-interactive
```

### Example 4: Preview Before Applying
```bash
# See what would be changed
sudo ./install/security/harden_server.sh --dry-run --preserve-port

# If satisfied, apply for real
sudo ./install/security/harden_server.sh --preserve-port --non-interactive
```

### Example 5: Integration with Existing Workflow
```bash
# Use modular hardening within Phase 1
sudo ./run_1.sh --use-modular-hardening --preserve-ssh-port
sudo reboot
```

## Comparison: Standalone vs Phase 1

| Feature | Standalone Hardening | Phase 1 (run_1.sh) |
|---------|---------------------|-------------------|
| User Creation | No | Yes |
| SSH Port Change | Optional | Yes (configured) |
| Hostname Change | No | No |
| System Updates | No | Yes |
| Dependency Installation | Partial | Full |
| Reboot Required | No | Yes |
| Handoff Info | No | Yes |
| Use Case | Existing servers | New servers |

## Security Considerations

- **Always test in a non-production environment first**
- **Use `--preserve-port` for existing servers to prevent lockout**
- **Review backup locations before running**
- **Ensure you have console access to the server**
- **Test SSH access after port changes before disconnecting**
- **Monitor security logs after hardening**

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs in `/var/log/security_monitor.log`
3. Check AIDE logs in `/var/log/aide_check.log`
4. Review service logs: `sudo journalctl -u <service> -f`

## See Also

- [Main Documentation](README.md)
- [Workflow Documentation](WORKFLOW.md)
- [Security Documentation](docs/verify_security.sh)
- [Configuration Guide](docs/CONFIGURATION_GUIDE.md)