# Ethereum Node Quick Setup

Setup an Ethereum node quickly with simple shell scripts containing community best practices. 
Supports multiple client combinations for servers, home solo stakers, and pool node operators.

**⚠️ Security Notice:** Review scripts before execution.

## Prerequisites

1. **Server Setup**: Cloud VPS with SSH key or local server
   - **Recommended specs**: 2-4+ TB SSD/NVMe, 16-64+ GB RAM, 4-8+ cores, Ubuntu 20+
   - **Bare metal VPS preferred** (cloud instances may not finish syncing)
   - **SSH setup**: Configure SSH keys and server access

2. **System Configuration**:
   - Set swraid 1 & swraidlevel 0 for full disk access
   - Note: SSH fingerprint changes after setup - remove from known_hosts

## Quickstart

### Installation

1. **Download and prepare**:
   ```bash
   git clone https://github.com/chimera-defi/eth2-quickstart
   cd eth2-quickstart
   chmod +x run_1.sh
   ```

2. **Run server setup** (as root):
   ```bash
   ./run_1.sh
   ```
   - Upgrades Ubuntu and programs
   - Sets up firewalls and security hardening
   - Creates non-root user for safety
   - Installs required programs

3. **Reboot and configure**:
   ```bash
   sudo reboot
   # Login as new user (default: eth@ip)
   ```

4. **Configure and install clients**:
   - Edit `exports.sh` with your settings
   - Run `./select_clients.sh` for recommendations
   - Run `./run_2.sh` or install clients manually

5. **Start services**:
   ```bash
   sudo systemctl start eth1 cl validator mev
   sudo systemctl status eth1 cl validator mev
   ```

## Available Ethereum Clients

### Execution Clients (ETH1)
| Client | Description | Best For | Install Script |
|--------|-------------|----------|----------------|
| **Geth** | Go implementation, most popular | General use, stability | `install_geth.sh` |
| **Erigon** | Fast sync, low resource usage | Resource-constrained setups | `install_erigon.sh` |
| **Reth** | Rust implementation, fast | Performance, modern hardware | `install_reth.sh` |
| **Nethermind** | .NET implementation | Windows compatibility | `install_nethermind.sh` |
| **Besu** | Java implementation | Enterprise features | `install_besu.sh` |

### Consensus Clients (ETH2)
| Client | Description | Best For | Install Script |
|--------|-------------|----------|----------------|
| **Prysm** | Go implementation, popular | General use, ease of use | `install_prysm.sh` |
| **Lighthouse** | Rust implementation, fast | Performance, resource efficiency | `install_lighthouse.sh` |
| **Teku** | Java implementation | Enterprise, monitoring | `install_teku.sh` |
| **Nimbus** | Nim implementation, lightweight | Resource-constrained | `install_nimbus.sh` |
| **Lodestar** | TypeScript implementation | Development, research | `install_lodestar.sh` |
| **Grandine** | Rust implementation, new | Modern features, performance | `install_grandine.sh` |

## Configuration Architecture

### Centralized Configuration
All configuration is managed through `exports.sh`:
- **User settings**: Email, domain, fee recipient, graffiti
- **Network settings**: Peers, ports, relay URLs
- **Client settings**: Cache sizes, sync modes, features

### Template System
- **Base configs**: Located in `configs/` directory
- **User customization**: Variables from `exports.sh` merged into templates
- **Client-specific**: Each client has optimized configuration templates

## Client Selection Guide

### For Beginners
- **Execution**: Geth (stable, well-documented)
- **Consensus**: Prysm (user-friendly, good documentation)

### For Performance
- **Execution**: Reth or Erigon (fast sync, low resource usage)
- **Consensus**: Lighthouse (fast, efficient)

### For Enterprise
- **Execution**: Besu or Nethermind (enterprise features)
- **Consensus**: Teku (monitoring, enterprise support)

### For Resource-Constrained
- **Execution**: Erigon (low memory usage)
- **Consensus**: Nimbus (lightweight)

## System Requirements

### Minimum Requirements
- **CPU**: 4 cores
- **RAM**: 16 GB
- **Storage**: 2 TB SSD
- **OS**: Ubuntu 20.04+

### Recommended Requirements
- **CPU**: 8+ cores
- **RAM**: 32+ GB
- **Storage**: 4+ TB NVMe SSD
- **OS**: Ubuntu 22.04+

### Client-Specific Requirements
- **Geth**: 16 GB RAM, 2 TB SSD
- **Erigon**: 8 GB RAM, 1 TB SSD
- **Reth**: 16 GB RAM, 2 TB SSD
- **Prysm**: 8 GB RAM, 1 TB SSD
- **Lighthouse**: 4 GB RAM, 1 TB SSD

## Nginx RPC Setup

### Basic Setup
```bash
./install_nginx.sh
./install_ssl.sh
```

### Features
- **RPC/WS endpoints**: Secure access to Ethereum node
- **SSL/TLS**: Automatic certificate management
- **Rate limiting**: Protection against abuse
- **Authentication**: JWT-based access control

## Security Features

### Network Security
- **Firewall**: UFW with comprehensive rules
- **Fail2ban**: Protection against brute force attacks
- **Localhost binding**: Services only accessible locally

### File Security
- **Secure permissions**: Configuration files (600), directories (700)
- **Input validation**: Comprehensive validation functions
- **Error handling**: Sanitized error messages

### Monitoring
- **Security monitoring**: Real-time threat detection
- **Process monitoring**: Suspicious activity detection
- **Log management**: Automated log rotation and analysis

## Troubleshooting

### Common Issues
1. **Services not starting**: Check logs with `journalctl -u service_name`
2. **Sync issues**: Verify network connectivity and client status
3. **Permission errors**: Ensure proper file ownership and permissions
4. **Port conflicts**: Check for conflicting services

### Getting Help
1. Check service logs: `journalctl -u service_name -f`
2. Verify configuration: `./docs/verify_security.sh`
3. Review documentation: `docs/` directory
4. Check system requirements

## Network-Specific Setup

### Mainnet
- Default configuration
- No additional setup required

### Testnets
- Update `exports.sh` with testnet settings
- Use appropriate genesis files
- Configure testnet-specific parameters

## Benefits

- **Client Diversity**: Support for multiple client implementations
- **Security**: Comprehensive security hardening
- **Flexibility**: Choose optimal client combinations
- **Automation**: Streamlined installation and configuration
- **Monitoring**: Built-in security and performance monitoring
- **MEV-Boost Integration**: Maximize validator rewards
- **Uncensored RPC**: Run your own censorship-resistant endpoint
- **Enterprise Features**: Advanced monitoring and management

## Credits

- **Ethereum Foundation**: For the Ethereum protocol
- **Client Teams**: For their excellent implementations
- **Community**: For feedback and contributions

## Contact

- **Issues**: [GitHub Issues](https://github.com/chimera-defi/eth2-quickstart/issues)
- **Discussions**: [GitHub Discussions](https://github.com/chimera-defi/eth2-quickstart/discussions)

## Additional Documentation

### Core Documentation
- Scripts reference: docs/SCRIPTS.md
- Setup workflow: docs/WORKFLOW.md
- Terminology: docs/GLOSSARY.md
- Security guide: docs/SECURITY_GUIDE.md

### Configuration & Development
- Configuration guide: docs/CONFIGURATION_GUIDE.md
- Shell scripting best practices: docs/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md

### Testing & Validation
- Shell script test results: docs/SHELL_SCRIPT_TEST_RESULTS.md

### Project Management
- Commit message conventions: docs/COMMIT_MESSAGES.md
- Development progress: docs/progress.md

### AI Agent Reference
- **Agent Context**: [docs/AGENT_CONTEXT.md](docs/AGENT_CONTEXT.md) - Complete AI agent reference
- **Quick Reference**: [AGENT_QUICK_REFERENCE.md](AGENT_QUICK_REFERENCE.md) - Quick access to agent docs