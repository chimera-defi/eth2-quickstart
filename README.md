# Introduction

Get a ETH2 compatible rpc node setup in second! 
Get your own uncensored & unmetered RPC node! 
And get ready for the ETH2 merge!

We try to setup guideline to quickly, safely and secury setup ETH2 capable nodes on a cloud vps.  

The goal is to allow soverign individuals to set up independent validators, and validating services easily.   
On their own hardware, in their own location, safe from government overreach and censorship.   

Additionally, by using a vps, they can more easily offer a censorship resistant rpc node for their fellow etherians.  
(Do you really want to open up a rpc node on your home wifi for the world to use? )

# Steps
1. Set up cloud vps with a ssh pub key
  a. Prefer a bare metal vps as it wont finish syncing on cloud
  b. Recommended specs based on Geth and Prysm
    - 2 - 4+ TB SSD
    - 32-64+GB of RAM
    - 4-8+ cores
    - ubuntu 20+
  c. Referral link for $20 free in cloud credits https://hetzner.cloud/?ref=d4Hoyi2u3pwn
  
2. Run provided scripts. Read through them first to make sure you understand what is happening and its correct. It can bork your server. 
  a. Run_1.sh 
    - will upgrade ubuntu and installed programs, 
    - setup firewalls, do security hardening, 
    - install needed programs for setting up a node,
  b. After it finishes, verify the results and run `sudo reboot`
  c. Log back in and run `run_2.sh`, this will install prysm, geth, nginx, setup systemctl for eth2 services and prompt for getting a ssl cert for the rpc. Also contains commands to begin syncing prysm and geth
  c1. You can revisit this step and the certbot command if you do not have a domain yet. See step 4 for details. You can stil continue to the next step.  
  d. Start your services via systemctl! eth1, beacon-chain & validator
  d1. 
  ```
   sudo systemctl start eth1
   sudo systemctl start beacon-chain
   sudo systemctl start validator
  ```
3. Once geth & prysm are synced, verify nginx is working and configured correctly using the following command and tutorials: 

```
$ curl -X POST http://<ip>/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'
```

4. Setup a domain
  a. Get a website
  b. Setup DNS records from it to point to your servers public IP
  c. Setup Nginx on your server to handle requests
5. Setup SSL for your domain
  a. A lot of the work will be done for you by the script
  b. Follow the tutorials here after they finish: 
  c. Verify it works `$ curl -X POST http://<ip>/rpc --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":32}' -H 'Content-Type: application/json'`
  