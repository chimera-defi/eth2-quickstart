### Scripts overview

This repository contains Bash scripts to harden an Ubuntu server and install an Ethereum node stack: execution client (Geth/Erigon/Reth), consensus client (Prysm/Lighthouse), validator, MEV-Boost, and optional Nginx reverse proxy with SSL.

- Expected OS: Ubuntu 20.04+
- Run order: `run_1.sh` → reboot → login as `LOGIN_UNAME` → update `exports.sh` → `run_2.sh`
- Central configuration: `exports.sh` (email, domain, fee recipient, graffiti, peers, relay list, ports)

### Environment configuration (exports.sh)

`exports.sh` defines environment variables used across scripts:

- `EMAIL`: Contact email, used by ACME/cert tooling
- `LOGIN_UNAME`: Non-root user to create (default `eth`)
- `YourSSHPortNumber`: SSH port used by fail2ban jail (default `22`)
- `maxretry`: fail2ban retry threshold
- `REPO_NAME`: Repo folder name (default `eth2-quickstart`)
- `SERVER_NAME`: Domain for Nginx/SSL (e.g. `rpc.example.com`)
- `FEE_RECIPIENT`: 0x address to receive priority fees via validator/CL
- `GRAFITTI`: String added to blocks by the validator/client
- `MAX_PEERS`: Consensus client peer cap
- `PRYSM_CPURL`: Prysm checkpoint sync and genesis API base URL
- `USE_PRYSM_MODERN`, `PRYSM_ALLOW_UNVERIFIED_BINARIES`: Prysm flags
- `LH`: Host for Geth HTTP/WS (default `127.0.0.1`)
- `GETH_CACHE`: Geth cache size in MB (default `8192`)
- `MEV_RELAYS`: Comma-separated MEV-Boost relay URLs
- `MIN_BID`, `MEVGETHEADERT`, `MEVGETPAYLOADT`, `MEVREGVALT`: MEV-Boost tuning

Update these before running `run_2.sh`.

### Stage 1: Initial hardening and base setup

`run_1.sh`
- Sources `./exports.sh`
- System updates: `apt update/upgrade/full-upgrade/autoremove`
- SSH hardening: replaces `/etc/ssh/sshd_config` with repo version (`./sshd_config`), backs up original to `/etc/ssh/sshd_config.bkup`, copies active config into repo for review
- Installs and configures fail2ban with jails for `nginx-proxy` and `sshd` using `YourSSHPortNumber` and `maxretry`
- Creates non-root user `LOGIN_UNAME`, sets up SSH keys, adds to `sudo`
- Copies the repo into `/home/LOGIN_UNAME/REPO_NAME` and makes scripts executable/owned by the user
- Runs `./firewall.sh`
- Installs `chrony` and enables NTP via `timedatectl`
- Appends a line to `/etc/fstab` to mount `/run/shm` as `tmpfs` with `ro,noexec,nosuid`
- Prints network checks: `ss -tulpn`, `sshd -t`, `ufw status`
- Pauses for manual steps:
  - Review outputs; continue
  - In a separate shell, run `visudo` to add `LOGIN_UNAME ALL=(ALL) NOPASSWD: ALL`
  - Set password for `LOGIN_UNAME`
- Prompts to reboot. After reboot, SSH as `LOGIN_UNAME` and proceed to stage 2

Usage (run as root):
```bash
sudo ./run_1.sh
sudo reboot
ssh LOGIN_UNAME@<server-ip>
```

`firewall.sh`
- Installs and configures UFW
- Defaults: deny incoming, allow outgoing
- Allows: `30303` (EL p2p), `13000/tcp` and `12000/udp` (CL p2p), `ssh`, `22/tcp`, `443/tcp`
- Denies outbound connections to private/reserved address ranges to prevent network scan abuse
- Denies inbound to `4000/tcp`, `3500/tcp`, `8551/tcp`, `8545/tcp` (protects Engine/JSON-RPC)
- Enables UFW

### Stage 2: Client installation and services

`run_2.sh` (run as the non-root `LOGIN_UNAME`)
- Sources `./exports.sh`
- Installs `snapd`
- Runs installers: `./install_geth.sh`, `./install_prysm.sh`, `./install_mev_boost.sh`
- Echoes next steps for Nginx + SSL

Start services after install:
```bash
sudo systemctl start eth1
sudo systemctl start cl
sudo systemctl start validator
sudo systemctl start mev
```

`install_geth.sh`
- Adds `ppa:ethereum/ethereum` and installs Geth
- Builds `GETH_CMD` with typical flags:
  - `--syncmode snap`, `--cache $GETH_CACHE`
  - HTTP/WS enabled: `--http`, `--http.corsdomain "*"`, `--http.vhosts=*`, `--http.api "admin, eth, net, web3, engine"`
  - WS: `--ws`, `--ws.origins "*"`, `--ws.api "web3, eth, net, engine"`
  - Auth RPC: `--authrpc.jwtsecret=$HOME/secrets/jwt.hex`
  - Miner labels: `--miner.etherbase=$FEE_RECIPIENT`, `--miner.extradata=$GRAFITTI`
- Creates systemd unit `eth1.service` with `ExecStart=$(GETH_CMD)` and enables it

`install_prysm.sh`
- Creates `~/prysm`, downloads `prysm.sh`, and generates `jwt.hex` → moves to `~/secrets`
- Generates Prysm config files by merging repo defaults with user overrides:
  - `prysm_validator_conf.yaml`: sets `graffiti`, `suggested-fee-recipient`, `wallet-password-file`
  - `prysm_beacon_conf.yaml`: sets `graffiti`, `suggested-fee-recipient`, `p2p-host-ip`, `p2p-max-peers`, `checkpoint-sync-url`, `genesis-beacon-api-url`, `jwt-secret`
- **Updated Configuration Features (v6.1.2)**:
  - Performance optimizations: `max-goroutines`, `block-batch-limit`, `slots-per-archive-point`
  - Monitoring: Prometheus metrics on port 8080 (beacon node)
  - MEV boost: Configured to use external MEV-Boost (local builder disabled)
  - Reliability: `dynamic-key-reload-debounce-interval`, `enable-doppelganger`
- Creates systemd units and enables them:
  - `cl.service` (beacon chain) runs `prysm.sh beacon-chain --config-file=~/prysm/prysm_beacon_conf.yaml`
  - `validator.service` runs `prysm.sh validator --config-file=~/prysm/prysm_validator_conf.yaml`

`install_mev_boost.sh`
- Installs Go via Snap, builds Flashbots `mev-boost` from source (stable branch)
- Creates `mev.service` that runs `mev-boost` with `-mainnet`, `-relay-check`, `-min-bid $MIN_BID`, relay list from `MEV_RELAYS`, and request timeouts
- Enables the service

### Nginx and SSL

`install_nginx.sh`
- Installs Nginx and `apache2-utils`
- Installs site config at `/etc/nginx/sites-enabled/default`:
  - `location /rpc` → proxy to `127.0.0.1:8545`
  - `location /ws` → proxy to `127.0.0.1:8546`
- Opens UFW rule "Nginx Full" and enables UFW
- Restarts Nginx, then runs `./nginx_harden.sh`

`install_acme_ssl.sh`
- Runs `install_nginx.sh`
- Installs `acme.sh`, issues cert for `SERVER_NAME` via webroot, installs certs to `/etc/letsencrypt/live/SERVER_NAME`
- Calls `install_nginx_ssl.sh` to switch Nginx to SSL config

`install_ssl_certbot.sh`
- Runs `install_nginx.sh`
- Installs Certbot (Snap) and walks through manual DNS challenge; runs `certbot --nginx -d $SERVER_NAME` (expected to fail but produce files)
- Calls `install_nginx_ssl.sh`

`install_nginx_ssl.sh`
- Overwrites `/etc/nginx/sites-enabled/default` with SSL server using certs in `/etc/letsencrypt/live/$SERVER_NAME/`
- Adds UFW rules and restarts Nginx, then runs `./nginx_harden.sh`

`nginx_harden.sh`
- Creates Fail2ban filter `nginx-proxy.conf` to block attempts to use the server as an open proxy
- Attempts to update `jail.local` with the filter and restarts fail2ban and nginx

### Extra utilities (extra_utils)

`start.sh`: Starts all systemd units (`eth1`, `cl`, `validator`, `mev`, `nginx`)

`refresh.sh`: Restarts `eth1`, `mev`, `beacon-chain`, `validator`, then prints stats

`stats.sh`: Quick health snapshot:
- Greps recent errors from journals, shows next validator duties, prints client versions, and shows `systemctl status` for services

`update.sh`: Performs apt upgrades, reinstalls/updates geth, restarts CL/validator, rebuilds MEV-Boost and restarts it, restarts Nginx, then prints a before/after version report

`optional_tools.sh`: Installs terminal network monitors (`bmon`, `slurm`, `tcptrack`)

### Security utilities

`test_security_fixes.sh`: Comprehensive security testing suite
- Tests network exposure fixes, input validation, file permissions
- Tests error handling, rate limiting, security monitoring
- Tests AIDE intrusion detection, firewall configuration
- Provides detailed test results and recommendations

`docs/verify_security.sh`: Production-ready security verification
- Network security verification (UFW, Fail2ban, localhost binding)
- File security verification (permissions, access controls)
- Service security verification (systemd services, failed services)
- System security verification (updates, SSH config, disk/memory usage)
- SSL/TLS security verification (certificates, expiration)
- Security score calculation and detailed recommendations

### Alternative clients and advanced scripts

`erigon.sh`
- Opens additional ports (30304, 42069, 4000/udp, 4001/udp)
- Clones and builds Erigon (`erigon`, `rpcdaemon`, `integration`), writes a config at `$HOME/erigon/config.yaml`
- Replaces `eth1.service` to run Erigon with `--externalcl` and enables it

`reth.sh`
- Installs Rust toolchain and build dependencies
- Opens p2p ports
- Installs `reth` via Cargo and replaces `eth1.service` to run `reth node`

`lighthouse.sh`
- Downloads Lighthouse release tarball
- Prepares a CL command using checkpoint sync and Engine API (JWT from Reth path), creates and enables `cl.service`

`fb_builder_geth.sh`
- Clones Flashbots `builder` repo, builds Flashbots-patched `geth`, and copies it to `/usr/bin/geth`

`fb_mev_prysm.sh`
- Installs build prerequisites and Bazel
- Clones Flashbots fork of Prysm, builds `beacon-chain` and `validator`, replaces binaries in `~/prysm/`
- Regenerates `jwt.hex` and rewrites `cl`/`validator` systemd services to use the new binaries

### Systemd units created

- `eth1.service`: Execution client (Geth/Erigon/Reth)
- `cl.service`: Consensus client (Prysm beacon chain or Lighthouse)
- `validator.service`: Validator client (Prysm validator)
- `mev.service`: Flashbots `mev-boost`

Manage with:
```bash
sudo systemctl [start|stop|restart|status] eth1 cl validator mev
```

### Networking and ports (typical)

- Execution client p2p: 30303/tcp
- Consensus client p2p: 13000/tcp, 12000/udp
- Geth HTTP JSON-RPC: 8545 (proxied by Nginx `/rpc`)
- Geth WS: 8546 (proxied by Nginx `/ws`)
- Engine API (authrpc): 8551 (localhost only; blocked by UFW inbound)
- **Monitoring Ports**:
  - Geth/Nethermind/Besu: 6060 (Prometheus metrics)
  - Prysm: 8080 (beacon node metrics)
  - Teku: 8008 (beacon), 8009 (validator)
  - Nimbus: 8008 (beacon)
  - Lodestar: 8008 (beacon), 8009 (validator)
- Nginx: 80/443

### Data Management and Client Switching

`purge_ethereum_data.sh`
- Removes all Ethereum client data directories for clean client switching
- Supports all execution and consensus clients
- Usage:
  ```bash
  # Preview what would be deleted
  ./install/utils/purge_ethereum_data.sh --dry-run
  
  # Purge with confirmation
  ./install/utils/purge_ethereum_data.sh
  
  # Purge without confirmation
  ./install/utils/purge_ethereum_data.sh --confirm
  ```
- **WARNING**: Permanently deletes all Ethereum client data. Backup important data first.

### Useful references

- Geth: [geth.ethereum.org/docs](https://geth.ethereum.org/docs)
- Prysm: [docs.prylabs.network](https://docs.prylabs.network/)
- MEV-Boost: [github.com/flashbots/mev-boost](https://github.com/flashbots/mev-boost)
- Erigon: [github.com/ledgerwatch/erigon](https://github.com/ledgerwatch/erigon)
- Reth: [paradigmxyz.github.io/reth](https://paradigmxyz.github.io/reth/)
- Lighthouse: [lighthouse-book.sigmaprime.io](https://lighthouse-book.sigmaprime.io/)
- Nginx: [nginx.org/en/docs](https://nginx.org/en/docs/)
- Fail2ban: [github.com/fail2ban/fail2ban](https://github.com/fail2ban/fail2ban)

