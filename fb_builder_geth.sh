#!/bin/bash

git clone https://github.com/flashbots/builder.git
cd builder/ || exit
make geth
sudo cp ./build/bin/geth /usr/bin/
