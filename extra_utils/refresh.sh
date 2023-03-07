#!/bin/bash

# refreshes / restarts / potentially upgrades all our services
sudo systemctl restart eth1 &&
sudo systemctl restart mev && 
sudo systemctl restart beacon-chain && 
sudo systemctl restart validator

./$HOME/eth2-quickstart/extra_utils/stats.sh
