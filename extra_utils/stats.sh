#!/bin/bash
echo "Error scan"
journalctl -u cl -n 200 | grep error
journalctl -u eth1 -n 200 | grep error
journalctl -u validator -n 200 | grep error
journalctl -u mev -n 200 | grep error
echo "End error scan output --"
echo "check time till duty"
journalctl -u validator -n 1000 | grep timeTillDuty
echo ''
echo ''
echo ''

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
