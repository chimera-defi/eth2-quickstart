# Introduction

Setup an Ethereum node quickly with automated scripts. 
Simple shell scripts contain community best practices to remove tedious setup. 
Supports servers, home solo stakers, pool node operators. 

**NEW**: Now supports multiple Ethereum clients with a unified installation experience!

(Don't blindly run scripts near sensitive data)   

# Supported Clients

## Execution Clients
- **Geth** - Most popular, battle-tested Go implementation
- **Nethermind** - High performance .NET implementation  
- **Besu** - Enterprise-focused Java implementation
- **Erigon** - Fast sync Go implementation
- **Reth** - High performance Rust implementation

## Consensus Clients
- **Prysm** - Most popular Go implementation
- **Lighthouse** - High performance Rust implementation
- **Teku** - Enterprise-focused Java implementation
- **Nimbus** - Lightweight Nim implementation
- **Lodestar** - TypeScript implementation

## Validator Clients
- **Prysm Validator** - Integrated with Prysm
- **Lighthouse Validator** - Integrated with Lighthouse
- **Teku Validator** - Integrated with Teku
- **Nimbus Validator** - Integrated with Nimbus
- **Lodestar Validator** - Integrated with Lodestar

# Pre-reqs
1. Set up cloud vps with a ssh pub key or local server
    a. Prefer a bare metal vps as it won't finish syncing on cloud
    b. Recommended specs based on client choice:
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

### Option 1: Interactive Client Selection (Recommended)

1. Download these scripts, initially as root via running this from the terminal; we will automatically create a eth user for safety.     

```
git clone https://github.com/chimera-defi/eth2-quickstart
cd eth2-quickstart
chmod +x run_1.sh
chmod +x client_selector.sh
```

  
2. Run server setup script 
```
./run_1.sh
``` 
  - will upgrade ubuntu and installed programs,   
  - guide the user on manual steps
  - setup firewalls, do security hardening,   
  - install needed programs for setting up a node  

  
3. After it finishes, verify the results and run `sudo reboot`  
Log back in as the new non-root user `eth@ip`
- configure `exports.sh` 

4. Log back in as the new non-root user `eth@ip`
- configure `exports.sh` 
- Run the interactive client selector:
```
./client_selector.sh
```
   This will guide you through selecting:
     - Execution client (Geth, Nethermind, Besu, Erigon, or Reth)
     - Consensus client (Prysm, Lighthouse, Teku, Nimbus, or Lodestar)
     - Validator client (if you plan to run a validator)
     - MEV-Boost service

### Option 2: Manual Installation

5. Log back in as the new non-root user `eth@ip`
- configure `exports.sh` 
- Run individual install scripts:
```
# Install execution client (choose one)
./install_geth.sh
# OR
./install_nethermind.sh
# OR
./install_besu.sh
# OR
./erigon.sh
# OR
./install_reth.sh

# Install consensus client (choose one)
./install_prysm.sh
# OR
./lighthouse.sh
# OR
./install_teku.sh
# OR
./install_nimbus.sh
# OR
./install_lodestar.sh

# Install MEV-Boost
./install_mev_boost.sh
```

6. Start your services via systemctl to confirm successful installation!
  
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

### Checkpoint Sync (Fast Sync)
Most consensus clients support checkpoint sync for faster initial synchronization:

**Prysm:**
```
sudo systemctl stop cl
sudo systemctl stop validator
$(echo $HOME)/prysm/prysm.sh cl --checkpoint-block=$PWD/prysm/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/prysm/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/prysm/genesis.ssz --config-file=$PWD/prysm/prysm_beacon_conf.yaml --p2p-host-ip=$(curl -s v4.ident.me)
```

**Other clients:** Checkpoint sync is configured automatically in the client configurations.

### Validator Setup
1. **Prysm:** Follow the official docs: https://docs.prylabs.network/docs/install/install-with-script#step-5-run-a-validator-using-prysm
   - Create a `pass.txt` file in `~/prysm` with your wallet password
   
2. **Lighthouse:** Follow the official docs: https://lighthouse.sigmaprime.io/validator.html
   
3. **Teku:** Follow the official docs: https://docs.teku.consensys.net/how-to/configure/validator-keys
   
4. **Nimbus:** Follow the official docs: https://nimbus.guide/validator.html
   
5. **Lodestar:** Follow the official docs: https://lodestar.chainsafe.io/validator/

### Execution Client Sync
Execution clients will sync in the background. Typical sync times:
- **Geth:** 1-3 days
- **Nethermind:** 1-2 days  
- **Besu:** 2-4 days
- **Erigon:** 6-12 hours (fastest)
- **Reth:** 4-8 hours (very fast)   

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

# Troubleshooting & tips

- need to update? just run `./update.sh`   
- make sure the files are executable 
```
chmod u+x run1.sh..
```
- check disk space and setup
```
df -hT
```
- Use on goerli - do the following before running `run_2.sh`
  - There is a Goerli checkpt url in `exports.sh`; change the prysm cp url to it
  - Add `--prater` to the prysm start cmds in `install_prysm.sh`
  - Add `--goerli` to the geth start cmd in `install_geth.sh`


# Client Comparison

## Execution Clients

| Client | Language | Sync Speed | Memory Usage | Best For |
|--------|----------|------------|--------------|----------|
| **Geth** | Go | Medium | Medium | Most users, battle-tested |
| **Nethermind** | .NET | Fast | Low | High performance needs |
| **Besu** | Java | Medium | High | Enterprise features |
| **Erigon** | Go | Very Fast | Low | Fast sync, archival |
| **Reth** | Rust | Very Fast | Low | Performance, new features |

## Consensus Clients

| Client | Language | Memory Usage | Best For |
|--------|----------|--------------|----------|
| **Prysm** | Go | Medium | Most users, easy setup |
| **Lighthouse** | Rust | Low | High performance |
| **Teku** | Java | High | Enterprise features |
| **Nimbus** | Nim | Very Low | Resource-constrained |
| **Lodestar** | TypeScript | Medium | JavaScript ecosystem |

# Benefits:
- **Multiple Client Support:** Choose from 5 execution clients and 5 consensus clients
- **Unified Installation:** Single script to install any client combination
- **Fast Sync:** Checkpoint sync support for quick initial synchronization
- **Reduced Code Duplication:** Common functions library for maintainable scripts
- **Get your own uncensored & unmetered RPC node!** 
- **Simplified setup** with community best practices
- **Firewall rules** to prevent scanning private IPs and avoid hosting provider alerts

We provide guidelines to quickly, safely and securely setup Ethereum nodes on cloud VPS or bare metal servers.  
The goal is to allow sovereign individuals to set up independent validators and validating services easily.    
On their own hardware, in their own location, safe from government overreach and censorship.    

Additionally, by using a VPS, they can more easily offer a censorship resistant RPC node for their fellow etherians.   

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
