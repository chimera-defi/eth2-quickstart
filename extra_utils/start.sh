#!/bin/bash

# Starts all systemd units
sudo systemctl start eth1
sudo systemctl start cl
sudo systemctl start validator
sudo systemctl start mev
sudo systemctl start nginx
