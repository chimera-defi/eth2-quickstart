#!/bin/bash

# Monad Full Node Installation Script - Phase 2
# Analogous to run_2.sh for Ethereum. Installs and configures a Monad full node.
# Must run as the non-root operator user (with sudo available).
# Requires CHAIN='monad' and MONAD_TRIEDB_DRIVE set in config/user_config.env.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/exports.sh"
source "$SCRIPT_DIR/lib/common_functions.sh"

# Require non-root execution (operator user runs this, uses sudo where needed)
if [[ $EUID -eq 0 ]]; then
    log_error "This script must NOT be run as root. Run as the operator user (e.g. '${LOGIN_UNAME:-eth}')."
    exit 1
fi

# Step 0: Guard — CHAIN must be set to monad
if [[ "${CHAIN:-}" != "monad" ]]; then
    log_error "This script is for Monad only. CHAIN is set to '${CHAIN:-unset}'."
    log_error "Set CHAIN='monad' in config/user_config.env and re-run."
    exit 1
fi

# Step 1: Guard — MONAD_TRIEDB_DRIVE must be set
if [[ -z "${MONAD_TRIEDB_DRIVE:-}" ]]; then
    log_error "MONAD_TRIEDB_DRIVE is not set."
    log_error "This must be the path to a DEDICATED, EMPTY NVMe device (e.g. /dev/nvme1n1)."
    log_error "WARNING: The device will be completely reformatted. Do NOT set this to your OS drive."
    log_error "Set MONAD_TRIEDB_DRIVE in config/user_config.env and re-run."
    exit 1
fi

# Step 1b: Verify system has sufficient RAM for Monad hugepages requirement.
# Monad requires 2048 hugepages × 2 MiB = 4 GiB reserved just for hugepages, plus
# operating overhead. Minimum usable system RAM is 8 GiB.
MIN_RAM_KB=$((8 * 1024 * 1024))
AVAILABLE_RAM_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [[ "${AVAILABLE_RAM_KB}" -lt "${MIN_RAM_KB}" ]]; then
    log_error "Insufficient RAM: ${AVAILABLE_RAM_KB} KiB available, ${MIN_RAM_KB} KiB required."
    log_error "Monad requires at least 8 GiB RAM for hugepages and node operation."
    exit 1
fi
log_info "RAM check passed: ${AVAILABLE_RAM_KB} KiB available."

# Step 2: Verify drive has no mountpoints before touching it
log_info "Verifying MONAD_TRIEDB_DRIVE=${MONAD_TRIEDB_DRIVE} is safe to format..."
if lsblk -o MOUNTPOINT "${MONAD_TRIEDB_DRIVE}" 2>/dev/null | grep -qv '^$\|MOUNTPOINT'; then
    log_error "Drive ${MONAD_TRIEDB_DRIVE} has active mountpoints. Aborting to protect data."
    log_error "Run 'lsblk -o NAME,SIZE,TYPE,MOUNTPOINT' to inspect drives."
    exit 1
fi
log_info "Drive ${MONAD_TRIEDB_DRIVE} has no mountpoints. Safe to proceed."

# Step 3: System update and dependencies
# Do NOT use 'sudo install_dependencies' — shell functions are not inherited by sudo subprocesses
log_info "Updating system and installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y curl nvme-cli aria2 jq parted iptables-persistent

# Open Monad P2P ports and persist the anti-spam iptables rule now that
# iptables-persistent is installed. Phase 1 (consolidated_security.sh) opened SSH only;
# we layer the chain-specific rules on top here in Phase 2.
log_info "Opening Monad P2P firewall ports..."
sudo ufw allow 8000/tcp
sudo ufw allow 8000/udp
sudo ufw allow 8001/tcp

log_info "Applying and persisting Monad iptables anti-spam rule..."
sudo iptables -I INPUT -p udp --dport 8000 -m length --length 0:1400 -j DROP
sudo netfilter-persistent save
log_info "iptables anti-spam rule applied and persisted across reboots."

# Step 4: Add Monad APT repository and install package
log_info "Configuring Monad APT repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkg.category.xyz/keys/public-key.asc \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/category-labs.gpg

sudo tee /etc/apt/sources.list.d/category-labs.sources > /dev/null << 'EOF'
Types: deb
URIs: https://pkg.category.xyz/
Suites: noble
Components: main
Signed-By: /etc/apt/keyrings/category-labs.gpg
EOF

sudo apt-get update -y
sudo apt-get install -y monad
sudo apt-mark hold monad
log_info "Monad package installed and held at current version."

# Step 5: Create monad service user
log_info "Creating monad system service user..."
if ! id -u monad &>/dev/null; then
    sudo useradd -r -m -s /bin/bash monad
    log_info "Created monad user."
else
    log_info "monad user already exists, skipping."
fi

sudo mkdir -p /home/monad/monad-bft/config \
              /home/monad/monad-bft/ledger \
              /home/monad/monad-bft/config/forkpoint \
              /home/monad/monad-bft/config/validators
sudo chown -R monad:monad /home/monad/

# Step 6: Configure TrieDB NVMe device
log_info "Partitioning TrieDB device: ${MONAD_TRIEDB_DRIVE}"
log_info "THIS IS DESTRUCTIVE. The device will be completely reformatted."
sudo parted "${MONAD_TRIEDB_DRIVE}" mklabel gpt
sudo parted "${MONAD_TRIEDB_DRIVE}" mkpart triedb 0% 100%

PARTUUID=$(sudo lsblk -o PARTUUID "${MONAD_TRIEDB_DRIVE}" | tail -n 1)
log_info "TrieDB partition UUID: ${PARTUUID}"

echo "ENV{ID_PART_ENTRY_UUID}==\"${PARTUUID}\", MODE=\"0666\", SYMLINK+=\"triedb\"" \
    | sudo tee /etc/udev/rules.d/99-triedb.rules > /dev/null

sudo udevadm trigger
sudo udevadm control --reload
sudo udevadm settle

if [[ ! -e /dev/triedb ]]; then
    log_error "/dev/triedb symlink was not created. Check udev rules."
    exit 1
fi
log_info "TrieDB device configured at /dev/triedb"

log_info "Formatting TrieDB partition via monad-mpt service..."
sudo systemctl start monad-mpt
sudo journalctl -u monad-mpt -n 20 -o cat --no-pager

# Step 7: Download official Monad testnet config files
MF_BUCKET="https://bucket.monadinfra.com"
log_info "Downloading Monad testnet configuration files..."
sudo curl -fsSL -o /home/monad/.env \
    "${MF_BUCKET}/config/testnet/latest/.env.example"
sudo curl -fsSL -o /home/monad/monad-bft/config/node.toml \
    "${MF_BUCKET}/config/testnet/latest/full-node-node.toml"
sudo chown monad:monad /home/monad/.env /home/monad/monad-bft/config/node.toml
log_info "Config files downloaded to /home/monad/"

# Step 8: Generate keystore password
# Do NOT use ensure_jwt_secret — that is for Ethereum Engine API JWT, different purpose/format.
log_info "Generating keystore password..."
sudo sed -i "s|^KEYSTORE_PASSWORD=.*$|KEYSTORE_PASSWORD='$(openssl rand -base64 32)'|" \
    /home/monad/.env
sudo mkdir -p /opt/monad/backup/
KEYSTORE_PASS=$(sudo grep KEYSTORE_PASSWORD /home/monad/.env | cut -d= -f2)
echo "Keystore password: ${KEYSTORE_PASS}" | sudo tee /opt/monad/backup/keystore-password-backup
sudo chmod 600 /opt/monad/backup/keystore-password-backup
log_info "Keystore password generated and backed up to /opt/monad/backup/keystore-password-backup"

# Step 9: Generate BLS and SECP keys
# monad-keystore is a Monad-specific binary from the monad APT package.
# The sudo heredoc pattern runs as root to write to monad-owned paths.
log_info "Generating monad keystore (BLS + SECP keys)..."
sudo bash << 'KEYEOF'
set -e
. /home/monad/.env
monad-keystore create \
    --key-type secp \
    --keystore-path /home/monad/monad-bft/config/id-secp \
    --password "${KEYSTORE_PASSWORD}"
monad-keystore create \
    --key-type bls \
    --keystore-path /home/monad/monad-bft/config/id-bls \
    --password "${KEYSTORE_PASSWORD}"
chown monad:monad /home/monad/monad-bft/config/id-secp \
                  /home/monad/monad-bft/config/id-bls
KEYEOF
log_info "Keystores generated."

# Step 10: Apply Monad performance sysctl
# These are Monad-specific kernel tuning values, separate from security sysctl in Phase 1.
log_info "Applying Monad performance sysctl settings..."
sudo tee /etc/sysctl.d/99-monad.conf > /dev/null << 'EOF'
# Monad full node kernel tuning
# Source: docs.monad.xyz + monad-bft README
# These are performance settings, separate from security sysctl in Phase 1.

# Hugepages required by monad-bft consensus process
vm.nr_hugepages = 2048

# UDP/TCP buffer sizes for consensus and RPC stability
net.core.rmem_max = 62500000
net.core.rmem_default = 62500000
net.core.wmem_max = 62500000
net.core.wmem_default = 62500000
net.ipv4.tcp_rmem = 4096 62500000 62500000
net.ipv4.tcp_wmem = 4096 62500000 62500000
EOF

sudo sysctl -p /etc/sysctl.d/99-monad.conf
log_info "Monad sysctl applied."

# Step 11: Enable and start all Monad systemd services
# otelcol excluded — pending security review (see CLAUDE.md)
log_info "Enabling and starting Monad systemd services..."
for svc in monad-bft monad-execution monad-rpc monad-cruft; do
    enable_and_start_systemd_service "$svc"
done

# Step 12: Smoke check
log_info "Waiting for Monad RPC to become available..."
RPC_UP=false
for i in $(seq 1 6); do
    sleep 5
    RESULT=$(curl -sf -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null || true)
    if echo "${RESULT}" | grep -q '"result"'; then
        log_info "Monad RPC responded: ${RESULT}"
        RPC_UP=true
        break
    fi
    log_info "RPC not yet available (attempt $i/6)..."
done

if [[ "$RPC_UP" == "false" ]]; then
    log_warn "Monad RPC did not respond within 30 seconds."
    log_warn "This may be normal during initial sync. Check with:"
    log_warn "  journalctl -fu monad-bft"
    log_warn "  journalctl -fu monad-execution"
else
    log_info "Smoke check PASSED. Monad node is responding to RPC."
fi

# Step 13: Print completion summary
cat << EOF

=== Monad Full Node Installation Complete ===

Services installed:
  monad-bft        (consensus client)
  monad-execution  (execution client)
  monad-rpc        (RPC server)
  monad-cruft      (hourly cleanup)

To check status:
  sudo systemctl status monad-bft
  sudo systemctl status monad-execution
  sudo systemctl status monad-rpc

To follow logs:
  journalctl -fu monad-bft
  journalctl -fu monad-execution

To verify sync progress (block height should increase over time):
  curl -sf -X POST http://localhost:8545 \\
    -H "Content-Type: application/json" \\
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

Config files:
  /home/monad/.env                        (env vars including KEYSTORE_PASSWORD)
  /home/monad/monad-bft/config/node.toml (node config)
  /opt/monad/backup/keystore-password-backup  (KEEP THIS SAFE)

EOF
