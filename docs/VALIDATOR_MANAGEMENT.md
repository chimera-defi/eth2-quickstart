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

# Filter by balance (ETH), withdrawal type (0x00 BLS / 0x01 execution / 0x02 compounding), or status
./scripts/eth2qs.sh validators --json --min-balance 32 --withdrawal-type 0x01
./scripts/eth2qs.sh validators --withdrawal-type 0x02            # compounding validators only
./scripts/eth2qs.sh validators --max-balance 32 --status active_ongoing

# Deploy validators + generate keys and deposit_data.json (0x01 or 0x02 compounding)
# Set the keystore password via the ETHQS_KEYSTORE_PASSWORD env var (preferred) or interactive prompt.
ETHQS_KEYSTORE_PASSWORD=... ./scripts/eth2qs.sh validator-deploy \
  --num-validators 1 --withdrawal-type 0x02 --withdrawal-address 0xYourAddr --import-keys

# Go straight to voluntary exit flow
./scripts/eth2qs.sh validator-exit
./install/utils/validator_exit.sh

# Go straight to 0x02 validator creation flow
./scripts/eth2qs.sh validator-create-0x02
./install/utils/validator_create_0x02.sh

# Preview / generate / submit BLS-to-execution changes for 0x00 validators
./scripts/eth2qs.sh validator-withdrawal-changes --dry-run --generate --submit --yes
./scripts/eth2qs.sh validator-withdrawal-changes --generate --submit --yes
./install/utils/validator_withdrawal_changes.sh --dry-run --generate --submit --yes

# Interactive management menu (exit / consolidate)
./scripts/eth2qs.sh validator-manage
./install/utils/validator_manage.sh

# Go straight to consolidation flow (EIP-7251)
./scripts/eth2qs.sh validator-manage --consolidate
./install/utils/validator_manage.sh --consolidate

# Go straight to EIP-7002 exit/withdrawal flow
./scripts/eth2qs.sh validator-manage --eip7002-exit
./install/utils/validator_manage.sh --eip7002-exit

# Go straight to withdrawal credential change flow
./scripts/eth2qs.sh validator-manage --withdraw-change
./install/utils/validator_manage.sh --withdraw-change
```

---

## `validator_list.sh` — How It Works

1. Detects the running consensus client from the `validator` systemd service.
2. Scans the client's well-known keystore directory for EIP-2335 keystore files.
3. Extracts the public key from each keystore's JSON.
4. Queries the local beacon node API (`/eth/v1/beacon/states/head/validators`)
   filtered to those public keys only.
5. Displays a table with validator index, pubkey, status, balance, withdrawal credential type, and effective balance.
6. Emits inventory freshness metadata in the JSON output (`generated_at_utc`, `beacon_query_status`) so operators can tell when the snapshot was taken and whether the beacon query succeeded.

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
  "generated_at_utc": "2026-06-04T00:00:00Z",
  "beacon_query_status": "ok",
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

## `validator_withdrawal_changes.sh` — BLS-to-Execution Change Flow

This helper generates and optionally submits signed BLS-to-execution change
messages for validators that still use `0x00` withdrawal credentials. It is the
first step before a later voluntary exit if you want the validator to become
withdrawable.

1. Shows the current local validator inventory, including withdrawal credential
   type and inventory freshness metadata.
2. Filters the inventory to the selected credential type (default `0x00`).
3. Supports `--dry-run` so operators can preview the exact signing and submit
   commands without writing or POSTing anything.
4. Uses the official deposit CLI to generate signed BLS-to-execution change
   JSON files from a withdrawal mnemonic and execution address.
5. Optionally POSTs the generated JSON files to the local beacon node REST API
   at `/eth/v1/beacon/pool/bls_to_execution_changes`.
6. Works with the repo's Prysm + geth stack as long as the beacon REST API is
   reachable from the node running the helper.

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
- A dynamic fee is required (queried live from the contract using `eth_call` with empty calldata).

**Contract:** `0x0000BBdDc7CE488642fb579F8B00f3a590007251` (mainnet)

The consolidation flow:

1. Shows all local validators.
2. Prompts for source pubkey and target pubkey.
3. Queries the current fee from the consolidation contract.
4. Displays the full `cast send` command with filled-in values.
5. Optionally executes it (requires [Foundry](https://getfoundry.sh) `cast`).

**Manual execution** (if you prefer not to enter a private key interactively):

```bash
# The script prints the exact command — copy and run it yourself:
cast send 0x0000BBdDc7CE488642fb579F8B00f3a590007251 \
  --value <fee_wei>wei \
  --data 0x<source_pubkey_hex><target_pubkey_hex> \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <YOUR_WITHDRAWAL_ADDRESS_PRIVATE_KEY>

# Install Foundry if needed:
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

---

### 3. EIP-7002 EL-triggered exit/withdrawal

`validator_manage.sh --eip7002-exit` builds the EIP-7002 payload (`validator_pubkey || amount`) and prints the exact `cast send` command before execution.

```bash
cast send 0x00000961Ef480Eb55e80D19ad83579A64c007002 \
  --value <fee_wei>wei \
  --data 0x<validator_pubkey_hex><amount_u64_gwei_be_hex> \
  --rpc-url http://127.0.0.1:8545 \
  --from <WITHDRAWAL_ADDRESS>
```

`amount_u64_gwei_be_hex` is the withdrawal amount in gwei encoded as an 8-byte big-endian integer.
`amount = 0` requests a full voluntary exit.

### 4. Withdrawal credential change

- `0x00 -> 0x01`: `ethdo validator credentials set`:

```bash
ethdo validator credentials set \
  --validator <index_or_pubkey> \
  --withdrawal-address <address> \
  --connection http://127.0.0.1:5052
```

- `0x01 -> 0x02`: self-consolidation (source and target are the same pubkey) using `cast`.

```bash
cast send 0x0000BBdDc7CE488642fb579F8B00f3a590007251 \
  --value <fee_wei>wei \
  --data 0x<source_pubkey_hex><source_pubkey_hex> \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <WITHDRAWAL_ADDRESS_PRIVATE_KEY>
```

## `validator_deploy.sh` — Key Generation & Deposit

Generates validator keystores + `deposit_data.json` by wrapping
[`ethstaker-deposit-cli`](https://github.com/eth-educators/ethstaker-deposit-cli),
shows the exact client-specific **import command** for the detected client, and
**prints the deposit command for manual submission** (it never submits the
on-chain deposit for you).

```bash
ETHQS_KEYSTORE_PASSWORD=... ./scripts/eth2qs.sh validator-deploy \
  --num-validators 2 \
  --withdrawal-type 0x02 \                 # 0x01 (execution address) or 0x02 (compounding)
  --amount 64 \                            # optional, 0x02 only: 32-2048 ETH (default 32)
  --withdrawal-address 0xYourWithdrawalAddr \
  --import-keys                            # optional: print the client import command
```

- Provide the keystore password via the `ETHQS_KEYSTORE_PASSWORD` env var or the
  interactive prompt. The `--keystore-password` flag works but is discouraged
  (visible in process listings / shell history).
- Mnemonic and keys are never echoed to the terminal; generated files are written
  `600` under `$HOME/secrets`. The mnemonic is captured in
  `<output-dir>/generation.log` (mode 600) — **back it up offline, then delete
  the log, before funding.**
- `--import-keys` does not silently copy files: most clients require their own
  import command (prysm/lighthouse/nimbus/lodestar) or password-file pairs
  (teku), so the script prints the exact command to run instead.
- `ethstaker-deposit-cli` and `ethdo` are installed by
  `install/utils/install_dependencies.sh`; if absent, the script prints manual
  install + command instructions instead of failing hard.

## Filtering the validator list

`validators` / `validator_list.sh` accept filters that apply to both the table
and `--json` output:

| Flag | Meaning |
|------|---------|
| `--min-balance <eth>` | Only validators with balance ≥ this (ETH) |
| `--max-balance <eth>` | Only validators with balance ≤ this (ETH) |
| `--withdrawal-type <t>` | `0x00` (BLS), `0x01` (execution address), `0x02` (compounding) |
| `--status <substr>` | Status substring, e.g. `active_ongoing`, `exited` |

The withdrawal type is matched against the prefix of each validator's
`withdrawal_credentials`.

## Agent access (MCP)

For agents (Claude Code / Codex) the MCP server exposes:

- **`eth2qs_validators(min_balance, max_balance, withdrawal_type, status)`** —
  read-only validator inventory with the same filters as the CLI.
- **`eth2qs_validator_op_preview(operation)`** — read-only; returns the exact node
  CLI command for a funds-affecting operation (`exit`, `withdrawal-change`,
  `consolidate`, `eip7002-exit`, `create-0x02`, `deploy`).

**Funds-affecting validator operations are intentionally NOT executed via MCP.**
They are irreversible and require secrets/keys, so they run only on the node CLI
where they prompt for confirmation. The MCP surface lets an agent inspect and
plan; a human (or the CLI) performs the actual mutation.

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

**Withdrawal change generation fails**
- The helper needs the withdrawal mnemonic, the optional mnemonic password, and a valid execution address.
- If you are using Prysm, make sure the beacon REST API is reachable from the node running the helper.
- Use `--validators-json` with a fixture if you want to rehearse the flow without touching live keys.

**Exit command fails with unknown flag**
- Client versions change CLI flags. If the auto-detected command fails,
  use the manual `ethdo` path shown in the output.
