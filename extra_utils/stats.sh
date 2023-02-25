#!/bin/bash

echo "Versions of clients"
../mev-boost/mev-boost -version
../prysm/prysm.sh cl -version
../prysm/prysm.sh validator -version
geth version
echo "End version output --"
echo ''

systemctl status eth1 --no-pager
systemctl status cl --no-pager
systemctl status validator --no-pager
systemctl status mev --no-pager
