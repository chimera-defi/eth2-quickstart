#!/bin/bash
source ./exports.sh

# Hot patch prysm installation with mev prysm 

# prereqs to build from src
sudo apt install cmake libssl-dev libgmp-dev libtinfo5 libprotoc
go install github.com/bazelbuild/bazelisk@latest

git clone --recurse-submodules https://github.com/flashbots/prysm.git
cd prysm
bazel build //cmd/beacon-chain:beacon-chain --config=release
bazel build //cmd/validator:validator --config=release

# ?? 
# $(echo $HOME)/prysm/prysm.sh
# 