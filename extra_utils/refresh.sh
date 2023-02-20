#!/bin/bash

# refreshes / restarts all our services

sudo systemctl restart eth1
sudo systemctl restart mev
sudo systemctl restart beacon-chain
sudo systemctl restart validator
sudo service nginx restart
