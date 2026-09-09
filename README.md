# Ethereum Node Quick Setup

[![CI Build and Test](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/ci.yml/badge.svg)](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/ci.yml)
[![Shell Script Validation](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/shellcheck.yml)
[![Frontend CI](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/frontend.yml/badge.svg)](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/frontend.yml)
[![Security Validation](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/security.yml/badge.svg)](https://github.com/chimera-defi/eth2-quickstart/actions/workflows/security.yml)

Shell scripts that turn a fresh Ubuntu VPS or bare-metal box into a production-ready Ethereum node: security hardening, an execution + consensus client pair, MEV integration, and an optional RPC-facing web server. Supports multiple client combinations for solo stakers, pool operators, and RPC providers who want client diversity.

**🌐 Website & blog:** [eth2quickstart.com](https://eth2quickstart.com) — quick start, supported clients, and the [Ethereum client bake-off](https://eth2quickstart.com/blog/ethereum-client-bakeoff) write-up. Presenting or sharing the blog and slide deck? See the **[Blog & Presentation Guide](docs/BLOG_GUIDE.md)** — deep-link sharing, speaker notes, print-to-PDF, and the live [slide deck](https://eth2quickstart.com/deck/bakeoff.html).

**⚠️ Security notice:** This handles real validator funds. Read a script before you run it — never run scripts you haven't reviewed near sensitive data or keys.

## Quick Start

### Prerequisites

1. A cloud VPS or bare-metal server — recommended 2–4+ TB SSD/NVMe, 16–64+ GB RAM, 4–8+ cores, Ubuntu 20+. Bare metal is preferred; some cloud instances never finish syncing.
2. SSH key access to the server, added *before* you start (`ssh-copy-id root@<ip>`) — Phase 1 disables password login.
3. If your provider asks: set `swraid 1` and `swraidlevel 0` for full disk access.
4. Your SSH fingerprint changes after Phase 1 — remove the old one from `known_hosts` when you reconnect.

Optional: [$20 free Hetzner credit via referral link](https://hetzner.cloud/?ref=d4Hoyi2u3pwn).

### Option A — One-liner bootstrap (recommended for a fresh host)

```bash
curl -fsSL https://raw.githubusercontent.com/chimera-defi/eth2-quickstart/master/install.sh | sudo bash
```

- Auto-detects a non-interactive shell (e.g. piped from `curl`) and falls back to defaults.
- Force non-interactive: add `-s -- --non-interactive`.
- Force the interactive TUI (needs a real TTY): add `-s -- --interactive`.

### Option B — Manual, step by step

1. **Clone and prepare:**
   ```bash
   git clone https://github.com/chimera-defi/eth2-quickstart
   cd eth2-quickstart
   chmod +x run_1.sh
   ```
2. **Run Phase 1 as root** (read the script first — it can bork your server):
   ```bash
   ssh-copy-id root@<your-server-ip>   # do this first, or you'll lock yourself out
   ./run_1.sh
   ```
   Upgrades the OS, hardens the firewall/SSH, enables the Snort IDS profile (disable with `ENABLE_SNORT=false` in `config/user_config.env`), and creates a non-root user carrying your SSH key.
3. **Reboot, then log back in as the new user:**
   ```bash
   sudo reboot
   # ssh eth@<your-server-ip>   (default username)
   ```
4. **Configure and run Phase 2:**
   - Edit `exports.sh` with your settings.
   - Run `./install/utils/select_clients.sh` for client recommendations.
   - Run `./run_2.sh` (or install clients manually — see [Available Ethereum Clients](#available-ethereum-clients)).
5. **Start and check services:**
   ```bash
   ./install/utils/start.sh
   ./install/utils/stats.sh
   ```

**Never chain Phase 1 and Phase 2 (`./run_1.sh && ./run_2.sh`).** The reboot and re-login in between are mandatory — Phase 1 changes the SSH port and disables root login.

### Unified command wrapper

One entrypoint for the common workflows, for humans or agents:

```bash
./scripts/eth2qs.sh help
./scripts/eth2qs.sh configure --non-interactive
./scripts/eth2qs.sh client-options --json
./scripts/eth2qs.sh phase1
./scripts/eth2qs.sh phase2
./scripts/eth2qs.sh monad-install
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh debug --json --service cl
./scripts/eth2qs.sh stats --json
./scripts/eth2qs.sh update-check --json
./scripts/eth2qs.sh monitor export --json
./scripts/eth2qs.sh repair
./scripts/eth2qs.sh restart --smart
```

Validator management (full guide: [docs/VALIDATOR_MANAGEMENT.md](docs/VALIDATOR_MANAGEMENT.md)):

```bash
./scripts/eth2qs.sh validators --json --withdrawal-type 0x01 --min-balance 32
./scripts/eth2qs.sh validator-deploy --num-validators 1 --withdrawal-type 0x02 --withdrawal-address 0xYourAddr
./scripts/eth2qs.sh validator-exit
./scripts/eth2qs.sh validator-withdrawal-changes          # 0x00 -> 0x01 (BLS-to-execution)
./scripts/eth2qs.sh validator-manage --consolidate        # EIP-7251 (0x01 -> 0x02 compounding)
```

- For machine-readable client names and tested presets: `./scripts/eth2qs.sh client-options --json`.
- For machine-readable monitoring, issue classification, and repair previews: `./scripts/eth2qs.sh stats --json`.
- For structured per-service root-cause analysis: `./scripts/eth2qs.sh debug --json --service <name>`.
- For software freshness and repo drift: `./scripts/eth2qs.sh update-check --json`.
- For a compact bot/dashboard summary: `./scripts/eth2qs.sh monitor export --json`.
- For a bounded auto-repair preview/apply path: `./scripts/eth2qs.sh repair` and `./scripts/eth2qs.sh repair --apply --confirm`.

### Service Unit Names (canonical)

Core units, installed by the execution/consensus scripts:
- `eth1.service` — execution client
- `cl.service` — consensus beacon node
- `validator.service` — validator client

MEV units, installed based on your selection:
- `mev.service` — MEV-Boost
- `commit-boost-pbs.service` / `commit-boost-signer.service` — Commit-Boost
- `ethgas.service` — optional, requires Commit-Boost

Web units, optional:
- `nginx.service` / `caddy.service` — reverse proxy

## Sync and Configure

1. **Prysm checkpoint sync is on by default.** `install/consensus/prysm.sh` writes both `checkpoint-sync-url` and `genesis-beacon-api-url` from `$PRYSM_CPURL`, so the beacon node starts from a trusted checkpoint instead of syncing from genesis.
2. **Set up a validator** using the [Prysm validator guide](https://docs.prylabs.network/docs/install/install-with-script#step-5-run-a-validator-using-prysm) — create a `pass.txt` file in `~/prysm` with your wallet password first.
3. **Geth sync timing:** expect 1–3 days running in the background.
4. **MEV setup:** see [MEV Solutions](#mev-solutions) below.

## MEV Solutions

Three MEV (Maximal Extractable Value) solutions are supported. **Choose ONE base solution** — MEV-Boost or Commit-Boost, never both.

| Solution | Type | Best for | Install script |
|----------|------|----------|----------------|
| **MEV-Boost** | Standard | Most users (stable, proven) | `install_mev_boost.sh` |
| **Commit-Boost** | Advanced | Preconfirmations, modular features | `install_commit_boost.sh` |
| **ETHGas** | Add-on | Preconfirmation revenue (requires Commit-Boost) | `install_ethgas.sh` |

**Option A — Standard (recommended):**
```bash
cd install/mev
./install_mev_boost.sh
sudo systemctl start mev
```

**Option B — Advanced (with preconfirmations):**
```bash
cd install/mev
./install_commit_boost.sh
./install_ethgas.sh  # optional
sudo systemctl start commit-boost-pbs commit-boost-signer
sudo systemctl start ethgas  # if installed
```

Ports: MEV-Boost `18550` · Commit-Boost PBS `18550` (drop-in) · Commit-Boost Signer `20000` · ETHGas `18552`.

Full guide: [docs/MEV_GUIDE.md](docs/MEV_GUIDE.md).

## Available Ethereum Clients

### Execution clients

| Client | Language | Best for | Install script |
|--------|----------|----------|-----------------|
| **Geth** | Go | Beginners, stability | `geth.sh` |
| **Erigon** | Go | Performance, fast sync, low memory | `erigon.sh` |
| **Reth** | Rust | Performance, modularity | `reth.sh` |
| **Nethermind** | C# | Enterprise, advanced features | `nethermind.sh` |
| **Besu** | Java | Private networks, compliance | `besu.sh` |
| **Nimbus-eth1** | Nim | Raspberry Pi, low resources | `nimbus_eth1.sh` |
| **Ethrex** | Rust | Testing, client diversity (experimental) | `ethrex.sh` |

### Consensus clients

| Client | Language | Best for | Install script |
|--------|----------|----------|-----------------|
| **Prysm** | Go | Beginners, documentation | `prysm.sh` |
| **Lighthouse** | Rust | Performance, security | `lighthouse.sh` |
| **Teku** | Java | Institutional, monitoring | `teku.sh` |
| **Nimbus** | Nim | Raspberry Pi, low resources | `nimbus.sh` |
| **Lodestar** | TypeScript | Development, TypeScript devs | `lodestar.sh` |
| **Grandine** | Rust | Advanced users, performance | `grandine.sh` |

### Client selection guide

| Priority | Execution | Consensus |
|----------|-----------|-----------|
| Beginners | Geth (stable, well-documented) | Prysm (user-friendly) |
| Performance | Reth or Erigon (fast sync, low resources) | Lighthouse (fast, efficient) |
| Enterprise | Besu, Nethermind, or Nimbus-eth1 | Teku (monitoring, support) |
| Resource-constrained | Erigon (low memory) | Nimbus (lightweight) |

## Configuration Architecture

All configuration lives in `exports.sh`, the single source of truth:

```
exports.sh → base template + your overrides → final client config
```

- Each client has its own template directory, e.g. `configs/teku/teku_beacon_base.yaml` and `configs/teku/teku_validator_base.yaml`.
- Install scripts (e.g. `install/consensus/teku.sh`) merge the base template with your variables from `exports.sh`.
- Key variable groups: user settings (email, domain, fee recipient, graffiti), network settings (peers, ports, relay URLs), client settings (cache sizes, sync modes), and per-client caches (`NETHERMIND_CACHE`, `BESU_CACHE`, `TEKU_CACHE`, etc.).

## System Requirements

| Resource | Minimum | Recommended | Notes |
|----------|---------|--------------|-------|
| CPU | 4 cores | 8+ cores | More cores help with sync |
| RAM | 16 GB | 32 GB+ | Nimbus can run on 8 GB |
| Storage | 2 TB SSD | 4 TB NVMe | Fast storage matters most |
| Network | Stable broadband | Unmetered | Avoid metered connections |

Client-specific: Geth 16 GB RAM / 2 TB SSD · Erigon 8 GB RAM / 1 TB SSD · Reth 16 GB RAM / 2 TB SSD · Nimbus-eth1 4 GB RAM / 500 GB SSD · Prysm 8 GB RAM / 1 TB SSD · Lighthouse 4 GB RAM / 1 TB SSD.

## Web Server (RPC Exposure)

Run your own uncensored, unmetered RPC endpoint for yourself and your community, behind Nginx or Caddy.

### Nginx

```bash
./install/web/install_nginx.sh
./install/ssl/install_acme_ssl.sh
```

Verify:
```bash
# Locally
curl -X POST http://$(curl -s v4.ident.me)/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'

# With a domain
curl -X POST https://yourdomain.com/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'
```

Optional domain setup: get a domain (e.g. Namecheap), point its A record at your server, then let the Nginx install script configure it.

SSL options: `./install/ssl/install_acme_ssl.sh` (recommended) or `./install/ssl/install_ssl_certbot.sh` (Certbot).

### Caddy (alternative to Nginx)

Automatic HTTPS, HTTP/2 and HTTP/3, and security headers built in.

```bash
cd install/web
sudo ./install_caddy.sh
# or, with manual SSL certificates:
sudo ./install_caddy_ssl.sh
```

`install_caddy.sh` automatically runs `install/security/caddy_harden.sh`, which enables the bundled `rate_limit` module and adds fail2ban jails for spam/429s on the Caddy access log — no separate step needed.

| Feature | Caddy | Nginx |
|---------|-------|-------|
| Configuration | Simple Caddyfile | `nginx.conf` |
| HTTPS | Automatic | Manual setup |
| Security headers | Built in | Manual configuration |
| Rate limiting | On by default (`rate_limit` module) | Built in (`limit_req`/`limit_conn`) |
| HTTP/3 | Native | Requires modules |

Both Nginx and Caddy share one edge policy, generated by `install/web/proxy_config_renderer.sh` and tunable in `config/user_config.env`:

| Variable | Purpose |
|----------|---------|
| `EDGE_RPC_UPSTREAMS` / `EDGE_WS_UPSTREAMS` | Comma-separated upstream backends (fanout/failover) |
| `EDGE_LB_POLICY` | `least_conn` or `ip_hash` |
| `EDGE_*_RATE_LIMIT_RPM` / `EDGE_*_BURST` / `EDGE_*_CONN_LIMIT_PER_IP` | Per-route abuse limits (RPC/WS/general) |
| `EDGE_TRUSTED_PROXIES` | Trusted proxy CIDRs for forwarded client IPs |
| `EDGE_ENABLE_METRICS` + `EDGE_METRICS_PATH` | Local-only metrics endpoint (on by default) |
| `CADDY_LB_*` / `CADDY_MAX_FAILS` / `CADDY_FAIL_DURATION` | Caddy retry/failover tuning |
| `CADDY_REQUIRE_RATE_LIMIT` / `CADDY_REQUIRE_DNS_CHALLENGE` | Fail closed if a required Caddy capability is unavailable |

Validate a config:
```bash
bash ./test/validate_review_guardrails.sh
bash ./test/validate_nginx_config.sh
bash ./test/validate_caddy_config.sh
sudo caddy validate --config /etc/caddy/Caddyfile
```

Full Caddy guide: [docs/CADDY_INSTALLATION.md](docs/CADDY_INSTALLATION.md).

## Security Features

- **Network:** UFW firewall with strict rules, fail2ban against brute force, all services bound to localhost by default.
- **Files:** config files at `600`, directories at `700`, sanitized error messages.
- **Monitoring:** real-time threat and suspicious-process detection, automated log rotation.

## Troubleshooting

### Common issues

| Symptom | Fix |
|---------|-----|
| Service not starting | `journalctl -u <service_name>` |
| Sync stalled | Check network connectivity and client status |
| Permission errors | Check file ownership and permissions |
| Port conflicts | Check for other processes on the same port |

### Execution clients

| Client | Cause → Fix |
|--------|-------------|
| **Geth** | Most stable; if it won't start, check for port conflicts on `8545`, `8546`, `30303` |
| **Erigon** | Needs more RAM during sync; check `config.yaml` settings |
| **Reth** | Ships as a prebuilt binary — no local compilation. If the download fails, check the GitHub release for your architecture |
| **Nethermind** | Ships self-contained with its own runtime — no separate .NET install needed. If it won't start, check the install log for the release archive it fetched |
| **Besu** | Java heap size issues — adjust memory settings in the service file |
| **Nimbus-eth1** | Check the [GitHub releases page](https://github.com/status-im/nimbus-eth1/releases) for the latest build if install fails |

### Consensus clients

| Client | Cause → Fix |
|--------|-------------|
| **Prysm** | Checkpoint sync failing → update `PRYSM_CPURL` in `exports.sh` |
| **Lighthouse** | Ships as a prebuilt binary — no local compilation needed |
| **Teku** | Java out of memory → increase heap size in the service file |
| **Nimbus** | Designed for low-resource systems — resource errors likely mean a config issue, not underpowered hardware |
| **Lodestar** | Ships as a prebuilt binary — no local Node.js/npm install needed |
| **Grandine** | Newest client here — check [upstream docs](https://github.com/grandinetech/grandine) for recent changes |

### Getting help

1. Check service logs: `journalctl -u <service_name> -f`
2. Verify configuration: `./docs/verify_security.sh`
3. Review the [`docs/`](docs/) directory
4. Re-check [System Requirements](#system-requirements)
5. Open a [GitHub issue](https://github.com/chimera-defi/eth2-quickstart/issues) or [discussion](https://github.com/chimera-defi/eth2-quickstart/discussions)

## Network-Specific Setup

### Testnets (Sepolia/Holesky)

Before running the client install scripts:
- Update the checkpoint URL in `exports.sh` for your target testnet.
- Add the matching network flag to client commands (e.g. `--sepolia`, `--holesky`) — check each client's own `--help`, since supported testnets and flag names shift as networks are deprecated (Goerli is retired).
- Use testnet-specific genesis and checkpoint files, not mainnet ones.

### Mainnet optimization

- Enable checkpoint sync for a fast initial sync.
- Configure MEV-Boost (or Commit-Boost) with multiple relays.
- Size caches to your available RAM.
- Use fast NVMe storage.

## Agent & Automation Integration

For agent integrations, the published skill source lives at `skills/eth2-quickstart/`, meant to be used from inside an `eth2-quickstart` checkout. Entry point: [`skills/eth2-quickstart/SKILL.md`](skills/eth2-quickstart/SKILL.md) (operator, sizing, safety, and improvement references). This is a repo-backed operations skill, not a standalone package.

```bash
# once published
clawhub install eth2-quickstart

# fallback: local workspace
git clone --depth 1 https://github.com/chimera-defi/eth2-quickstart.git
cd eth2-quickstart
```

- Raw-ingest fallback for agents that load a text URL directly: [`llms.txt`](./llms.txt) and [`llms-full.txt`](./llms-full.txt)
- Codex fallback: `python ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py --repo chimera-defi/eth2-quickstart --path skills/eth2-quickstart`
- Native tool fallback for Claude Code / Codex via MCP: [`mcp_server/run_eth2qs_mcp.sh`](mcp_server/run_eth2qs_mcp.sh) and [`skills/eth2-quickstart/references/mcp.md`](skills/eth2-quickstart/references/mcp.md)
- Claude plugin packaging for local validation and marketplace-style install: [`.claude-plugin/`](./.claude-plugin/) and [`.claude/settings.json`](./.claude/settings.json)

MCP quickstart:
```bash
python3 -m pip install mcp
codex mcp add eth2-quickstart ./mcp_server/run_eth2qs_mcp.sh
# or: claude mcp add eth2-quickstart -- ./mcp_server/run_eth2qs_mcp.sh
# or: ./scripts/install_claude_eth2qs_mcp.sh
```

The MCP server exposes the core lifecycle directly: Phase 1 hardening, Phase 2 client install, planner-driven install, health checks, logs, and safe cleanup. For validator inventory and filtering, use the read-only MCP tool `eth2qs_validators` (filters: `min_balance`/`max_balance` ETH, `withdrawal_type` 0x00/0x01/0x02, `status`). Funds-affecting operations (exit, withdrawal-credential change, consolidation, EIP-7002 exit, deploy) are exposed read-only via `eth2qs_validator_op_preview`, which returns the exact CLI command to run — they are **never executed via MCP**. Run those on the node CLI, where they prompt for confirmation. Full guide: [`docs/VALIDATOR_MANAGEMENT.md`](docs/VALIDATOR_MANAGEMENT.md). For the full command surface and safety rules, start with [`skills/eth2-quickstart/SKILL.md`](skills/eth2-quickstart/SKILL.md).

## Why This Project Exists

The goal: let sovereign individuals run independent validators on their own hardware, in their own location, free of censorship — and, by using a VPS, offer a censorship-resistant RPC node to fellow Ethereum users rather than exposing a home connection to the world.

## Benefits

- **Client diversity**, guided by an interactive selector with recommendations
- **Security hardening** built in — firewall, fail2ban, real-time monitoring
- **One command** from bare server to running validator, with MEV-Boost integration for rewards
- **Your own uncensored, unmetered RPC endpoint** — for you and your community
- **Infra-friendly by default** — firewall rules and settings tuned to avoid provider abuse alerts

## Credits

This was made possible by the guides written by Somersat and CoinCashew, and by the beacon checkpoint states Sharedstake.org makes available and hosts for its community.

- **Somersat:** https://someresat.medium.com/guide-to-staking-on-ethereum-ubuntu-prysm-581fb1969460?utm_source=substack&utm_medium=email
- **CoinCashew:** https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client
- **Sharedstake.org:** https://Sharedstake.org
- **Sharedtools.org:** https://sharedtools.org

## Contact for Questions / Collaboration

- **Email:** Chimera_defi@protonmail.com
- **Twitter:** https://twitter.com/chimeradefi
- **Issues:** [GitHub Issues](https://github.com/chimera-defi/eth2-quickstart/issues)
- **Discussions:** [GitHub Discussions](https://github.com/chimera-defi/eth2-quickstart/discussions)

## Additional Documentation

- Canonical docs index: [docs/README.md](docs/README.md)
- Current status and open gaps: [docs/STATUS.md](docs/STATUS.md)
- Script reference: [docs/SCRIPTS.md](docs/SCRIPTS.md)
- Agent skill listing copy: [docs/AGENT_SKILL_LISTING.md](docs/AGENT_SKILL_LISTING.md)
- Frontend docs: [docs/FRONTEND.md](docs/FRONTEND.md) and [frontend/README.md](frontend/README.md)
- Session continuity and follow-ups: [docs/agent-handoff.md](docs/agent-handoff.md)
- Common functions reference: [docs/COMMON_FUNCTIONS_REFERENCE.md](docs/COMMON_FUNCTIONS_REFERENCE.md)
