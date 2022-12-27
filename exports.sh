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
export GRAFITTI="SharedStake.org!WAGMI!"
export MAX_PEERS=100 # You may want to reduce this if you have banwidth restrictions

# Mev boost relays to use. 
# Includes only 2 censored relays rn, bloxroute and flashbots 
# export MEV_RELAYS='https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net,https://0xad0a8bb54565c2211cee576363f3a347089d2f07cf72679d16911d740262694cadb62d7fd7483f27afd714ca0f1b9118@bloxroute.ethical.blxrbdn.com'
# Bloxroute fails on registerValidator w/ timeout so only flashbots for now
export MEV_RELAYS='https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net'
MEV_RELAYS=$MEV_RELAYS',https://0x84e78cb2ad883861c9eeeb7d1b22a8e02332637448f84144e245d20dff1eb97d7abdde96d4e7f80934e5554e11915c56@relayooor.wtf'
MEV_RELAYS=$MEV_RELAYS',https://0x98650451ba02064f7b000f5768cf0cf4d4e492317d82871bdc87ef841a0743f69f0f1eea11168503240ac35d101c9135@mainnet-relay.securerpc.com'
MEV_RELAYS=$MEV_RELAYS',https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money'
MEV_RELAYS=$MEV_RELAYS',https://0xb3ee7afcf27f1f1259ac1787876318c6584ee353097a50ed84f51a1f21a323b3736f271a895c7ce918c038e4265918be@relay.edennetwork.io'
MEV_RELAYS=$MEV_RELAYS',https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live'

export MIN_BID=0.03
# ~10% chance of local block production for minimal opp cost

set +o allexport
