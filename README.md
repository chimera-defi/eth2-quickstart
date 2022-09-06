# Introduction

Get a ETH2 compatible rpc node setup in seconds! And get ready for the ETH2 merge!  


# Benefits:
- Save at least 2 days compared to CoinCashew and Somersats guides using the automated scripts and included prysm checkpoint state here!!   
- Get your own uncensored & unmetered RPC node! 
- Simplified script will follow sane defaults from tutorials to get you set up seamlessly and prompt for extra input not added in exports.sh
- Includes firewall and client rules to prevent scanning private IPs/limit to public, to avoid Abuse alerts from cloud / bare metal hosting providers



We try to setup guideline to quickly, safely and secury setup ETH2 capable nodes on a cloud vps or bare metal server.  
Addditionally, there's firewall rules and settings for the clients to not cause alerts from your infra provider.    

The goal is to allow soverign individuals to set up independent validators, and validating services easily.    
On their own hardware, in their own location, safe from government overreach and censorship.    

Additionally, by using a vps, they can more easily offer a censorship resistant rpc node for their fellow etherians.   

# Pre-reqs
1. Set up cloud vps with a ssh pub key
    a. Prefer a bare metal vps as it wont finish syncing on cloud
    b. Recommended specs based on Geth and Prysm
      - 2 - 4+ TB SSD or NVMe
      - 16-64+GB of RAM
      - 4-8+ cores
      - ubuntu 20+
  c. Referral link for $20 free in cloud credits https://hetzner.cloud/?ref=d4Hoyi2u3pwn
  d. SSH in, set up your server
  e. (Optional) Configure VSCode to work with your server https://code.visualstudio.com/docs/remote/ssh


# Quickstart 

1. Download these scripts, initially as root via running this from the terminal    
`
git clone https://github.com/chimera-defi/eth2-quickstart
`
`
cd eth2-quickstart
`

  
2. Run provided scripts. First make changes in `exports.sh` to your preferred values for setup via vscode or:     
    `nano exports.sh`  
  a. Run  `./run_1.sh` 
    - will upgrade ubuntu and installed programs,   
    - setup firewalls, do security hardening,   
    - install needed programs for setting up a node,  
  
  b. After it finishes, verify the results and run `sudo reboot`  
  c. Log back in as the user and run   
  `./run_2.sh`  
   this will setup:
 
     - prysm
     - geth
     - mev-boost
     - setup systemctl for eth2 services 
     - Also contains commands to begin syncing prysm and geth
  d. Start your services via systemctl to confirm succesful installation! eth1, beacon-chain & validator  
    - d.  
Start eth services
`sudo systemctl start eth1`
`sudo systemctl start beacon-chain`
`sudo systemctl start validator`
`sudo systemctl start mev`   
Verify they work
   `sudo systemctl status eth1`
    `sudo systemctl status beacon-chain`
    `sudo systemctl status validator`
    `sudo systemctl status mev `
   
    - e. Sync prysm instantly

    ```
    sudo systemctl stop beacon-chain
    sudo systemctl stop validator
    $(echo $HOME)/prysm/prysm.sh beacon-chain --checkpoint-block=$PWD/prysm/block_mainnet_altair_4620512-0xef9957e6a709223202ab00f4ee2435e1d42042ad35e160563015340df677feb0.ssz --checkpoint-state=$PWD/prysm/state_mainnet_altair_4620512-0xc1397f57149c99b3a2166d422a2ee50602e2a2c7da2e31d7ea740216b8fd99ab.ssz --genesis-state=$PWD/prysm/genesis.ssz --config-file=$PWD/prysm/prysm_beacon_conf.yaml --p2p-host-ip=$(curl -s v4.ident.me)
    ```
    
    Remember to restart the beacon-chain and validator afterwards.   
 
    - f. Continue using prysm docs to set up the validator using new or old imported keys : https://docs.prylabs.network/docs/install/install-with-script#step-5-run-a-validator-using-prysm
   
    - g. Create a pass.txt file in ~/prysm with your wallets password to enable using the validator service


  
3. [Optional RPC] Once geth & prysm are synced, install nginx   
`./install_nginx.sh`  
and verify it is working and configured correctly if you want to use the RPC.  
Use the following command to verify locally:
```
curl -X POST http://<ip>/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'
```
Replace <ip> w/ `$(curl v4.ident.me)` for local.  
Replace <ip> with your domain name to see if it works for real from a different host.   
Use https to check SSL.  

4. Setup a domain (Optional, helps w/ public RPC)  
   a. Get a website - e.g. via namecheap  
  b. Setup DNS records from it to point to your servers public IP  
  c. Setup Nginx on your server to handle requests and provide a rpc   

5. Setup SSL for your domain. You will need to use `sudo su` to switch back to super user to properly install NGINX an SSL with the provide scripts. 
  - There are 2 options to configure SSL and NGINX:
  - `./install_acme_ssl.sh` will use sensible defaults, letencrypt, acme.sh and nginx to setup certificates.  
  - You can otherwise use `./install_ssl_certbot.sh` to use certbot.
  - See here for troubleshooting: https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/ 

     a. A lot of the work will be done for you by the script   
    b. Follow the tutorials here after they finish:   https://certbot.eff.org/  
    c. Verify it works using `curl -X POST http://$(curl -s v4.ident.me)/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'`

6. Confirm mev boost is configured and working correctly 
  - https://github.com/flashbots/mev-boost/wiki/Testing
  - Check validators register properly (Note: Need a 0x prefix on the validator pub key) https://boost.flashbots.net/mev-boost-status-updates/query-validator-registration-status-now


7. Further security hardening tips: (TODO)
  - Disable root login after everything is confirmed to be working by setting `PermitRootLogin no` in `/etc/ssh/sshd_config`  


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

# Contact: 

Chimera_defi@protonmail.com
