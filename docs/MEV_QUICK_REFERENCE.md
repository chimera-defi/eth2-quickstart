# MEV Technologies: Quick Reference

## Technology Status

| Technology | Status | Production Ready | Implementation |
|------------|--------|-----------------|----------------|
| **MEV Boost** | ✅ Active | ✅ Yes | ✅ Implemented |
| **Commit Boost** | ✅ Available | ✅ Yes | ❌ Not implemented |
| **ETHGas** | ✅ Available | ✅ Yes | ❌ Not implemented |
| **Profit** | 🔬 Research | ❌ No | ❌ Not found |

---

## Quick Decision Guide

**Need Production Solution Now?** → **Use MEV Boost** ✅

**Want Preconfirmations/Advanced Features?** → **Plan Commit Boost + ETHGas** 🔄

**Need Gas Optimization?** → **ETHGas** (requires Commit-Boost)

---

## MEV Boost Quick Start

### Installation
```bash
./install/mev/install_mev_boost.sh
```

### Configuration (`exports.sh`)
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
- **Teku**: `builder-endpoint: "http://127.0.0.1:18550"`
- **Lighthouse**: `--builder http://127.0.0.1:18550`
- **Lodestar**: `builder.urls: ["http://127.0.0.1:18550"]`
- **Nimbus**: `payload-builder-url = "http://127.0.0.1:18550"`
- **Grandine**: `builder_endpoint = "http://127.0.0.1:18550"`

### Verification
```bash
# Check service
sudo systemctl status mev

# Check API
curl http://127.0.0.1:18550/eth/v1/builder/status

# Check validator registration
# Visit: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now
```

---

## Port Reference

| Technology | Default Port | Service Name | Status |
|------------|--------------|--------------|--------|
| MEV Boost | 18550 | `mev` | ✅ Active |
| Commit Boost | 18551 | `commit-boost` | 🔄 Planned |
| ETHGas | 18552 | `ethgas` | 🔄 Planned |
| Profit | 18553 | `profit` | ❌ Research |

---

## Configuration Variables

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
# Additional config TBD
```

### ETHGas (Planned)
```bash
ETHGAS_HOST='127.0.0.1'
ETHGAS_PORT=18552
# Docker Compose deployment
# Requires Commit-Boost
```

---

## Troubleshooting

### MEV Boost Not Starting
```bash
journalctl -u mev -n 100
grep MEV exports.sh
curl https://boost-relay.flashbots.net
```

### No MEV Blocks
```bash
grep MIN_BID exports.sh  # Check if too high
journalctl -u mev -f | grep -i bid
curl https://boost-relay.flashbots.net/eth/v1/builder/status
```

### Validator Not Registered
```bash
sudo systemctl restart validator
# Check: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now
```

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

## Useful Links

### MEV Boost
- Repository: https://github.com/flashbots/mev-boost
- Documentation: https://docs.flashbots.net/
- Validator Check: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now

### Commit Boost
- Repository: https://github.com/Commit-Boost/commit-boost-client
- Documentation: https://commit-boost.github.io/commit-boost-client/

### ETHGas
- Repository: https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module
- Documentation: https://docs.ethgas.com/

### Related
- Builder API: Ethereum Builder API specifications
- PBS: Proposer-Builder Separation

---

## Feature Comparison

| Feature | MEV Boost | Commit Boost | ETHGas |
|---------|-----------|--------------|--------|
| Block Proposals | ✅ | ✅ | ✅ |
| MEV-Boost Compatible | N/A | ✅ | ✅ (via Commit-Boost) |
| Preconfirmations | ❌ | ✅ | ✅ |
| Multiple Relays | ✅ | ✅ | ✅ |
| Production Ready | ✅ | ✅ | ✅ |
| Implemented Here | ✅ | ❌ | ❌ |

---

*Last Updated: [Current Date]*  
*Version: 2.0*
