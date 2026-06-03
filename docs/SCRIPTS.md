# Scripts Reference

## Overview

Bash scripts to harden Ubuntu server and install Ethereum node stack: execution client, consensus client, validator, MEV tooling, and optional Nginx/Caddy reverse proxy with SSL.

- **OS**: Ubuntu 20.04+
- **Order**: `run_1.sh` → reboot → login as `LOGIN_UNAME` → update `exports.sh` → `run_2.sh`
- **Config**: `exports.sh` (email, domain, fee recipient, graffiti, peers, relay list, ports)

## Repo Maintenance Automation

For upstream review tracking (for example CLI-Anything harness PRs), use:

```bash
./scripts/check-cli-anything-pr.sh
./scripts/install-cli-anything-pr-watch-cron.sh
./scripts/uninstall-cli-anything-pr-watch-cron.sh
./status/poll_ci.sh
```

Defaults now target the local active PR (`chimera-defi/eth2-quickstart` PR `167`).
Override target PR with `--repo` and `--pr` when needed.

`check-cli-anything-pr.sh` stores state under `~/.eth2qs-pr-watch/`, reports new actionable feedback, and can optionally trigger an autofix command.
`install-cli-anything-pr-watch-cron.sh` installs an idempotent daily cron entry that runs the check script, appends logs to `~/.eth2qs-pr-watch/cron.log`, and auto-removes itself when the watched PR closes/merges.
`uninstall-cli-anything-pr-watch-cron.sh` removes existing watch entries by cron marker.
`status/poll_ci.sh` snapshots open PR CI/review state into `status/ci-summary.json` and runs one PR-watch check each poll cycle.

## Unified Wrapper (Recommended)

Use `scripts/eth2qs.sh` as a stable command entrypoint for both humans and AI agents.

```bash
./scripts/eth2qs.sh help
./scripts/eth2qs.sh configure --non-interactive
./scripts/eth2qs.sh client-options --json
./scripts/eth2qs.sh phase1
./scripts/eth2qs.sh phase2
./scripts/eth2qs.sh doctor --json
./scripts/eth2qs.sh debug --json --service cl
./scripts/eth2qs.sh stats --json
./scripts/eth2qs.sh update-check --json
./scripts/eth2qs.sh monitor export --json
./scripts/eth2qs.sh repair
./scripts/eth2qs.sh restart --smart
```

`stats --json` is the machine-readable monitoring surface. It summarizes service states, recent journal-derived failure modes, planner/doctor context, and bounded repair previews without making changes.
`debug --json` is the structured RCA surface. It adds per-service unit metadata, recent log tails, main PID, and listen socket hints.
`update-check --json` compares installed client versions and repo drift against the latest known upstream release tags.
`monitor export --json` is the compact summary surface for bots, dashboards, cron jobs, or alert relays, and `monitor snapshot` writes a local history entry under `~/.eth2qs-monitor/`.
`repair` is the bounded apply surface. It previews allowlisted targeted restarts by default and requires `--apply --confirm` before making changes.

Validator helpers:
- `./scripts/eth2qs.sh validator-exit` for the focused exit checklist and client-specific voluntary exit flow.
- `./scripts/eth2qs.sh validator-create-0x02` for the 0x02 entry checklist and deposit CLI launcher.
- `./scripts/eth2qs.sh validator-manage` for the combined exit / consolidation menu.

## Environment Configuration (exports.sh)

Key variables:
- `EMAIL`: Contact email for ACME/cert tooling
- `LOGIN_UNAME`: Non-root user to create (default `eth`)
- `YourSSHPortNumber`: SSH port for fail2ban (default `22`)
- `SERVER_NAME`: Domain for Nginx/SSL (e.g. `rpc.example.com`)
- `FEE_RECIPIENT`: 0x address for priority fees
- `GRAFITTI`: String added to blocks
- `MAX_PEERS`: Consensus client peer cap
- `GETH_CACHE`: Geth cache size in MB (default `8192`)
- `MEV_RELAYS`: Comma-separated MEV-Boost relay URLs
- `ENABLE_SNORT`: Optional Snort IDS profile toggle (`false` by default)
- `SNORT_INTERFACE` / `SNORT_HOME_NET`: Optional Snort capture interface and CIDR scope

## Stage 1: Initial Hardening (run_1.sh)

**Run with sudo (or as root):**
```bash
sudo ./run_1.sh
# Or: ./run_1.sh  (re-execs with sudo if not root)
sudo reboot
ssh LOGIN_UNAME@<server-ip>
```

**Actions:**
- System updates: `apt update/upgrade/full-upgrade/autoremove`
- SSH hardening: replaces `/etc/ssh/sshd_config`
- Fail2ban: configures jails for `nginx-proxy` and `sshd`
- User creation: creates non-root user `LOGIN_UNAME` (SSH key-only, no password)
- Backs up and migrates authorized_keys from root, SUDO_USER, and all /home/* users to new user (prevents lockout)
- Copies eth2-quickstart to `~/eth2-quickstart` for new user (handoff: `cd ~/eth2-quickstart && ./run_2.sh`)
- Security: runs consolidated security script
- IDS: Snort is enabled by default; set `ENABLE_SNORT=false` to disable
- NTP: installs `chrony` and enables NTP
- Security: mounts `/run/shm` as `tmpfs` with `ro,noexec,nosuid`

**Prerequisite:** Add your SSH key before running: `ssh-copy-id root@<server>` or `ssh-copy-id <your-user>@<server>` (if using sudo)

## Stage 2: Client Installation (run_2.sh)

**Run as non-root user:**
```bash
./run_2.sh
```

**Actions:**
- Installs `snapd`
- Verifies client configuration path resolution (`install/utils/verify_client_configs.sh`)
- Runs selected installers from:
  - `install/execution/<client>.sh`
  - `install/consensus/<client>.sh`
  - `install/mev/install_mev_boost.sh` or `install/mev/install_commit_boost.sh`
  - optional `install/mev/install_ethgas.sh` (requires Commit-Boost)
- Echoes next steps for Nginx + SSL

**Start services:**
```bash
./install/utils/start.sh
./install/utils/stats.sh
./scripts/eth2qs.sh stats --json
./scripts/eth2qs.sh monitor export --json
```

## Logs

run_1.sh and run_2.sh write logs to disk. View them with:
```bash
./install/utils/view_logs.sh [--list|--run1|--run2|--security] [-n N] [-f]
```
- `--list` – list all logs
- `--run1` – latest run_1.sh log (in /var/log/eth2-quickstart)
- `--run2` – latest run_2.sh log (in ~/eth2-quickstart/logs)
- `--security` – latest security validation log
- `-n N` – last N lines (default 50)
- `-f` – follow (tail -f)

## Client Installation Scripts

### Execution Clients

#### geth.sh
- **Language: Go**
- Adds `ppa:ethereum/ethereum` and installs Geth
- Builds `GETH_CMD` with flags:
  - `--syncmode snap`, `--cache $GETH_CACHE`
  - HTTP/WS: `--http`, `--http.corsdomain "*"`, `--http.vhosts=*`, `--http.api "admin, eth, net, web3, engine"`
  - WS: `--ws`, `--ws.origins "*"`, `--ws.api "web3, eth, net, engine"`
  - Auth RPC: `--authrpc.jwtsecret=$HOME/secrets/jwt.hex`
  - Miner: `--miner.etherbase=$FEE_RECIPIENT`, `--miner.extradata=$GRAFITTI`
- Creates systemd unit `eth1.service`

#### erigon.sh
- **Language: Go**
- Downloads and installs Erigon
- Configures with typical flags
- Creates systemd unit `eth1.service`

#### reth.sh
- **Language: Rust**
- Downloads and installs Reth
- Configures with typical flags
- Creates systemd unit `eth1.service`

#### nethermind.sh
- **Language: C# (.NET)**
- Downloads and installs Nethermind
- Configures with typical flags
- Creates systemd unit `eth1.service`

#### besu.sh
- **Language: Java**
- Downloads and installs Besu
- Configures with typical flags
- Creates systemd unit `eth1.service`

#### nimbus_eth1.sh
- **Language: Nim**
- Downloads and installs Nimbus-eth1 (nightly builds)
- Lightweight Nim-based execution client
- Configures with TOML configuration file
- Creates systemd unit `eth1.service`

#### ethrex.sh
- **Language: Rust**
- Downloads and installs Ethrex
- Configures with typical flags
- Creates systemd unit `eth1.service`

### Consensus Clients

#### prysm.sh
- **Language: Go**
- Creates `~/prysm`, downloads `prysm.sh`, generates `jwt.hex`
- Generates config files:
  - `prysm_validator_conf.yaml`: sets `graffiti`, `suggested-fee-recipient`, `wallet-password-file`
  - `prysm_beacon_conf.yaml`: sets `graffiti`, `suggested-fee-recipient`, `p2p-host-ip`, `p2p-max-peers`, `checkpoint-sync-url`, `genesis-beacon-api-url`, `jwt-secret`
- **Updated Configuration Features (v6.1.2)**:
  - Performance: `max-goroutines`, `block-batch-limit`, `slots-per-archive-point`
  - Monitoring: Prometheus metrics on port 8080
  - MEV boost: Configured to use external MEV-Boost
  - Reliability: `dynamic-key-reload-debounce-interval`, `enable-doppelganger`
- Creates systemd units `cl.service` and `validator.service`

#### lighthouse.sh
- **Language: Rust**
- Downloads and installs Lighthouse
- Configures with typical flags
- Creates systemd units `cl.service` and `validator.service`

#### teku.sh
- **Language: Java**
- Downloads and installs Teku
- Configures with typical flags
- Creates systemd units `cl.service` and `validator.service`

#### nimbus.sh
- **Language: Nim**
- Downloads and installs Nimbus
- Configures with typical flags
- Creates systemd units `cl.service` and `validator.service`

#### lodestar.sh
- **Language: TypeScript**
- Downloads and installs Lodestar
- Configures with typical flags
- Creates systemd units `cl.service` and `validator.service`

#### grandine.sh
- **Language: Rust**
- Downloads and installs Grandine
- Configures with typical flags
- Creates systemd units `cl.service` and `validator.service`

### MEV Solutions

⚠️ **IMPORTANT**: MEV-Boost and Commit-Boost are mutually exclusive - choose ONE!

#### install_mev_boost.sh (RECOMMENDED)
- Clones and builds MEV-Boost from Flashbots repository
- Configures with relay URLs from `MEV_RELAYS`
- Creates systemd unit `mev.service`
- Port: 18550

#### install_commit_boost.sh
- Downloads pre-built Commit-Boost binaries (PBS + Signer)
- Modular sidecar with MEV-Boost relay compatibility
- Supports preconfirmations and inclusion lists
- Creates systemd units: `commit-boost-pbs.service`, `commit-boost-signer.service`
- Ports: PBS (18550, same as MEV-Boost), Signer (20000), Metrics (10000+)

#### install_ethgas.sh
- Clones and builds ETHGas preconfirmation module
- **Requires Commit-Boost** to be installed first
- Enables validators to sell preconfirmations
- Creates systemd unit `ethgas.service`
- Ports: Main (18552), Metrics (18553)

#### test_mev_implementations.sh
- Comprehensive test suite for all MEV implementations
- Tests installation, configuration, services, ports, and dependencies
- Verifies mutual exclusivity between MEV-Boost and Commit-Boost

#### fb_builder_geth.sh (Advanced)
- Builds Geth from Flashbots builder repository
- For advanced users running block builders

#### fb_mev_prysm.sh (Advanced)
- Builds Prysm from Flashbots repository with MEV support
- For advanced users with custom MEV setups

## Nginx and SSL Scripts

### install_nginx.sh
- Installs Nginx
- Configures reverse proxy for RPC/WS endpoints
- Sets up rate limiting and security headers

### install_acme_ssl.sh / install_ssl_certbot.sh
- Installs SSL certificates (ACME.sh or Certbot flow)
- Configures HTTPS redirect
- Sets up certificate renewal

## Extra Utilities

### select_clients.sh
- Interactive client selection
- Provides recommendations based on use case
- Updates `exports.sh` with selected clients

### purge_ethereum_data.sh
- See [Data Management](#data-management) for scope and safety guarantees.

## Security Utilities

### test_security_fixes.sh
- Tests all implemented security fixes
- Validates network exposure, input validation, file permissions
- Provides security score and recommendations

### docs/verify_security.sh
- Comprehensive security verification
- Checks all security implementations
- Provides detailed security report

### docs/validate_security_safe.sh
- Safe validation without root privileges
- Validates security implementations
- Provides security score

## Systemd Units

### eth1.service
- Execution client service
- Depends on network.target
- Restart on failure

### cl.service
- Consensus client service
- Depends on eth1.service
- Restart on failure

### validator.service
- Validator service
- Depends on cl.service
- Restart on failure

### mev.service
- MEV-Boost service (standard)
- Port 18550
- Restart on failure

### commit-boost-pbs.service
- Commit-Boost PBS module
- MEV-Boost compatible relay interface
- Port 18550 (drop-in for MEV-Boost)
- Restart on failure

### commit-boost-signer.service
- Commit-Boost Signer module
- BLS key signing for commitments
- Port 20000
- Restart on failure

### ethgas.service
- ETHGas preconfirmation service
- Requires Commit-Boost services
- Port 18552 (metrics 18553)
- Restart on failure

### nginx.service
- Nginx reverse proxy service
- Optional (web RPC/SSL setup)
- Restart on failure

### caddy.service
- Caddy reverse proxy service
- Optional alternative to Nginx
- Restart on failure

## Networking and Ports

### Required Ports
- **30303**: Execution client P2P
- **13000/tcp**: Consensus client P2P
- **12000/udp**: Consensus client P2P
- **22/tcp**: SSH
- **443/tcp**: HTTPS (if using Nginx)

### Protected Ports
- **4000/tcp**: Engine API
- **3500/tcp**: Beacon API
- **8551/tcp**: Engine API
- **8545/tcp**: JSON-RPC

## Data Management

### purge_ethereum_data.sh
- Removes default Ethereum data/state directories
- Preserves key/secret paths (including `~/secrets` and validator keystores)
- Does not touch custom non-default datadirs
- Useful for fresh starts

### Data Directories
- **Geth**: `~/.ethereum`
- **Erigon**: `~/.local/share/erigon`
- **Reth**: `~/.local/share/reth`
- **Ethrex**: `~/ethrex/data`
- **Prysm**: `~/.local/share/prysm`
- **Lighthouse**: `~/.lighthouse`
- **Teku**: `~/.local/share/teku`
- **Nimbus**: `~/.local/share/nimbus`
- **Lodestar**: `~/.local/share/lodestar`
- **Grandine**: `~/.local/share/grandine`
- **Commit-Boost**: `~/commit-boost`
- **ETHGas**: `~/ethgas`

## Troubleshooting

### Logs
- **System logs**: `journalctl -u service_name -f`
- **Security logs**: `/var/log/security_monitor.log`
- **Fail2ban logs**: `/var/log/fail2ban.log`

### Getting Help
For issue triage patterns and client-specific troubleshooting, see [README.md](../README.md#troubleshooting).
