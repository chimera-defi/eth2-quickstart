# MEV Technologies Guide

## Overview

This guide covers MEV (Maximal Extractable Value) technologies for Ethereum validators. Three production-ready solutions are available: **MEV Boost** (implemented), **Commit Boost** (production-ready, not yet implemented), and **ETHGas** (production-ready, requires Commit-Boost, not yet implemented).

---

## Technology Status

| Technology | Status | Production Ready | Implementation Status |
|------------|--------|-----------------|----------------------|
| **MEV Boost** | ✅ Active | ✅ Yes | ✅ Implemented |
| **Commit Boost** | ✅ Available | ✅ Yes | ❌ Not implemented |
| **ETHGas** | ✅ Available | ✅ Yes | ❌ Not implemented (requires Commit-Boost) |
| **Profit** | 🔬 Research | ❌ No | ❌ Not found as separate project |

---

## MEV Boost

### Overview

**MEV Boost** is the industry-standard middleware that connects Ethereum validators to block builders through relays. It's fully implemented and production-ready.

**Repository**: https://github.com/flashbots/mev-boost  
**Documentation**: https://docs.flashbots.net/

### Key Features

- ✅ Relay-based architecture with multiple relay support
- ✅ Builder API v1.5+ integration
- ✅ Validator registration and bid comparison
- ✅ Proven stability and reliability
- ✅ Comprehensive documentation

### Current Implementation

**Installation Script**: `install/mev/install_mev_boost.sh`  
**Service**: `mev.service`  
**Port**: `18550` (configurable via `MEV_PORT`)

**Configuration** (`exports.sh`):
```bash
MEV_HOST='127.0.0.1'
MEV_PORT=18550
MEV_RELAYS='https://...@boost-relay.flashbots.net,...'
MIN_BID=0.002
MEVGETHEADERT=950
MEVGETPAYLOADT=4000
MEVREGVALT=6000
```

**Client Integration**:
- **Prysm**: `http-mev-relay: http://127.0.0.1:18550`
- **Teku**: `builder-endpoint: "http://127.0.0.1:18550"`
- **Lighthouse**: `--builder http://127.0.0.1:18550`
- **Lodestar**: `builder.urls: ["http://127.0.0.1:18550"]`
- **Nimbus**: `payload-builder-url = "http://127.0.0.1:18550"`
- **Grandine**: `builder_endpoint = "http://127.0.0.1:18550"`

**Verification**:
```bash
sudo systemctl status mev
journalctl -u mev -f
curl http://127.0.0.1:18550/eth/v1/builder/status
```

---

## Commit Boost

### Overview

**Commit Boost** is a modular Ethereum validator sidecar that standardizes communication between validators and third-party protocols. It's production-ready, audited by Sigma Prime, and can replace or complement MEV-Boost.

**Repository**: https://github.com/Commit-Boost/commit-boost-client  
**Documentation**: https://commit-boost.github.io/commit-boost-client/  
**Twitter**: https://x.com/Commit_Boost

### Key Features

- ✅ Modular sidecar architecture (built in Rust)
- ✅ MEV-Boost compatible (supports MEV-Boost relays)
- ✅ Supports commitment protocols (preconfirmations, inclusion lists)
- ✅ Plugin system for custom modules
- ✅ Metrics reporting and dashboards
- ✅ Audited by Sigma Prime

### Architecture

Commit-Boost runs as a single sidecar composed of multiple modules:
- Supports MEV-Boost relays
- Supports commitment protocols (preconfirmations, inclusion lists)
- Plugin system for custom modules
- Single API to interact with validators

### Integration Notes

**Can replace or complement MEV-Boost**:
- Fully compatible with MEV-Boost relays
- Additional support for commitment protocols
- Modular architecture allows multiple protocols simultaneously

**Implementation Status**: ❌ Not yet implemented in this project

**Next Steps**: See [Implementation Plan](#implementation-plan) below

---

## ETHGas

### Overview

**ETHGas** is a preconfirmation protocol that enables real-time Ethereum transactions. It integrates with Commit-Boost as a module, allowing validators to sell preconfirmations (precons) - commitments to include transactions in future blocks.

**Repository**: https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module  
**Documentation**: https://docs.ethgas.com/  
**API Documentation**: https://developers.ethgas.com/  
**Twitter**: https://x.com/ETHGASofficial

### Key Features

- ✅ Preconfirmation (precon) protocol for real-time transactions
- ✅ ETHGas Exchange for buying/selling precons
- ✅ Support for standard, SSV, and Obol validators
- ✅ Collateral-based security model
- ✅ Audited by Sigma Prime

### Architecture

**Three Main Components**:

1. **`cb_pbs`**: Similar to MEV-Boost, serves block proposals to validators
2. **`cb_signer`**: Securely generates signatures from validator BLS keys
3. **`cb_ethgas_commit`**: Handles ETHGas registration and preconfirmation selling

**Deployment**: Docker-based using Docker Compose  
**Configuration**: TOML-based configuration files

**Collateral Contracts**:
- Mainnet: `0x3314Fb492a5d205A601f2A0521fAFbD039502Fc3`
- Holesky: `0x104Ef4192a97E0A93aBe8893c8A2d2484DFCBAF1`

### Integration Requirements

**⚠️ Important**: ETHGas **requires Commit-Boost** - it cannot run standalone.

**Architecture**:
```
Validator
    ↓
Commit-Boost (sidecar)
    ├── MEV-Boost Module (relays)
    ├── ETHGas Module (precons)
    └── Other Modules (inclusion lists, etc.)
```

**Implementation Status**: ❌ Not yet implemented in this project

**Next Steps**: See [Implementation Plan](#implementation-plan) below

---

## Profit

### Status

**Not found as a separate project**. Profit maximization may be:
- Integrated into ETHGas Exchange
- Part of other MEV protocols
- A future/planned project
- Research phase only

**Recommendation**: Continue monitoring. ETHGas Exchange already includes profit mechanisms for validators selling precons.

---

## Technology Comparison

| Feature | MEV Boost | Commit Boost | ETHGas |
|---------|-----------|--------------|--------|
| **Production Ready** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Implementation Status** | ✅ Implemented | ❌ Not implemented | ❌ Not implemented |
| **Architecture** | Relay-based | Modular sidecar | Commit-Boost module |
| **MEV-Boost Compatible** | N/A | ✅ Yes | ✅ Yes (via Commit-Boost) |
| **Preconfirmations** | ❌ No | ✅ Yes | ✅ Yes |
| **Inclusion Lists** | ❌ No | ✅ Yes | ❌ No |
| **Dependencies** | None | None | Requires Commit-Boost |
| **Deployment** | Binary | Binary | Docker Compose |
| **Language** | Go | Rust | Rust |
| **Audited** | ✅ Yes | ✅ Yes (Sigma Prime) | ✅ Yes (Sigma Prime) |

---

## Decision Guide

### Use MEV Boost if:
- ✅ You need a production-ready solution **now**
- ✅ You want proven stability and reliability
- ✅ You need comprehensive documentation and community support
- ✅ You want multiple relay options

### Use Commit Boost if:
- ✅ You want MEV-Boost compatibility plus additional protocols
- ✅ You need preconfirmation or inclusion list support
- ✅ You want a modular, extensible architecture
- ✅ You're planning to use ETHGas (requires Commit-Boost)

### Use ETHGas if:
- ✅ You want to sell preconfirmations for additional revenue
- ✅ You need real-time transaction guarantees
- ✅ You're already using Commit-Boost
- ✅ You want collateral-based security

### Combined Approach:
- Use **Commit-Boost** as the sidecar
- Enable **MEV-Boost module** for standard MEV extraction
- Enable **ETHGas module** for preconfirmation revenue
- Get the best of all worlds

---

## Implementation Plan

### Phase 1: Commit Boost Implementation

**Priority**: High (required for ETHGas)

**Tasks**:
1. Research Commit-Boost installation and configuration
2. Create installation script: `install/mev/install_commit_boost.sh`
3. Add configuration variables to `exports.sh`
4. Create systemd service configuration
5. Update client configurations for Commit-Boost integration
6. Test with MEV-Boost relays (compatibility mode)
7. Document integration steps

**Estimated Effort**: 4-8 hours

### Phase 2: ETHGas Implementation

**Priority**: Medium (requires Commit-Boost first)

**Tasks**:
1. Research ETHGas Docker deployment
2. Create installation script: `install/mev/install_ethgas.sh`
3. Add configuration variables to `exports.sh`
4. Set up Docker Compose configuration
5. Configure collateral contracts
6. Integrate with Commit-Boost
7. Test preconfirmation selling
8. Document integration steps

**Estimated Effort**: 6-10 hours

### Phase 3: Testing and Validation

**Tasks**:
1. Test Commit-Boost with MEV-Boost relays
2. Test ETHGas preconfirmation flow
3. Validate combined architecture
4. Performance testing
5. Security review
6. Documentation updates

**Estimated Effort**: 4-6 hours

---

## Quick Reference

### MEV Boost

**Service Management**:
```bash
sudo systemctl start mev
sudo systemctl status mev
journalctl -u mev -f
```

**Verification**:
```bash
curl http://127.0.0.1:18550/eth/v1/builder/status
```

**Validator Registration Check**:
- https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now

### Commit Boost (Planned)

**Port**: `18551` (planned)  
**Service**: `commit-boost` (planned)

### ETHGas (Planned)

**Port**: `18552` (planned)  
**Deployment**: Docker Compose  
**Requires**: Commit-Boost

---

## Troubleshooting

### MEV Boost Issues

**Service not starting**:
```bash
journalctl -u mev -n 100
grep MEV exports.sh
curl https://boost-relay.flashbots.net
```

**No MEV blocks**:
```bash
grep MIN_BID exports.sh  # Check if min-bid is too high
journalctl -u mev -f | grep -i bid
curl https://boost-relay.flashbots.net/eth/v1/builder/status
```

**Validator not registered**:
- Restart validator service
- Check registration at Flashbots validator check page

---

## Resources

### MEV Boost
- Repository: https://github.com/flashbots/mev-boost
- Documentation: https://docs.flashbots.net/
- Wiki: https://github.com/flashbots/mev-boost/wiki

### Commit Boost
- Repository: https://github.com/Commit-Boost/commit-boost-client
- Documentation: https://commit-boost.github.io/commit-boost-client/
- Twitter: https://x.com/Commit_Boost

### ETHGas
- Repository: https://github.com/ethgas-developer/ethgas-preconf-commit-boost-module
- Documentation: https://docs.ethgas.com/
- API Documentation: https://developers.ethgas.com/
- Twitter: https://x.com/ETHGASofficial

### Related
- Builder API: Ethereum Builder API specifications
- PBS: Proposer-Builder Separation
- EIP-4844: Proto-Danksharding

---

*Last Updated: [Current Date]*  
*Document Version: 2.0*  
*Status: Consolidated guide with accurate production-ready information*
