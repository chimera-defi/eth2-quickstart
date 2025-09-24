# Ethereum Node Quick Setup

Setup an Ethereum node quickly with simple shell scripts containing community best practices. 
Supports multiple client combinations for servers, home solo stakers, and pool node operators.
Choose from various execution and consensus clients for optimal client diversity.

**⚠️ Security Notice:** Don't blindly run scripts near sensitive data. Review scripts before execution.   

# Pre-reqs
1. Set up cloud vps with a ssh pub key or local server
    a. Prefer a bare metal vps as it wont finish syncing on cloud
    b. Recommended specs based on Geth and Prysm
      - 2 - 4+ TB SSD or NVMe
      - 16-64+GB of RAM
      - 4-8+ cores
      - ubuntu 20+
  d. SSH in, set up your server.
      - set swraid 1 & swraidlevel 0 for full disk access and better performance
      - Note: Fingerprint will change, you will need to rm it from known-hosts after setup every time -> `nano ~/.ssh/known_hosts` and remove the last line corresponding to your new server or run: `sed -i '' -e '$ d' ~/.ssh/known_hosts`
  e. (Optional) Configure VSCode to work with your server https://code.visualstudio.com/docs/remote/ssh
    - `cmd shift p` -> add new remote host -> `ssh root@my.ip.`  -> connect


# Quickstart 

## Installation

1. Download these scripts, initially as root via running this from the terminal; we will automatically create a eth user for safety.     

```
git clone https://github.com/chimera-defi/eth2-quickstart
cd eth2-quickstart
chmod +x run_1.sh
```

  
2. Run server setup script 
```
./run_1.sh
``` 
  - will upgrade ubuntu and installed programs,   
  - guide the user on manual steps
  - setup firewalls, do security hardening,   
  - install needed programs for setting up a node  

  
4. After it finishes, verify the results and run `sudo reboot`  
Log back in as the new non-root user `eth@ip`
- configure `exports.sh` 

5. Log back in as the new non-root user `eth@ip`
- configure `exports.sh` 
- **Choose your clients:** Run `./select_clients.sh` to get recommendations
- Run`./run_2.sh` OR manually install your chosen clients:
   Default setup includes:
     - prysm (consensus client)
     - geth (execution client) 
     - mev-boost
     - setup systemctl for eth2 services
6. Start your services via systemctl to confirm successful installation! eth1, beacon-chain & validator
  
    ```
    sudo systemctl start eth1
    sudo systemctl start cl
    sudo systemctl start validator
    sudo systemctl start mev
    ```
    Verify they work normally
    ```
    sudo systemctl status eth1
    sudo systemctl status cl
    sudo systemctl status validator
    sudo systemctl status mev
    ```

## Sync and configure 
**Note: You may be able to skip this step now with checkpoint urls added**
1. Sync prysm instantly / faster thanks to provided checkpoint files in this repo

    ```
    sudo systemctl stop cl
    sudo systemctl stop validator
    $(echo $HOME)/prysm/prysm.sh cl --checkpoint-block=$PWD/prysm/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/prysm/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/prysm/genesis.ssz --config-file=$PWD/prysm/prysm_beacon_conf.yaml --p2p-host-ip=$(curl -s v4.ident.me)
    ```
    
    Remember to restart the beacon-chain and validator afterwards.   
    ```
    sudo systemctl restart cl
    sudo systemctl restart validator
    ```
2. Continue using prysm docs to set up the validator using new or old imported keys : https://docs.prylabs.network/docs/install/install-with-script#step-5-run-a-validator-using-prysm
    - Create a `pass.txt` file in `~/prysm` with your wallets password to enable using the validator service
3. To speed up geth sync you can try to restart it with other flags in its config, but most likely it will just take a little time running in the background.  Benchmark is 1-3 days.   

## Available Ethereum Clients

This repository supports multiple Ethereum client implementations to promote client diversity and provide options for different use cases.

### Execution Clients (ETH1)

| Client | Language | Description | Best For | Install Script |
|--------|----------|-------------|----------|----------------|
| **Geth** | Go | Original Go implementation, most stable | Beginners, stability | `./install_geth.sh` |
| **Erigon** | Go | Re-architected for efficiency | Performance, fast sync | `./erigon.sh` |
| **Reth** | Rust | Modern Rust implementation | Performance, modularity | `./reth.sh` |
| **Nethermind** | C# | Enterprise-focused .NET client | Enterprise, advanced features | `./install_nethermind.sh` |
| **Besu** | Java | Apache 2.0 licensed, enterprise-ready | Private networks, compliance | `./install_besu.sh` |

### Consensus Clients (ETH2)

| Client | Language | Description | Best For | Install Script |
|--------|----------|-------------|----------|----------------|
| **Prysm** | Go | Well-documented, reliable | Beginners, documentation | `./install_prysm.sh` |
| **Lighthouse** | Rust | Security-focused, high performance | Performance, security | `./lighthouse.sh` |
| **Teku** | Java | ConsenSys-developed, enterprise features | Institutional, monitoring | `./install_teku.sh` |
| **Nimbus** | Nim | Lightweight, resource efficient | Raspberry Pi, low resources | `./install_nimbus.sh` |
| **Lodestar** | TypeScript | Developer-friendly, modern | Development, TypeScript devs | `./install_lodestar.sh` |
| **Grandine** | Rust | High-performance, cutting-edge | Advanced users, performance | `./install_grandine.sh` |

### Configuration Architecture

This repository follows a consistent configuration pattern across all clients:

#### **Configuration Conventions**
1. **Centralized Variables**: All client-specific settings are defined in `exports.sh`
2. **Template + Custom Pattern**: Each client has base template configs and custom variable overlays
3. **Directory Structure**: Each client has its own config directory (e.g., `teku/`, `nimbus/`)
4. **Merge Strategy**: Install scripts combine base templates with user-specific variables

#### **Configuration Flow**
```
exports.sh → Base Template + Custom Variables → Final Client Config
```

**Example Structure:**
```
├── exports.sh                    # All configuration variables
├── configs/
│   └── teku/
│       ├── teku_beacon_base.yaml     # Base beacon config template
│       └── teku_validator_base.yaml  # Base validator config template
└── install_teku.sh               # Merges base + custom configs
```

#### **Key Variables in exports.sh**
- `NETHERMIND_CACHE`, `BESU_CACHE`, `TEKU_CACHE` - Client-specific memory settings
- `TEKU_REST_PORT`, `NIMBUS_REST_PORT` - Client-specific API ports  
- `TEKU_CHECKPOINT_URL`, `LIGHTHOUSE_CHECKPOINT_URL` - Client-specific checkpoint URLs
- `FEE_RECIPIENT`, `GRAFITTI` - Universal validator settings

### Client Selection Guide

Run the interactive client selection assistant:
```bash
chmod +x select_clients.sh
./select_clients.sh
```

**Recommendations by Use Case:**

- **Beginners**: Geth + Prysm (most documentation and support)
- **Performance**: Erigon/Reth + Lighthouse (optimized for speed)
- **Resource-Constrained**: Geth + Nimbus (proven on various hardware)
- **Enterprise**: Nethermind/Besu + Teku (enterprise features)
- **Client Diversity**: Any minority client combination

### System Requirements by Client

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **CPU** | 4 cores | 8+ cores | More cores help with sync |
| **RAM** | 16GB | 32GB+ | Nimbus can run on 8GB |
| **Storage** | 2TB SSD | 4TB NVMe | Fast storage crucial |
| **Network** | Stable broadband | Unlimited data | Avoid metered connections |

## Setup public RPC endpoint using Nginx
Setup a secure uncensored outward facing Ethereum RPC for you and your friends!  It's been faster than Infura/alchemy etc for me.

1. [Optional RPC] Once geth & prysm are synced, install nginx   
`./install_nginx.sh`  
and verify it is working and configured correctly if you want to use the RPC.  
Use the following command to verify locally:
    ```
    curl -X POST http://<ip>/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'
    ```
    Replace `<ip>` w/ `$(curl v4.ident.me)` for local.  
    Replace `<ip>` with your domain name to see if it works for real from a different host.   
    Use https to check SSL.  

2. Setup a domain (Optional, helps w/ public RPC)  
   a. Get a website - e.g. via namecheap  
  b. Setup DNS records from it to point to your servers public IP  
  c. Setup Nginx on your server to handle requests and provide a rpc   

3. Setup SSL for your domain. You will need to use `sudo su` to switch back to super user to properly install NGINX an SSL with the provide scripts. 
  - There are 2 options to configure SSL and NGINX:
  - `./install_acme_ssl.sh` will use sensible defaults, letencrypt, acme.sh and nginx to setup certificates.  
  - You can otherwise use `./install_ssl_certbot.sh` to use certbot.
  - See here for troubleshooting: https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/ 

     a. A lot of the work will be done for you by the script   
    b. Follow the tutorials here after they finish:   https://certbot.eff.org/  
    c. Verify it works using `curl -X POST http://$(curl -s v4.ident.me)/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'`

4. Confirm mev boost is configured and working correctly 
  - https://github.com/flashbots/mev-boost/wiki/Testing
  - Check validators register properly (Note: Need a 0x prefix on the validator pub key) https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now


5. Further security hardening tips: (TODO)
  - Disable root login after everything is confirmed to be working by setting `PermitRootLogin no` in `/etc/ssh/sshd_config`  

# Troubleshooting & Tips

## General Troubleshooting

- **Need to update?** Run `./update.sh`   
- **Make files executable:** 
```bash
chmod +x *.sh
chmod +x lib/common_functions.sh
```
- **Check disk space:** 
```bash
df -hT
```
- **Check service status:**
```bash
sudo systemctl status eth1 cl validator mev
```
- **View logs:**
```bash
journalctl -fu eth1    # Execution client logs
journalctl -fu cl      # Consensus client logs  
journalctl -fu validator # Validator logs
journalctl -fu mev     # MEV-Boost logs
```

## Client-Specific Issues

### Execution Clients
- **Geth**: Most stable, check for port conflicts on 8545, 8546, 30303
- **Erigon**: Requires more RAM during sync, check `config.yaml` settings
- **Reth**: Compilation issues? Ensure Rust toolchain is updated
- **Nethermind**: .NET runtime issues? Check Java installation
- **Besu**: Java heap size issues? Adjust memory settings in config

### Consensus Clients  
- **Prysm**: Checkpoint sync failing? Update `PRYSM_CPURL` in `exports.sh`
- **Lighthouse**: Rust compilation issues? Update Rust toolchain
- **Teku**: Java out of memory? Increase heap size in service file
- **Nimbus**: Resource constraints? It's designed for low-resource systems
- **Lodestar**: Node.js issues? Ensure Node.js 16+ is installed
- **Grandine**: Very new client, check official docs for latest updates

## Network-Specific Setup

### Testnet Usage (Goerli/Holesky)
Before running client install scripts, modify configurations:
- Update checkpoint URLs in `exports.sh`
- Add network flags (e.g., `--goerli`, `--holesky`) to client commands
- Ensure testnet-specific genesis and checkpoint files

### Mainnet Optimization
- Enable checkpoint sync for faster initial sync
- Configure MEV-Boost with multiple relays
- Set appropriate cache sizes based on available RAM
- Use fast NVMe storage for better performance


# Benefits

## Performance & Reliability
- **Multiple Client Options**: Choose from 5 execution and 6 consensus clients
- **Client Diversity**: Improve network resilience by using minority clients
- **Optimized Configurations**: Pre-tuned settings for each client type
- **Fast Sync**: Checkpoint sync enabled for rapid initial synchronization
- **Resource Efficiency**: Options for resource-constrained environments (Nimbus)

## Ease of Use
- **Interactive Selection**: `./select_clients.sh` guides client choice
- **Automated Setup**: Reduced setup time compared to manual configuration
- **Common Functions**: Refactored codebase eliminates duplication
- **Comprehensive Logging**: Detailed logs and status monitoring
- **Systemd Integration**: Proper service management and auto-restart

## Security & Infrastructure  
- **Firewall Rules**: Automated security hardening
- **JWT Authentication**: Secure execution/consensus client communication
- **MEV-Boost Integration**: Maximize validator rewards
- **Uncensored RPC**: Run your own censorship-resistant endpoint
- **Enterprise Features**: Advanced monitoring and management (Teku, Nethermind, Besu)

## Client-Specific Advantages
- **Geth**: Battle-tested stability, extensive documentation
- **Erigon**: Faster sync, lower disk usage, better performance  
- **Reth**: Modern Rust implementation, modular architecture
- **Nethermind**: Enterprise features, .NET ecosystem integration
- **Besu**: Permissive licensing, private network support
- **Lighthouse**: Security-focused, excellent performance
- **Teku**: Institutional-grade monitoring and management
- **Nimbus**: Ultra-lightweight, perfect for ARM devices
- **Lodestar**: Developer-friendly TypeScript implementation
- **Grandine**: Cutting-edge performance optimizations

We try to setup guideline to quickly, safely and secury setup ETH2 capable nodes on a cloud vps or bare metal server.  
Addditionally, there's firewall rules and settings for the clients to not cause alerts from your infra provider.    

The goal is to allow soverign individuals to set up independent validators, and validating services easily.    
On their own hardware, in their own location, safe from government overreach and censorship.    

Additionally, by using a vps, they can more easily offer a censorship resistant rpc node for their fellow etherians.   

# Credits
This was made possible by the great guides written by:

- Someresat    
https://someresat.medium.com/guide-to-staking-on-ethereum-ubuntu-prysm-581fb1969460?utm_source=substack&utm_medium=email

and   

- coincashew   
https://www.coincashew.com/coins/overview-eth/guide-or-how-to-setup-a-validator-on-eth2-mainnet/part-i-installation/installing-execution-client


Additionally the beacon checkpoint states have been made available by the servers run for the community of:      
https://Sharedstake.org
And 
https://sharedtools.org

# Contact for qs / collab: 

Chimera_defi@protonmail.com

Twitter: https://twitter.com/chimeradefi

## Additional documentation

### Core Documentation
- Scripts reference: docs/SCRIPTS.md
- Setup workflow: docs/WORKFLOW.md
- Terminology: docs/GLOSSARY.md

### Configuration & Development
- Configuration guide: docs/CONFIGURATION_GUIDE.md
- Shell scripting best practices: docs/SHELL_SCRIPTING_BEST_PRACTICES_AND_LINTING_GUIDE.md
- Refactoring summary: docs/REFACTORING_SUMMARY.md

### Testing & Validation
- Comprehensive testing report: docs/COMPREHENSIVE_SCRIPT_TESTING_REPORT.md
- Shell script test results: docs/SHELL_SCRIPT_TEST_RESULTS.md
- Final verification: docs/FINAL_VERIFICATION.md

### Project Management
- Consolidated PR details: docs/CONSOLIDATED_PR.md
- Commit message conventions: docs/COMMIT_MESSAGES.md
- Development progress: docs/progress.md
