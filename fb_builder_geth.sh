#!/bin/bash

git clone https://github.com/flashbots/builder.git
cd builder/
make geth
sudo cp ./build/bin/geth /usr/bin/
