# MEV Technologies: Implementation Guide

## Overview

This guide provides practical implementation instructions for integrating MEV Boost, Commit Boost, ETHGas, and Profit technologies into the Ethereum node setup project.

---

## Table of Contents

1. [MEV Boost Implementation](#mev-boost-implementation)
2. [Commit Boost Implementation (Planned)](#commit-boost-implementation-planned)
3. [ETHGas Implementation (Planned)](#ethgas-implementation-planned)
4. [Profit Implementation (Planned)](#profit-implementation-planned)
5. [Integration Patterns](#integration-patterns)
6. [Testing and Validation](#testing-and-validation)
7. [Troubleshooting](#troubleshooting)

---

## MEV Boost Implementation

### Current Status

✅ **Fully Implemented** in this project

### Installation

**Script**: `install/mev/install_mev_boost.sh`

**Manual Installation Steps**:

1. **Clone Repository**:
```bash
cd ~/mev-boost
git clone https://github.com/flashbots/mev-boost .
git checkout v1.9
```

2. **Build**:
```bash
make build
```

3. **Configure**:
Edit `exports.sh`:
```bash
MEV_HOST='127.0.0.1'
MEV_PORT=18550
MEV_RELAYS='https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net,https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money'
MIN_BID=0.002
MEVGETHEADERT=950
MEVGETPAYLOADT=4000
MEVREGVALT=6000
```

4. **Create Systemd Service**:
```bash
sudo systemctl edit --full --force mev.service
```

Service file:
```ini
[Unit]
Description=MEV Boost Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=eth
Restart=always
RestartSec=5
TimeoutStartSec=600
TimeoutStopSec=300
ExecStart=/home/eth/mev-boost/mev-boost \
  -mainnet \
  -relay-check \
  -min-bid 0.002 \
  -relays https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net,https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money \
  -request-timeout-getheader 950 \
  -request-timeout-getpayload 4000 \
  -request-timeout-regval 6000 \
  -addr 127.0.0.1:18550 \
  -loglevel info \
  -json

[Install]
WantedBy=multi-user.target
```

5. **Enable and Start**:
```bash
sudo systemctl enable mev
sudo systemctl start mev
sudo systemctl status mev
```

### Client Integration

#### Prysm

**Configuration**: `configs/prysm/prysm_beacon_conf.yaml`
```yaml
http-mev-relay: http://127.0.0.1:18550
```

#### Teku

**Configuration**: `configs/teku/teku_beacon_base.yaml`
```yaml
builder-endpoint: "http://127.0.0.1:18550"
```

#### Lighthouse

**Command Line**:
```bash
--builder http://127.0.0.1:18550
```

#### Lodestar

**Configuration**: `configs/lodestar/lodestar_beacon_base.json`
```json
{
  "builder": {
    "urls": ["http://127.0.0.1:18550"]
  }
}
```

#### Nimbus

**Configuration**: `configs/nimbus/nimbus_base.toml`
```toml
payload-builder-url = "http://127.0.0.1:18550"
```

#### Grandine

**Configuration**: `configs/grandine/grandine_base.toml`
```toml
builder_endpoint = "http://127.0.0.1:18550"
```

### Verification

**Check Service Status**:
```bash
sudo systemctl status mev
journalctl -u mev -f
```

**Test Registration**:
```bash
curl -X POST http://127.0.0.1:18550/eth/v1/builder/validators \
  -H "Content-Type: application/json" \
  -d '{"message": {...}, "signature": "0x..."}'
```

**Check Validator Registration**:
- Flashbots: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now

---

## Commit Boost Implementation (Planned)

### Status

⚠️ **Research Phase** - Awaiting official documentation and specifications

### Planned Implementation

#### Installation Script Template

**File**: `install/mev/install_commit_boost.sh`

```bash
#!/bin/bash

# Commit Boost Installation Script
# Commit Boost implements commit-reveal schemes for MEV extraction

source ../../exports.sh
source ../../lib/common_functions.sh

get_script_directories

log_installation_start "Commit Boost"

# Check system requirements
check_system_requirements 8 500

# Create Commit Boost directory
COMMIT_BOOST_DIR="$HOME/commit-boost"
rm -rf "$COMMIT_BOOST_DIR"
ensure_directory "$COMMIT_BOOST_DIR"

cd "$COMMIT_BOOST_DIR" || exit

# Clone repository (URL TBD)
log_info "Cloning Commit Boost repository..."
# git clone https://github.com/.../commit-boost .

# Build (method TBD)
log_info "Building Commit Boost..."
# make build

# Create systemd service
EXEC_START="$COMMIT_BOOST_DIR/commit-boost \
  -mainnet \
  -commit-networks $COMMIT_NETWORKS \
  -commit-timeout $COMMIT_TIMEOUT \
  -reveal-timeout $REVEAL_TIMEOUT \
  -min-bid $MIN_BID \
  -addr $COMMIT_BOOST_HOST:$COMMIT_BOOST_PORT \
  -loglevel info"

create_systemd_service "commit-boost" "Commit Boost Service" "$EXEC_START" "$(whoami)" "always" "600" "5" "300"

enable_and_start_systemd_service "commit-boost"

log_installation_complete "Commit Boost" "commit-boost" "" "$COMMIT_BOOST_DIR"
```

#### Configuration Variables (Planned)

**Add to `exports.sh`**:
```bash
# Commit Boost configuration
export COMMIT_BOOST_HOST='127.0.0.1'
export COMMIT_BOOST_PORT=18551
export COMMIT_NETWORKS='https://commit-network-1.example.com,https://commit-network-2.example.com'
export COMMIT_TIMEOUT=2000
export REVEAL_TIMEOUT=3000
export COMMITMENT_SCHEME='hash'  # 'hash' or 'pedersen'
```

#### Client Integration (Planned)

Similar to MEV Boost integration, but with commit-reveal protocol support:

**Prysm**:
```yaml
http-mev-relay: http://127.0.0.1:18551
commit-reveal-enabled: true
```

**Other Clients**: Similar configuration patterns

### Implementation Checklist

- [ ] Research commit-reveal protocol specifications
- [ ] Identify commit network providers
- [ ] Develop installation script
- [ ] Implement systemd service
- [ ] Add configuration variables
- [ ] Update client configurations
- [ ] Create testing procedures
- [ ] Document integration steps

---

## ETHGas Implementation (Planned)

### Status

⚠️ **Research Phase** - Awaiting official documentation and specifications

### Planned Implementation

#### Installation Script Template

**File**: `install/mev/install_eat_gas.sh`

```bash
#!/bin/bash

# ETHGas Installation Script
# ETHGas optimizes gas usage for MEV extraction

source ../../exports.sh
source ../../lib/common_functions.sh

get_script_directories

log_installation_start "ETHGas"

# Check system requirements
check_system_requirements 8 500

# Create ETHGas directory
ETHGAS_DIR="$HOME/ethgas"
rm -rf "$ETHGAS_DIR"
ensure_directory "$ETHGAS_DIR"

cd "$ETHGAS_DIR" || exit

# Clone repository (URL TBD)
log_info "Cloning ETHGas repository..."
# git clone https://github.com/.../ethgas .

# Build (method TBD)
log_info "Building ETHGas..."
# make build

# Create systemd service
EXEC_START="$ETHGAS_DIR/ethgas \
  -mainnet \
  -optimization-mode $GAS_OPTIMIZATION_MODE \
  -gas-analysis-enabled $GAS_ANALYSIS_ENABLED \
  -fee-optimization $FEE_OPTIMIZATION \
  -block-space-target $BLOCK_SPACE_TARGET \
  -addr $ETHGAS_HOST:$ETHGAS_PORT \
  -loglevel info"

create_systemd_service "ethgas" "ETHGas Service" "$EXEC_START" "$(whoami)" "always" "600" "5" "300"

enable_and_start_systemd_service "ethgas"

log_installation_complete "ETHGas" "ethgas" "" "$ETHGAS_DIR"
```

#### Configuration Variables (Planned)

**Add to `exports.sh`**:
```bash
# ETHGas configuration
export ETHGAS_HOST='127.0.0.1'
export ETHGAS_PORT=18552
export GAS_OPTIMIZATION_MODE='balanced'  # 'aggressive', 'balanced', 'conservative'
export GAS_ANALYSIS_ENABLED=true
export FEE_OPTIMIZATION=true
export BLOCK_SPACE_TARGET=0.95  # Target 95% block space utilization
```

#### Client Integration (Planned)

ETHGas may integrate differently, potentially as middleware:

**Option 1: Direct Integration**
```yaml
gas-optimizer-endpoint: http://127.0.0.1:18552
gas-optimization-enabled: true
```

**Option 2: Middleware Integration**
- Intercepts transaction flow
- Optimizes before block construction
- Returns optimized transactions

### Implementation Checklist

- [ ] Research gas optimization techniques
- [ ] Identify optimization algorithms
- [ ] Develop installation script
- [ ] Implement systemd service
- [ ] Add configuration variables
- [ ] Design client integration approach
- [ ] Create testing procedures
- [ ] Document integration steps

---

## Profit Implementation (Planned)

### Status

⚠️ **Research Phase** - Awaiting official documentation and specifications

### Planned Implementation

#### Installation Script Template

**File**: `install/mev/install_profit.sh`

```bash
#!/bin/bash

# Profit Installation Script
# Profit implements profit-sharing and profit maximization for MEV

source ../../exports.sh
source ../../lib/common_functions.sh

get_script_directories

log_installation_start "Profit"

# Check system requirements
check_system_requirements 8 500

# Create Profit directory
PROFIT_DIR="$HOME/profit"
rm -rf "$PROFIT_DIR"
ensure_directory "$PROFIT_DIR"

cd "$PROFIT_DIR" || exit

# Clone repository (URL TBD)
log_info "Cloning Profit repository..."
# git clone https://github.com/.../profit .

# Build (method TBD)
log_info "Building Profit..."
# make build

# Create systemd service
EXEC_START="$PROFIT_DIR/profit \
  -mainnet \
  -profit-networks $PROFIT_NETWORKS \
  -distribution-mode $PROFIT_DISTRIBUTION_MODE \
  -analytics-enabled $PROFIT_ANALYTICS_ENABLED \
  -profit-tracking-enabled $PROFIT_TRACKING_ENABLED \
  -addr $PROFIT_HOST:$PROFIT_PORT \
  -loglevel info"

create_systemd_service "profit" "Profit Service" "$EXEC_START" "$(whoami)" "always" "600" "5" "300"

enable_and_start_systemd_service "profit"

log_installation_complete "Profit" "profit" "" "$PROFIT_DIR"
```

#### Configuration Variables (Planned)

**Add to `exports.sh`**:
```bash
# Profit configuration
export PROFIT_HOST='127.0.0.1'
export PROFIT_PORT=18553
export PROFIT_NETWORKS='https://profit-network-1.example.com'
export PROFIT_DISTRIBUTION_MODE='equal'  # 'equal', 'weighted', 'custom'
export PROFIT_ANALYTICS_ENABLED=true
export PROFIT_TRACKING_ENABLED=true
```

#### Client Integration (Planned)

Similar to MEV Boost, but with profit-specific features:

**Prysm**:
```yaml
http-mev-relay: http://127.0.0.1:18553
profit-sharing-enabled: true
```

### Implementation Checklist

- [ ] Research profit distribution models
- [ ] Identify profit calculation methods
- [ ] Develop installation script
- [ ] Implement systemd service
- [ ] Add configuration variables
- [ ] Design profit distribution logic
- [ ] Create analytics system
- [ ] Create testing procedures
- [ ] Document integration steps

---

## Integration Patterns

### Pattern 1: Single Technology

Use one MEV technology at a time:

```bash
# Use MEV Boost only
sudo systemctl start mev
sudo systemctl stop commit-boost ethgas profit
```

### Pattern 2: Sequential Fallback

Try technologies in sequence, fallback to next:

```bash
# Try Commit Boost first, fallback to MEV Boost
if ! commit-boost-available; then
    use-mev-boost
fi
```

### Pattern 3: Parallel Comparison

Query all technologies, select best:

```bash
# Query all technologies simultaneously
mev-boost-bid=$(query-mev-boost)
commit-boost-bid=$(query-commit-boost)
ethgas-bid=$(query-ethgas)
profit-bid=$(query-profit)

# Select highest bid
best-bid=$(max $mev-boost-bid $commit-boost-bid $ethgas-bid $profit-bid)
```

### Pattern 4: Hybrid Approach

Use different technologies for different scenarios:

```bash
# High-value blocks: Commit Boost
if block-value > threshold; then
    use-commit-boost
# Gas optimization: ETHGas
elif gas-optimization-needed; then
    use-ethgas
# Standard blocks: MEV Boost
else
    use-mev-boost
fi
```

---

## Testing and Validation

### MEV Boost Testing

**1. Service Status**:
```bash
sudo systemctl status mev
journalctl -u mev -n 50
```

**2. Registration Test**:
```bash
curl -X POST http://127.0.0.1:18550/eth/v1/builder/validators \
  -H "Content-Type: application/json" \
  -d @validator-registration.json
```

**3. Header Request Test**:
```bash
curl http://127.0.0.1:18550/eth/v1/builder/header/123456/0x.../0x...
```

**4. Validator Registration Check**:
- Visit: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now
- Enter validator public key (with 0x prefix)

**5. Block Proposal Monitoring**:
```bash
# Monitor validator logs for MEV blocks
journalctl -u validator -f | grep -i "mev\|builder"
```

### Commit Boost Testing (Planned)

**1. Service Status**:
```bash
sudo systemctl status commit-boost
journalctl -u commit-boost -n 50
```

**2. Commitment Test**:
```bash
# Submit commitment
curl -X POST http://127.0.0.1:18551/commit \
  -H "Content-Type: application/json" \
  -d @commitment.json
```

**3. Reveal Test**:
```bash
# Request reveal
curl -X POST http://127.0.0.1:18551/reveal \
  -H "Content-Type: application/json" \
  -d @reveal-request.json
```

**4. Verification Test**:
```bash
# Verify commitment
curl http://127.0.0.1:18551/verify/0x...
```

### ETHGas Testing (Planned)

**1. Service Status**:
```bash
sudo systemctl status ethgas
journalctl -u ethgas -n 50
```

**2. Gas Analysis Test**:
```bash
# Analyze transaction
curl -X POST http://127.0.0.1:18552/analyze \
  -H "Content-Type: application/json" \
  -d @transaction.json
```

**3. Optimization Test**:
```bash
# Optimize block
curl -X POST http://127.0.0.1:18552/optimize \
  -H "Content-Type: application/json" \
  -d @block-request.json
```

### Profit Testing (Planned)

**1. Service Status**:
```bash
sudo systemctl status profit
journalctl -u profit -n 50
```

**2. Profit Analysis Test**:
```bash
# Analyze profit
curl -X POST http://127.0.0.1:18553/analyze \
  -H "Content-Type: application/json" \
  -d @profit-request.json
```

**3. Distribution Test**:
```bash
# Test distribution
curl -X POST http://127.0.0.1:18553/distribute \
  -H "Content-Type: application/json" \
  -d @distribution-request.json
```

**4. Analytics Test**:
```bash
# Get analytics
curl http://127.0.0.1:18553/analytics
```

---

## Troubleshooting

### MEV Boost Issues

**Problem**: Service not starting
```bash
# Check logs
journalctl -u mev -n 100

# Check configuration
cat ~/mev-boost/mev-boost --help

# Verify relays are accessible
curl https://boost-relay.flashbots.net
```

**Problem**: Validator not registered
```bash
# Check registration
curl http://127.0.0.1:18550/eth/v1/builder/status

# Re-register
# Restart validator service
sudo systemctl restart validator
```

**Problem**: No MEV blocks
```bash
# Check relay connectivity
curl https://boost-relay.flashbots.net/eth/v1/builder/status

# Check min-bid setting (may be too high)
grep MIN_BID exports.sh

# Monitor bids
journalctl -u mev -f | grep -i bid
```

### Commit Boost Issues (Planned)

**Problem**: Commitments failing
- Check commit network connectivity
- Verify commitment scheme
- Check reveal timing

**Problem**: Reveals not matching commitments
- Verify cryptographic implementation
- Check nonce generation
- Validate commitment verification

### ETHGas Issues (Planned)

**Problem**: Optimization not working
- Check gas analysis enabled
- Verify optimization mode
- Check transaction data

**Problem**: Performance issues
- Adjust optimization mode
- Reduce analysis depth
- Check resource usage

### Profit Issues (Planned)

**Problem**: Profit calculation errors
- Verify profit model
- Check distribution mode
- Validate input data

**Problem**: Distribution failures
- Check profit network
- Verify distribution agreements
- Check participant addresses

---

## Best Practices

### Security

1. **Use Multiple Relays**: Don't rely on a single relay
2. **Verify Registrations**: Regularly check validator registration status
3. **Monitor Logs**: Watch for suspicious activity
4. **Keep Updated**: Regularly update MEV software
5. **Secure Configuration**: Protect configuration files (600 permissions)

### Performance

1. **Optimize Timeouts**: Set appropriate timeout values
2. **Monitor Resources**: Watch CPU, memory, network usage
3. **Test Regularly**: Test integrations regularly
4. **Monitor Metrics**: Track MEV extraction rates
5. **Optimize Configuration**: Tune settings for your setup

### Reliability

1. **Use Systemd**: Proper service management
2. **Enable Auto-restart**: Configure restart policies
3. **Monitor Health**: Regular health checks
4. **Backup Configuration**: Backup configuration files
5. **Document Changes**: Document any custom configurations

---

## Conclusion

This implementation guide provides practical steps for integrating MEV technologies. MEV Boost is production-ready, while Commit Boost, ETHGas, and Profit require further research and development before implementation.

**Next Steps**:
1. Monitor development progress
2. Update documentation as specifications become available
3. Implement test integrations
4. Plan production rollout

---

*Last Updated: [Current Date]*  
*Document Version: 1.0*
