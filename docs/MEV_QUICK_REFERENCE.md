# MEV Technologies: Quick Reference

## Technology Status

| Technology | Status | Production Ready | Implementation |
|------------|--------|-----------------|----------------|
| **MEV-Boost** | ✅ Active | ✅ Yes | ✅ **Implemented** |
| **Commit-Boost** | ✅ Active | ✅ Yes | ✅ **Implemented** |
| **ETHGas** | ✅ Active | ✅ Yes | ✅ **Implemented** |

⚠️ **IMPORTANT**: MEV-Boost and Commit-Boost are **mutually exclusive** - choose ONE!

---

## Quick Decision Guide

**Most Users (Stable, Production-Proven)** → **MEV-Boost** ✅

**Want Preconfirmations/Advanced Features** → **Commit-Boost** + optional **ETHGas**

---

## Installation

### Option A: MEV-Boost (RECOMMENDED)
```bash
cd install/mev
./install_mev_boost.sh
```

### Option B: Commit-Boost + ETHGas
```bash
# Manual installation
cd install/mev
./install_commit_boost.sh
./install_ethgas.sh  # Optional: requires Commit-Boost

# Or via run_2.sh flags
./run_2.sh --execution=geth --consensus=prysm --mev=commit-boost --ethgas
```

---

## Port Reference

| Service | Port | Notes |
|---------|------|-------|
| MEV-Boost | 18550 | Standard BuilderAPI |
| Commit-Boost PBS | 18550 | Same port (drop-in replacement) |
| Commit-Boost Signer | 20000 | Commitment protocol signing |
| Commit-Boost Metrics | 10000+ | Prometheus metrics |
| ETHGas | 18552 | Preconfirmation service |
| ETHGas Metrics | 18553 | Prometheus metrics |

---

## Service Management

### MEV-Boost
```bash
sudo systemctl start mev
sudo systemctl status mev
journalctl -u mev -f
```

### Commit-Boost
```bash
sudo systemctl start commit-boost-pbs commit-boost-signer
sudo systemctl status commit-boost-pbs commit-boost-signer
journalctl -u commit-boost-pbs -f
```

### ETHGas
```bash
sudo systemctl start ethgas
sudo systemctl status ethgas
journalctl -u ethgas -f
```

---

## Verification Commands

### MEV-Boost
```bash
curl http://127.0.0.1:18550/eth/v1/builder/status
```

### Commit-Boost
```bash
curl http://127.0.0.1:18550/eth/v1/builder/status  # Same endpoint as MEV-Boost
curl http://127.0.0.1:10000/metrics
```

### ETHGas
```bash
curl http://127.0.0.1:18553/metrics
```

---

## Client Integration

### MEV-Boost (Port 18550)
- **Prysm**: `http-mev-relay: http://127.0.0.1:18550`
- **Teku**: `builder-endpoint: "http://127.0.0.1:18550"`
- **Lighthouse**: `--builder http://127.0.0.1:18550`
- **Lodestar**: `builder.urls: ["http://127.0.0.1:18550"]`
- **Nimbus**: `payload-builder-url = "http://127.0.0.1:18550"`
- **Grandine**: `builder_endpoint = "http://127.0.0.1:18550"`

### Commit-Boost (Port 18550 — same as MEV-Boost)
Consensus client configs use `$MEV_HOST:$MEV_PORT` which works for both.
No config changes needed when switching between MEV-Boost and Commit-Boost.

---

## Configuration Variables (exports.sh)

### MEV-Boost
```bash
MEV_HOST='127.0.0.1'
MEV_PORT=18550
MEV_RELAYS='...'
MIN_BID=0.002
MEVGETHEADERT=950
MEVGETPAYLOADT=4000
MEVREGVALT=6000
```

### Commit-Boost
```bash
COMMIT_BOOST_HOST=$MEV_HOST   # Same as MEV-Boost (drop-in)
COMMIT_BOOST_PORT=$MEV_PORT   # Same as MEV-Boost (drop-in)
COMMIT_BOOST_SIGNER_PORT=20000
COMMIT_BOOST_METRICS_PORT=10000
```

### ETHGas
```bash
ETHGAS_HOST='127.0.0.1'
ETHGAS_PORT=18552
ETHGAS_METRICS_PORT=18553
ETHGAS_NETWORK='mainnet'
ETHGAS_REGISTRATION_MODE='standard'
```

---

## Testing

```bash
cd install/mev
./test_mev_implementations.sh
```

---

## Troubleshooting

### Service Not Starting
```bash
journalctl -u <service_name> -n 100
```

### Check Ports
```bash
ss -tuln | grep -E "18550|18551|18552|18553|20000|10000"
```

### Both Running (Should Not Happen)
```bash
# Stop MEV-Boost if using Commit-Boost
sudo systemctl stop mev && sudo systemctl disable mev

# OR stop Commit-Boost if using MEV-Boost
sudo systemctl stop commit-boost-pbs commit-boost-signer
```

---

## Useful Links

### MEV-Boost
- Repository: https://github.com/flashbots/mev-boost
- Documentation: https://docs.flashbots.net/
- Validator Check: https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now

### Commit-Boost
- Repository: https://github.com/Commit-Boost/commit-boost-client
- Documentation: https://commit-boost.github.io/commit-boost-client/

### ETHGas
- Repository: https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module
- Documentation: https://docs.ethgas.com/

---

## Feature Comparison

| Feature | MEV-Boost | Commit-Boost | ETHGas |
|---------|-----------|--------------|--------|
| Block Proposals | ✅ | ✅ | ✅ |
| MEV-Boost Compatible | N/A | ✅ | ✅ |
| Preconfirmations | ❌ | ✅ | ✅ |
| Multiple Relays | ✅ | ✅ | ✅ |
| Production Ready | ✅ | ✅ | ✅ |
| **Implemented** | ✅ | ✅ | ✅ |

---

*Last Updated: February 2026*  
*Version: 3.1*
