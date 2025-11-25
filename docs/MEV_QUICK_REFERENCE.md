# MEV Technologies: Quick Reference Guide

## Technology Status at a Glance

| Technology | Status | Production Ready | Documentation |
|------------|--------|-----------------|--------------|
| **MEV Boost** | ✅ Active | ✅ Yes | ✅ Comprehensive |
| **Commit Boost** | 🔬 Research | ❌ No | ❓ Unknown |
| **ETHGas** | 🔬 Research | ❌ No | ❓ Unknown |
| **Profit** | 🔬 Research | ❌ No | ❓ Unknown |

---

## Quick Decision Guide

### Need Production Solution Now?
→ **Use MEV Boost**

### Need Privacy/Commit-Reveal?
→ **Monitor Commit Boost** (when available)

### Need Gas Optimization?
→ **Monitor ETHGas** (when available)

### Need Profit Sharing?
→ **Monitor Profit** (when available)

---

## MEV Boost Quick Start

### Installation
```bash
./install/mev/install_mev_boost.sh
```

### Configuration
Edit `exports.sh`:
```bash
MEV_HOST='127.0.0.1'
MEV_PORT=18550
MEV_RELAYS='https://...@boost-relay.flashbots.net,...'
MIN_BID=0.002
```

### Service Management
```bash
sudo systemctl start mev
sudo systemctl status mev
journalctl -u mev -f
```

### Client Integration
- **Prysm**: `http-mev-relay: http://127.0.0.1:18550`
- **Teku**: `builder-endpoint: http://127.0.0.1:18550`
- **Lighthouse**: `--builder http://127.0.0.1:18550`
- **Lodestar**: `builder.urls: ["http://127.0.0.1:18550"]`
- **Nimbus**: `payload-builder-url = "http://127.0.0.1:18550"`
- **Grandine**: `builder_endpoint = "http://127.0.0.1:18550"`

### Verification
```bash
# Check service
sudo systemctl status mev

# Check registration
curl http://127.0.0.1:18550/eth/v1/builder/status

# Online validator check
# Visit: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now
```

---

## Feature Comparison

### Core Capabilities

| Feature | MEV Boost | Commit Boost | ETHGas | Profit |
|---------|-----------|--------------|---------|--------|
| Block Proposals | ✅ | ✅ | ✅ | ✅ |
| Multiple Relays | ✅ | ❓ | ❓ | ❓ |
| Privacy | ⚠️ Basic | ✅ Enhanced | ⚠️ Basic | ⚠️ Basic |
| Gas Optimization | ⚠️ Basic | ❌ | ✅ Yes | ⚠️ Basic |
| Profit Sharing | ❌ | ❌ | ❌ | ✅ Yes |

---

## Port Reference

| Technology | Default Port | Service Name |
|------------|--------------|--------------|
| MEV Boost | 18550 | `mev` |
| Commit Boost | 18551 | `commit-boost` |
| ETHGas | 18552 | `ethgas` |
| Profit | 18553 | `profit` |

---

## Configuration Variables Reference

### MEV Boost (Current)
```bash
MEV_HOST='127.0.0.1'
MEV_PORT=18550
MEV_RELAYS='...'
MIN_BID=0.002
MEVGETHEADERT=950
MEVGETPAYLOADT=4000
MEVREGVALT=6000
```

### Commit Boost (Planned)
```bash
COMMIT_BOOST_HOST='127.0.0.1'
COMMIT_BOOST_PORT=18551
COMMIT_NETWORKS='...'
COMMIT_TIMEOUT=2000
REVEAL_TIMEOUT=3000
```

### ETHGas (Planned)
```bash
ETHGAS_HOST='127.0.0.1'
ETHGAS_PORT=18552
GAS_OPTIMIZATION_MODE='balanced'
GAS_ANALYSIS_ENABLED=true
FEE_OPTIMIZATION=true
```

### Profit (Planned)
```bash
PROFIT_HOST='127.0.0.1'
PROFIT_PORT=18553
PROFIT_NETWORKS='...'
PROFIT_DISTRIBUTION_MODE='equal'
PROFIT_ANALYTICS_ENABLED=true
```

---

## Troubleshooting Quick Fixes

### MEV Boost Not Starting
```bash
# Check logs
journalctl -u mev -n 100

# Verify configuration
grep MEV exports.sh

# Check relay connectivity
curl https://boost-relay.flashbots.net
```

### Validator Not Registered
```bash
# Restart validator
sudo systemctl restart validator

# Check registration status
# Visit Flashbots validator check page
```

### No MEV Blocks
```bash
# Check min-bid (may be too high)
grep MIN_BID exports.sh

# Monitor bids
journalctl -u mev -f | grep -i bid

# Check relay status
curl https://boost-relay.flashbots.net/eth/v1/builder/status
```

---

## Documentation Index

1. **MEV_TECHNOLOGIES_COMPARISON.md** - Comprehensive comparison
2. **MEV_TECHNICAL_ARCHITECTURE.md** - Technical deep dive
3. **MEV_IMPLEMENTATION_GUIDE.md** - Implementation instructions
4. **MEV_DECISION_GUIDE.md** - Decision-making framework
5. **MEV_RESEARCH_SUMMARY.md** - Research findings
6. **MEV_QUICK_REFERENCE.md** - This document

---

## Useful Links

### MEV Boost
- Repository: https://github.com/flashbots/mev-boost
- Documentation: https://docs.flashbots.net/
- Testing Guide: https://github.com/flashbots/mev-boost/wiki/Testing
- Validator Check: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now

### Related
- Builder API: Ethereum Builder API specifications
- EIP-4844: Proto-Danksharding
- PBS: Proposer-Builder Separation

---

## Common Commands

### Service Management
```bash
# Start
sudo systemctl start mev

# Stop
sudo systemctl stop mev

# Restart
sudo systemctl restart mev

# Status
sudo systemctl status mev

# Logs
journalctl -u mev -f
```

### Testing
```bash
# Test registration
curl -X POST http://127.0.0.1:18550/eth/v1/builder/validators \
  -H "Content-Type: application/json" \
  -d @validator-registration.json

# Test header request
curl http://127.0.0.1:18550/eth/v1/builder/header/{slot}/{parent_hash}/{pubkey}
```

---

*Last Updated: [Current Date]*  
*Version: 1.0*
