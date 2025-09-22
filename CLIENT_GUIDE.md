# Ethereum Client Installation Guide

This guide provides detailed information about each Ethereum client supported by this project.

## Execution Clients

### Geth (Go-Ethereum)
- **Language:** Go
- **Sync Speed:** Medium
- **Memory Usage:** Medium
- **Best For:** Most users, battle-tested
- **Installation:** `./install_geth.sh`

**Features:**
- Most popular and widely used
- Excellent community support
- Stable and reliable
- Good balance of performance and resource usage

### Nethermind
- **Language:** .NET
- **Sync Speed:** Fast
- **Memory Usage:** Low
- **Best For:** High performance needs
- **Installation:** `./install_nethermind.sh`

**Features:**
- High performance
- Low memory usage
- Good for resource-constrained environments
- Enterprise features

### Besu
- **Language:** Java
- **Sync Speed:** Medium
- **Memory Usage:** High
- **Best For:** Enterprise features
- **Installation:** `./install_besu.sh`

**Features:**
- Enterprise-focused
- Privacy features
- Permissioning
- Good for corporate environments

### Erigon
- **Language:** Go
- **Sync Speed:** Very Fast
- **Memory Usage:** Low
- **Best For:** Fast sync, archival
- **Installation:** `./erigon.sh`

**Features:**
- Fastest sync times
- Low memory usage
- Good for archival nodes
- Modular architecture

### Reth
- **Language:** Rust
- **Sync Speed:** Very Fast
- **Memory Usage:** Low
- **Best For:** Performance, new features
- **Installation:** `./install_reth.sh`

**Features:**
- Very fast sync
- Low resource usage
- Modern architecture
- Active development

## Consensus Clients

### Prysm
- **Language:** Go
- **Memory Usage:** Medium
- **Best For:** Most users, easy setup
- **Installation:** `./install_prysm.sh`

**Features:**
- Most popular consensus client
- Easy to set up and use
- Good documentation
- Integrated validator client

### Lighthouse
- **Language:** Rust
- **Memory Usage:** Low
- **Best For:** High performance
- **Installation:** `./lighthouse.sh`

**Features:**
- High performance
- Low memory usage
- Fast sync
- Good for resource-constrained environments

### Teku
- **Language:** Java
- **Memory Usage:** High
- **Best For:** Enterprise features
- **Installation:** `./install_teku.sh`

**Features:**
- Enterprise-focused
- Good for large-scale deployments
- Comprehensive monitoring
- Separate validator client

### Nimbus
- **Language:** Nim
- **Memory Usage:** Very Low
- **Best For:** Resource-constrained
- **Installation:** `./install_nimbus.sh`

**Features:**
- Lowest memory usage
- Good for embedded systems
- Lightweight
- Integrated validator client

### Lodestar
- **Language:** TypeScript
- **Memory Usage:** Medium
- **Best For:** JavaScript ecosystem
- **Installation:** `./install_lodestar.sh`

**Features:**
- TypeScript implementation
- Good for developers
- Modern architecture
- Active development

## Installation Methods

### Method 1: Interactive Selection (Recommended)
```bash
./client_selector.sh
```
This will guide you through selecting your preferred clients.

### Method 2: Individual Installation
```bash
# Choose one execution client
./install_geth.sh
# OR
./install_nethermind.sh
# OR
./install_besu.sh
# OR
./erigon.sh
# OR
./install_reth.sh

# Choose one consensus client
./install_prysm.sh
# OR
./lighthouse.sh
# OR
./install_teku.sh
# OR
./install_nimbus.sh
# OR
./install_lodestar.sh

# Install MEV-Boost
./install_mev_boost.sh
```

## Configuration

All clients are configured using the `exports.sh` file. Key variables:

```bash
# Validator settings
export FEE_RECIPIENT=0x...  # Your fee recipient address
export GRAFITTI="Your Graffiti"  # Your graffiti message
export MAX_PEERS=100  # Maximum number of peers

# Checkpoint sync URL
export PRYSM_CPURL="https://beaconstate.ethstaker.cc"

# MEV-Boost settings
export MIN_BID=0.002
export MEV_RELAYS="https://..."
```

## Service Management

All clients are installed as systemd services:

```bash
# Start services
sudo systemctl start eth1      # Execution client
sudo systemctl start cl        # Consensus client
sudo systemctl start validator # Validator client
sudo systemctl start mev       # MEV-Boost

# Check status
sudo systemctl status eth1
sudo systemctl status cl
sudo systemctl status validator
sudo systemctl status mev

# View logs
sudo journalctl -u eth1 -f
sudo journalctl -u cl -f
sudo journalctl -u validator -f
sudo journalctl -u mev -f
```

## Troubleshooting

### Common Issues

1. **Service won't start:**
   - Check logs: `sudo journalctl -u <service-name> -f`
   - Verify configuration files
   - Check if ports are available

2. **Sync issues:**
   - Ensure execution client is synced first
   - Check checkpoint sync URLs
   - Verify network connectivity

3. **Memory issues:**
   - Consider switching to a lighter client (Nimbus, Lighthouse)
   - Increase system memory
   - Adjust client memory settings

### Getting Help

- Check client-specific documentation
- Join community Discord/Slack channels
- Check GitHub issues for your chosen client
- Use the troubleshooting section in the main README

## Performance Tips

1. **For fast sync:** Use Erigon or Reth
2. **For low memory:** Use Nimbus or Lighthouse
3. **For stability:** Use Geth and Prysm
4. **For enterprise:** Use Besu and Teku
5. **For development:** Use Lodestar

## Security Considerations

1. **Firewall:** All necessary ports are opened automatically
2. **User permissions:** Services run as non-root user
3. **JWT secrets:** Generated automatically and secured
4. **Configuration:** Sensitive data is stored in secure locations

## Monitoring

All clients include metrics endpoints:
- **Geth:** http://localhost:6060/debug/metrics
- **Nethermind:** http://localhost:8000/metrics
- **Besu:** http://localhost:9545/metrics
- **Erigon:** http://localhost:6060/debug/metrics
- **Reth:** http://localhost:9001/metrics
- **Prysm:** http://localhost:8080/metrics
- **Lighthouse:** http://localhost:5054/metrics
- **Teku:** http://localhost:8008/metrics
- **Nimbus:** http://localhost:8008/metrics
- **Lodestar:** http://localhost:8008/metrics