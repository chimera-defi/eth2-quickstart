# Client Test Plan - Full Docker E2E Coverage

## Goal
Test ALL clients (execution, consensus, MEV, web) in Docker CI. Binary download preferred. Builds must work in Docker and complete in <5 min.

## Phase 1: Audit Current Install Methods

| Client | Script | Current Method | Binary Available? |
|--------|--------|----------------|-------------------|
| geth | execution/geth.sh | TBD | |
| besu | execution/besu.sh | download | |
| erigon | execution/erigon.sh | git clone + make | |
| nethermind | execution/nethermind.sh | download | |
| nimbus_eth1 | execution/nimbus_eth1.sh | download | |
| reth | execution/reth.sh | git clone | |
| ethrex | execution/ethrex.sh | download (fallback build) | |
| prysm | consensus/prysm.sh | download | |
| lighthouse | consensus/lighthouse.sh | download | |
| lodestar | consensus/lodestar.sh | npm install | |
| teku | consensus/teku.sh | download | |
| nimbus | consensus/nimbus.sh | download | |
| grandine | consensus/grandine.sh | git clone + cargo | |
| mev-boost | mev/install_mev_boost.sh | download | |
| commit-boost | mev/install_commit_boost.sh | download | |
| ethgas | mev/install_ethgas.sh | git clone + cargo | |
| caddy | web/install_caddy.sh | apt | |
| nginx | web/install_nginx.sh | apt | |

## Phase 2: Changes Made

1. **erigon.sh** - Switched to binary download (erigon_v{V}_linux_amd64.tar.gz)
2. **reth.sh** - Switched to binary download (reth-v{V}-x86_64-unknown-linux-gnu.tar.gz)
3. **grandine.sh** - Switched to binary download (grandine-{V}-amd64 raw binary)
4. **install_dependencies.sh** - When CI_E2E=true, install Node (lodestar) and Rust (ethgas) even in Docker
5. **CI** - Added e2e-client-matrix job (job-level strategy.matrix) with 6 client combos
6. **ci_test_e2e.sh** - Fixed grandine verification path ($HOME/grandine/grandine)

## Attempt Log
| # | Action | Result |
|---|--------|--------|
| 1 | Audit scripts | Done |
| 2 | Switch erigon to binary | Done |
| 3 | Switch reth to binary | Done |
| 4 | Switch grandine to binary | Done |
| 5 | install_deps: Node/Rust in Docker when CI_E2E | Done |
| 6 | Add e2e-client-matrix job | Done |
