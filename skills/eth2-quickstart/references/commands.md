# Commands

Canonical command surface:

- Bootstrap repo install: `./scripts/eth2qs.sh bootstrap --non-interactive`
- Configure scripts: `./scripts/eth2qs.sh configure --non-interactive`
- Detect the next safe install step: `./scripts/eth2qs.sh plan --json`
- List supported clients and tested presets: `./scripts/eth2qs.sh client-options --json`
- Preview/apply the next safe step: `./scripts/eth2qs.sh ensure` or `./scripts/eth2qs.sh ensure --apply --confirm`
- Run Phase 1 hardening: `sudo ./scripts/eth2qs.sh phase1`
- Run Phase 2 install: `./scripts/eth2qs.sh phase2 --execution=geth --consensus=prysm --mev=mev-boost`
- Run explicit Monad install: `./scripts/eth2qs.sh monad-install`
- Health/status: `./scripts/eth2qs.sh doctor --json`
- Monitoring/triage: `./scripts/eth2qs.sh stats --json`
- Structured service debug: `./scripts/eth2qs.sh debug --json --service cl`
- Update freshness / repo drift: `./scripts/eth2qs.sh update-check --json`
- Compact monitor summary: `./scripts/eth2qs.sh monitor export --json`
- Save a monitor snapshot: `./scripts/eth2qs.sh monitor snapshot --json`
- Review recent monitor history: `./scripts/eth2qs.sh monitor history --json --limit 5`
- Smart repair preview/apply: `./scripts/eth2qs.sh repair` or `./scripts/eth2qs.sh repair --apply --confirm`
- Human-readable status: `./scripts/eth2qs.sh status`
- Start services: `./scripts/eth2qs.sh start`
- Stop services: `./scripts/eth2qs.sh stop`
- Restart services: `./scripts/eth2qs.sh restart` or `./scripts/eth2qs.sh restart --smart`
- Service/system stats: `./scripts/eth2qs.sh stats`
- View logs: `./scripts/eth2qs.sh logs --run2 -n 200`
- Clean default data dirs only: `./scripts/eth2qs.sh clean-data --dry-run`
- Confirm cleanup after review: `./scripts/eth2qs.sh clean-data --confirm`
- Host cleanup for stale root-managed installs: `sudo ./scripts/eth2qs.sh cleanup-host --dry-run`
- Confirm host cleanup after review: `sudo ./scripts/eth2qs.sh cleanup-host --confirm`
- Update installed components: `./scripts/eth2qs.sh update-all`

Prefer these commands over direct utility-script paths unless a task specifically needs the lower-level script.

## cli-anything-eth2-quickstart (Python Harness)

An alternative agent-native entrypoint for runtimes that prefer a structured Python CLI over raw shell. Install from `eth2-quickstart/agent-harness/`:

```bash
pip install -e eth2-quickstart/agent-harness/
```

Key commands (always pass `--json` for agent parsing):

```bash
# Machine-readable health
cli-anything-eth2-quickstart --json health-check

# Phase 2 install with explicit client choices
cli-anything-eth2-quickstart --json install-clients \
  --network mainnet \
  --execution-client geth \
  --consensus-client lighthouse \
  --mev mev-boost \
  --confirm

# Guided node setup (auto-detects phase)
cli-anything-eth2-quickstart --json setup-node \
  --phase auto \
  --execution-client geth \
  --consensus-client prysm \
  --mev commit-boost \
  --confirm

# Validator metadata (no key import)
cli-anything-eth2-quickstart --json configure-validator \
  --consensus-client prysm \
  --fee-recipient 0x1111111111111111111111111111111111111111 \
  --graffiti "my-node"

# RPC exposure
cli-anything-eth2-quickstart --json start-rpc \
  --web-stack nginx \
  --server-name rpc.example.org \
  --confirm
```

Discovers repo root from `--repo-root` flag → `ETH2QS_REPO_ROOT` env var → current directory. Prefer the `./scripts/eth2qs.sh` surface for direct shell use; use the Python harness when your agent runtime needs structured argument parsing or a REPL-style interface.
