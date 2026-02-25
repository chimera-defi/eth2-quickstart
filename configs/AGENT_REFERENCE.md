# Configuration Agent Reference

## Configuration Architecture Overview

This directory contains base configuration templates for all Ethereum clients. The configuration system follows a standardized pattern:

### Configuration Flow
```
exports.sh → Base Template + Custom Variables → Final Client Config
```

### Directory Structure
- `besu/` - Besu client configurations (TOML format)
- `grandine/` - Grandine client configurations
- `lodestar/` - Lodestar client configurations (JSON format)
- `nethermind/` - Nethermind client configurations
- `nimbus/` - Nimbus client configurations (TOML format)
- `prysm/` - Prysm client configurations (YAML format)
- `teku/` - Teku client configurations (YAML format)

### Key Principles
1. **Base Templates**: Static configuration files with placeholders
2. **Variable Substitution**: User-specific values from `exports.sh`
3. **Consistent Naming**: All clients follow similar configuration patterns
4. **Documentation**: Each config directory should have clear documentation

### For AI Agents
When working with configurations:
- **Read**: `docs/CONFIGURATION_GUIDE.md` for detailed architecture
- **Follow**: Template + custom variable pattern
- **Maintain**: Consistency across all client configurations
- **Update**: Both base templates and documentation when making changes

### Configuration Variables
Key variables are defined in `exports.sh`:
- Client-specific memory settings (e.g., `TEKU_CACHE`, `NIMBUS_CACHE`)
- Port configurations (e.g., `TEKU_REST_PORT`, `NIMBUS_REST_PORT`)
- Checkpoint URLs for fast sync
- Universal settings (e.g., `FEE_RECIPIENT`, `GRAFITTI`)
- Prysm-specific settings (e.g., `PRYSM_CPURL`, `USE_PRYSM_MODERN`)

### Recent Updates
- **Prysm v6.1.2 Configuration**: Updated with performance optimizations, monitoring capabilities, and deprecated flag fixes
- **Monitoring**: Added Prometheus metrics on port 8080 (beacon node)
- **Performance**: Added `max-goroutines`, `block-batch-limit`, and `slots-per-archive-point` flags
- **MEV Boost**: Configured to use external MEV-Boost (local builder disabled)

### Config Maintenance (Last Verified: 2025-02)

When updating configs, verify against current client docs and remove deprecated options:

| Client | Config Format | Key Docs |
|--------|---------------|----------|
| Besu | TOML | [besu.hyperledger.org](https://besu.hyperledger.org/stable/public-networks/how-to/configuration-file) |
| Nethermind | JSON (.cfg) | [docs.nethermind.io](https://docs.nethermind.io/fundamentals/configuration) |
| Nimbus | TOML | [nimbus.guide](https://nimbus.guide/) — REST API (JSON-RPC deprecated v22.6+) |
| Prysm | YAML | [docs.prylabs.network](https://docs.prylabs.network/docs/configure-prysm/) |
| Teku | YAML | [docs.teku.consensys.io](https://docs.teku.consensys.io/reference/cli) |
| Lodestar | JSON | [chainsafe.github.io/lodestar](https://chainsafe.github.io/lodestar/) |
| Grandine | TOML | [docs.grandine.io](https://docs.grandine.io/cli_options.html) |
| Commit-Boost | TOML | [commit-boost.github.io](https://commit-boost.github.io/commit-boost-client/get_started/configuration/) |

**Current standards:**
- **Besu**: BONSAI + SNAP default (24.3+); Forest deprecated path
- **Nimbus**: Use REST API (`rest = true`); JSON-RPC removed v22.6+
- **Prysm**: `min-builder-bid` in Gwei (2e6 = 0.002 ETH)
- **Nethermind**: SnapSync enabled by default; Merge.TerminalTotalDifficulty kept for config compatibility

Refer to `docs/CONFIGURATION_GUIDE.md` for complete configuration architecture details.