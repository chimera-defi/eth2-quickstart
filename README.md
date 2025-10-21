# Ethereum Node Quick Setup

Setup an Ethereum node quickly with simple shell scripts containing community best practices. 
Supports multiple client combinations for servers, home solo stakers, and pool node operators.
Choose from various execution and consensus clients for optimal client diversity.

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

## Sync and Configure

**Note: You may be able to skip this step now with checkpoint URLs added**

1. **Sync Prysm instantly** using provided checkpoint files:
   ```bash
   sudo systemctl stop cl
   sudo systemctl stop validator
   $(echo $HOME)/prysm/prysm.sh cl --checkpoint-block=$PWD/prysm/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/prysm/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/prysm/genesis.ssz --config-file=$PWD/prysm/prysm_beacon_conf.yaml --p2p-host-ip=$(curl -s v4.ident.me)
   ```
   
   **Restart services after sync:**
   ```bash
   sudo systemctl restart cl
   sudo systemctl restart validator
   ```

2. **Set up validator** using Prysm documentation:
   - Create a `pass.txt` file in `~/prysm` with your wallet password
   - Follow: https://docs.prylabs.network/docs/install/install-with-script#step-5-run-a-validator-using-prysm

3. **Geth sync timing**: Benchmark is 1-3 days running in the background

## Available Ethereum Clients

### Execution Clients (ETH1)
| Client | Language | Description | Best For | Install Script |
|--------|----------|-------------|----------|----------------|
| **Geth** | Go | Original Go implementation, most stable | Beginners, stability | `install_geth.sh` |
| **Erigon** | Go | Re-architected for efficiency | Performance, fast sync | `install_erigon.sh` |
| **Reth** | Rust | Modern Rust implementation | Performance, modularity | `install_reth.sh` |
| **Nethermind** | C# | Enterprise-focused .NET client | Enterprise, advanced features | `install_nethermind.sh` |
| **Besu** | Java | Apache 2.0 licensed, enterprise-ready | Private networks, compliance | `install_besu.sh` |

### Consensus Clients (ETH2)
| Client | Language | Description | Best For | Install Script |
|--------|----------|-------------|----------|----------------|
| **Prysm** | Go | Well-documented, reliable | Beginners, documentation | `install_prysm.sh` |
| **Lighthouse** | Rust | Security-focused, high performance | Performance, security | `install_lighthouse.sh` |
| **Teku** | Java | ConsenSys-developed, enterprise features | Institutional, monitoring | `install_teku.sh` |
| **Nimbus** | Nim | Lightweight, resource efficient | Raspberry Pi, low resources | `install_nimbus.sh` |
| **Lodestar** | TypeScript | Developer-friendly, modern | Development, TypeScript devs | `install_lodestar.sh` |
| **Grandine** | Rust | High-performance, cutting-edge | Advanced users, performance | `install_grandine.sh` |

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

### System Requirements by Client

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **CPU** | 4 cores | 8+ cores | More cores help with sync |
| **RAM** | 16GB | 32GB+ | Nimbus can run on 8GB |
| **Storage** | 2TB SSD | 4TB NVMe | Fast storage crucial |
| **Network** | Stable broadband | Unlimited data | Avoid metered connections |

### Client-Specific Requirements
- **Geth**: 16 GB RAM, 2 TB SSD
- **Erigon**: 8 GB RAM, 1 TB SSD  
- **Reth**: 16 GB RAM, 2 TB SSD
- **Prysm**: 8 GB RAM, 1 TB SSD
- **Lighthouse**: 4 GB RAM, 1 TB SSD

## Nginx RPC Setup

Setup a secure uncensored outward facing Ethereum RPC for you and your friends! It's been faster than Infura/Alchemy etc.

### Basic Setup
```bash
./install_nginx.sh
./install_ssl.sh
```

### Verify RPC Endpoint
```bash
# Test locally
curl -X POST http://$(curl -s v4.ident.me)/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'

# Test with domain (replace with your domain)
curl -X POST https://yourdomain.com/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'
```

### Domain Setup (Optional)
1. **Get a domain**: e.g., via Namecheap
2. **Setup DNS**: Point A record to your server's public IP
3. **Configure Nginx**: Handle requests and provide RPC

### SSL Options
- **ACME.sh**: `./install_acme_ssl.sh` (recommended)
- **Certbot**: `./install_ssl_certbot.sh`

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

### Client-Specific Issues

#### Execution Clients
- **Geth**: Most stable, check for port conflicts on 8545, 8546, 30303
- **Erigon**: Requires more RAM during sync, check `config.yaml` settings
- **Reth**: Compilation issues? Ensure Rust toolchain is updated
- **Nethermind**: .NET runtime issues? Check .NET installation
- **Besu**: Java heap size issues? Adjust memory settings in config

#### Consensus Clients
- **Prysm**: Checkpoint sync failing? Update `PRYSM_CPURL` in `exports.sh`
- **Lighthouse**: Rust compilation issues? Update Rust toolchain
- **Teku**: Java out of memory? Increase heap size in service file
- **Nimbus**: Resource constraints? It's designed for low-resource systems
- **Lodestar**: Node.js issues? Ensure Node.js 16+ is installed
- **Grandine**: Very new client, check official docs for latest updates

### Getting Help
1. Check service logs: `journalctl -u service_name -f`
2. Verify configuration: `./docs/verify_security.sh`
3. Review documentation: `docs/` directory
4. Check system requirements

## Network-Specific Setup

### Testnet Usage (Goerli/Holesky)
Before running client install scripts, modify configurations:
- Update checkpoint URLs in `exports.sh`
- Add network flags (e.g., `--goerli`, `--holesky`) to client commands
- Ensure testnet-specific genesis and checkpoint files

### Mainnet Optimization
- Enable checkpoint sync for faster initial sync
- Configure MEV-Boost with multiple relays
- Set appropriate cache sizes based on available RAM
- Use fast NVMe storage for better performance

## Benefits

- **Client Diversity**: Support for multiple client implementations
- **Interactive Selection**: Guided client selection with recommendations
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