# Ethereum Data Purge Script

## Overview

The `purge_ethereum_data.sh` script provides a comprehensive solution for safely removing all Ethereum client data directories and files. This allows you to cleanly switch between different client configurations on the same server without conflicts or leftover data.

## Features

- **Complete Data Cleanup**: Removes all execution and consensus client data directories
- **Safety First**: Multiple safety measures including confirmation prompts and dry-run mode
- **Backup Support**: Optional backup creation before purging
- **Service Management**: Automatically stops and disables systemd services
- **Comprehensive Coverage**: Supports all major Ethereum clients

## Supported Clients

### Execution Clients
- **Geth**: `~/.ethereum`
- **Nethermind**: `~/.local/share/nethermind`
- **Besu**: `~/.local/share/besu`
- **Erigon**: `~/.local/share/erigon`
- **Reth**: `~/.local/share/reth`

### Consensus Clients
- **Prysm**: `~/.local/share/prysm` + `~/prysm`
- **Lighthouse**: `~/.lighthouse` + `~/lighthouse`
- **Teku**: `~/.local/share/teku` + `~/teku`
- **Nimbus**: `~/.local/share/nimbus` + `~/nimbus`
- **Lodestar**: `~/.local/share/lodestar` + `~/lodestar`
- **Grandine**: `~/.local/share/grandine` + `~/grandine`

### Additional Cleanup
- **MEV-Boost**: `~/mev-boost`
- **Secrets**: `~/secrets` (JWT secrets, validator keys)
- **Backups**: `~/eth2-quickstart-backups`
- **Rust Toolchain**: `~/.cargo` (if only used for Ethereum)

## Usage

### Basic Usage

```bash
# Show help
./install/utils/purge_ethereum_data.sh --help

# Dry run to see what would be deleted
./install/utils/purge_ethereum_data.sh --dry-run

# Create backup and purge with confirmation
./install/utils/purge_ethereum_data.sh --backup

# Purge without backup (use with caution)
./install/utils/purge_ethereum_data.sh --confirm

# Full backup and purge
./install/utils/purge_ethereum_data.sh --backup --confirm
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--confirm` | Skip confirmation prompt (use with caution) |
| `--backup` | Create backup before purging (recommended) |
| `--dry-run` | Show what would be deleted without actually deleting |
| `--help`, `-h` | Show help message |
| `--version`, `-v` | Show version information |

## Workflow Examples

### Switching from Geth + Prysm to Nethermind + Lighthouse

```bash
# 1. Check current setup
./install/utils/stats.sh

# 2. Create backup and purge existing data
./install/utils/purge_ethereum_data.sh --backup --confirm

# 3. Install new execution client
./install/execution/install_nethermind.sh

# 4. Install new consensus client
./install/consensus/lighthouse.sh

# 5. Start new services
./install/utils/start.sh

# 6. Verify new setup
./install/utils/stats.sh
```

### Testing Different Client Combinations

```bash
# Test setup 1: Besu + Teku
./install/utils/purge_ethereum_data.sh --backup --confirm
./install/execution/install_besu.sh
./install/consensus/install_teku.sh
./install/utils/start.sh

# After testing, switch to setup 2: Reth + Nimbus
./install/utils/purge_ethereum_data.sh --backup --confirm
./install/execution/reth.sh
./install/consensus/install_nimbus.sh
./install/utils/start.sh
```

## Safety Features

### 1. Confirmation Prompts
- Interactive confirmation before deletion
- Clear warnings about data loss
- Option to cancel at any time

### 2. Dry Run Mode
- Preview what will be deleted
- Check directory sizes
- Verify cleanup scope

### 3. Backup Creation
- Timestamped backups in `~/ethereum-data-backups/`
- Preserves all client data and configurations
- Includes restoration instructions

### 4. Service Management
- Stops all Ethereum services before cleanup
- Disables systemd services
- Prevents data corruption

## What Gets Deleted

### Data Directories
- Blockchain data (can be re-synced)
- Client databases and indexes
- Log files and temporary data

### Configuration Files
- Client configuration files
- Service definitions
- Custom settings

### Sensitive Data
- **Validator keys and wallets** (ensure you have backups!)
- JWT secrets
- Keystore files

## What Gets Preserved

### System Files
- Operating system files
- Non-Ethereum applications
- User home directory structure

### Backups
- Previous backups in `~/ethereum-data-backups/`
- System backups
- Configuration backups

## Recovery

### From Backup
```bash
# List available backups
ls ~/ethereum-data-backups/

# Restore from specific backup
cp -r ~/ethereum-data-backups/ethereum_data_backup_YYYYMMDD_HHMMSS/* ~/

# Restart services
./install/utils/start.sh
```

### Fresh Installation
```bash
# After purging, install new clients
./install/execution/install_geth.sh
./install/consensus/install_prysm.sh
./install/utils/start.sh
```

## Troubleshooting

### Permission Issues
```bash
# Ensure script is executable
chmod +x install/utils/purge_ethereum_data.sh

# Run as correct user
sudo -u $LOGIN_UNAME ./install/utils/purge_ethereum_data.sh --dry-run
```

### Service Issues
```bash
# Check service status
systemctl status eth1 cl validator mev

# Manually stop services if needed
sudo systemctl stop eth1 cl validator mev

# Check for running processes
ps aux | grep -E "(geth|prysm|lighthouse|teku)"
```

### Disk Space Issues
```bash
# Check available space
df -h

# Check directory sizes
du -sh ~/.ethereum ~/.local/share/prysm ~/prysm

# Clean up logs if needed
sudo journalctl --vacuum-time=7d
```

## Best Practices

### Before Purging
1. **Backup Important Data**: Always create backups of validator keys and configurations
2. **Stop Services**: Ensure all Ethereum services are stopped
3. **Check Disk Space**: Ensure sufficient space for backups
4. **Document Configuration**: Note down important settings

### After Purging
1. **Verify Cleanup**: Check that all data directories are removed
2. **Install New Clients**: Use appropriate installation scripts
3. **Test Configuration**: Verify new setup works correctly
4. **Monitor Performance**: Check logs and metrics

### Regular Maintenance
1. **Clean Old Backups**: Remove outdated backups periodically
2. **Monitor Disk Usage**: Keep track of data directory sizes
3. **Update Clients**: Keep clients updated for best performance
4. **Test Recovery**: Periodically test backup restoration

## Security Considerations

### Backup Security
- Backups contain sensitive data (private keys, JWT secrets)
- Store backups securely with restricted access
- Consider encryption for long-term storage
- Delete backups when no longer needed

### Key Management
- Always backup validator keys before purging
- Store keys in multiple secure locations
- Use strong passwords for keystores
- Consider hardware security modules for production

## Support

For issues or questions:
1. Check the dry-run output for potential problems
2. Review logs for error messages
3. Ensure all prerequisites are met
4. Verify file permissions and ownership

## Version History

- **v1.0.0**: Initial release with support for all major Ethereum clients
- Comprehensive data directory mapping
- Safety features and backup support
- Service management integration