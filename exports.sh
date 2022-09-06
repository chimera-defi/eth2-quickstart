#!/bin/bash

# Add all shared env conf for shell scripts here 
# You only need to change the values here for all the scripts

set -o allexport

# Feel free to reach out
export EMAIL="chimera_defi@protonmail.com"

export LOGIN_UNAME='eth'
export YourSSHPortNumber='22'
export maxretry='3'
export REPO_NAME="eth2-quickstart"

# Server name used for nginx & ssl setup
export SERVER_NAME="rpc.sharedtools.org"

# Validator and beacon-chain settings
export FEE_RECIPIENT=0xa1feaF41d843d53d0F6bEd86a8cF592cE21C409e
export GRAFITTI="SharedStake.org - not yet censored"
export MAX_PEERS=200 # You may want to reduce this if you have banwidth restrictions

# Mev boost relays to use. 
# Includes only 2 censored relays rn, bloxroute and flashbots 
# export MEV_RELAYS='https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net,https://0xad0a8bb54565c2211cee576363f3a347089d2f07cf72679d16911d740262694cadb62d7fd7483f27afd714ca0f1b9118@bloxroute.ethical.blxrbdn.com'
# Bloxroute fails on registerValidator w/ timeout so only flashbots for now
export MEV_RELAYS='https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net'

set +o allexport
