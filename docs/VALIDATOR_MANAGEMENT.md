# Validator Management

Several standalone helper scripts for managing validators on this node.
They are also available through the unified `eth2qs.sh` wrapper.

---

## Quick Reference

```bash
# List local validators (human-readable table)
./scripts/eth2qs.sh validators
./install/utils/validator_list.sh

# List local validators (JSON — for scripting)
./scripts/eth2qs.sh validators --json
./install/utils/validator_list.sh --json

# Go straight to voluntary exit flow
./scripts/eth2qs.sh validator-exit
./install/utils/validator_exit.sh

# Go straight to 0x02 validator creation flow
./scripts/eth2qs.sh validator-create-0x02
./install/utils/validator_create_0x02.sh

# Interactive management menu (exit / consolidate)
./scripts/eth2qs.sh validator-manage
./install/utils/validator_manage.sh

# Go straight to consolidation flow (EIP-7251)
./scripts/eth2qs.sh validator-manage --consolidate
./install/utils/validator_manage.sh --consolidate
```

---

## `validator_list.sh` — How It Works

1. Detects the running consensus client from the `validator` systemd service.
2. Scans the client's well-known keystore directory for EIP-2335 keystore files.
3. Extracts the public key from each keystore's JSON.
4. Queries the local beacon node API (`/eth/v1/beacon/states/head/validators`)
   filtered to those public keys only.
5. Displays a table with validator index, pubkey, status, balance, and
   effective balance.

**Nothing is read from the network validator set** — only validators whose
keystore files exist on this machine are shown.

### Keystore Directories by Client

| Client     | Keystore directory                                      |
|------------|---------------------------------------------------------|
| Lighthouse | `~/.lighthouse/mainnet/validators/`                     |
| Prysm      | `~/prysm/`                                              |
| Teku       | `~/.local/share/teku/validator/keys/`                   |
| Lodestar   | `~/.local/share/lodestar/validators/keystores/`         |
| Nimbus     | `~/.local/share/nimbus/validators/`                     |
| Grandine   | `~/.local/share/grandine/validator/keystores/`          |

### JSON Output Schema

```json
{
  "client": "lighthouse",
  "beacon_url": "http://127.0.0.1:5052",
  "validators": [
    {
      "index": "123456",
      "balance": "32004100000",
      "status": "active_ongoing",
      "validator": {
        "pubkey": "0xabc...",
        "effective_balance": "32000000000",
        ...
      }
    }
  ]
}
```

---

## `validator_exit.sh` — Focused Exit Flow

This helper wraps the existing exit path, but it starts with a targeted checklist
for legacy validators.

1. Shows the current local validator inventory via `validator_list.sh`.
2. Reminds you that `0x00` validators need credential upgrades before any
   withdrawals can be swept.
3. Hands off to `validator_manage.sh --exit` for the interactive client-specific
   exit flow.

## `validator_create_0x02.sh` — Compounding Entry Flow

This helper is the matching entry path for modern validators.

1. Prints the offline key-generation checklist.
2. Shows the current local validator inventory so you can compare against the
   node you are about to import into.
3. Launches the local deposit CLI if available, or prints the exact command
   template when you are running the tool manually.
4. Reminds you to select compounding / `0x02` withdrawal credentials during the
   deposit CLI prompts.

## `validator_manage.sh` — Operations

### 1. Voluntary Exit

> **This is permanent and irreversible.** An exited validator cannot
> re-enter the active set.

The exit flow:

1. Shows all local validators (same discovery as `validator_list.sh`).
2. Prompts for the validator index or pubkey to exit. Enter `all` to exit
   all local validators.
3. Requires you to type `yes` to confirm.
4. Calls the client-specific exit CLI.

**Per-client exit commands** (called internally, shown here for reference):

| Client     | CLI                                                                    |
|------------|------------------------------------------------------------------------|
| Lighthouse | `lighthouse account validator exit --beacon-node <url> --pubkeys <pk>` |
| Prysm      | `prysm.sh validator accounts voluntary-exit --pubkeys <pk>`            |
| Teku       | `teku voluntary-exit --validator-public-key <pk>`                      |
| Lodestar   | `lodestar validator voluntary-exit --pubkeys <pk>`                     |
| Nimbus     | `nimbus_beacon_node deposits exit --validator <pk>`                    |
| Grandine   | Uses `ethdo` (see below)                                               |

**Universal alternative — ethdo:**

```bash
# Install
go install github.com/wealdtech/ethdo@latest

# Exit a specific validator
ethdo validator exit \
  --validator=<index_or_pubkey> \
  --connection=http://127.0.0.1:5052
```

### 2. Consolidation (EIP-7251)

Consolidation merges two of your validators into one, combining their
balances. The source validator exits; its stake moves to the target.

**Prerequisites:**

- Both validators must have `0x01` withdrawal credentials pointing to an
  Ethereum address you control.
- You need the private key of that withdrawal address to sign the transaction.
- A dynamic fee is required (queried live from the contract).

**Contract:** `0x00431F263cE400f4455c2dCf564e53007Ca4bbBb` (mainnet)

The consolidation flow:

1. Shows all local validators.
2. Prompts for source pubkey and target pubkey.
3. Queries the current fee from the consolidation contract.
4. Displays the full `cast send` command with filled-in values.
5. Optionally executes it (requires [Foundry](https://getfoundry.sh) `cast`).

**Manual execution** (if you prefer not to enter a private key interactively):

```bash
# The script prints the exact command — copy and run it yourself:
cast send 0x00431F263cE400f4455c2dCf564e53007Ca4bbBb \
  --value <fee_wei>wei \
  --data 0x<source_pubkey_hex><target_pubkey_hex> \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <YOUR_WITHDRAWAL_ADDRESS_PRIVATE_KEY>

# Install Foundry if needed:
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

---

## Beacon API Ports by Client

The scripts auto-detect the correct port from the `cl` systemd service.

| Client     | Default Port |
|------------|--------------|
| Lighthouse | 5052         |
| Prysm      | 5052         |
| Teku       | 5051         |
| Lodestar   | 9596         |
| Nimbus     | 5052         |
| Grandine   | 5052         |

---

## Troubleshooting

**"No keystore files found"**
- Check that validator keys have been imported into the client's keystore
  directory (see table above).
- Run `systemctl status validator` to confirm the service is running.

**"No validator data returned from beacon node"**
- The beacon node may still be syncing. Check with `./scripts/eth2qs.sh doctor`.
- Verify the beacon node is reachable: `curl -s http://127.0.0.1:5052/eth/v1/node/syncing`

**Exit command fails with unknown flag**
- Client versions change CLI flags. If the auto-detected command fails,
  use the manual `ethdo` path shown in the output.
