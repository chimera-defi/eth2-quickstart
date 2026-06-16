#!/bin/bash

# Eth2 Quick Start — Validator Deploy
# Generates validator keystores + deposit_data.json using ethstaker-deposit-cli
# Optionally imports keystores into the locally-detected consensus client
# Prints deposit command for manual on-chain submission (does NOT auto-submit)
#
# Usage: ./install/utils/validator_deploy.sh [options]

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

# shellcheck source=../../lib/common_functions.sh
source "$ROOT_DIR/lib/common_functions.sh"
# shellcheck source=../../exports.sh
if [[ -f "$ROOT_DIR/exports.sh" ]]; then
    source "$ROOT_DIR/exports.sh" 2>/dev/null || true
fi
if [[ -f "$ROOT_DIR/config/user_config.env" ]]; then
    # shellcheck source=/dev/null
    source "$ROOT_DIR/config/user_config.env" 2>/dev/null || true
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

SECRETS_DIR="$HOME/secrets"
DEPOSIT_CLI_NAME="ethstaker-deposit-cli"
DEPOSIT_CLI_VENV_DIR="$HOME/.${DEPOSIT_CLI_NAME}-venv"
# Persistent source checkout: the CLI resolves its intl/*.json text files
# relative to the working directory (pip does not package them), so it must be
# RUN from its own source tree — upstream's supported usage.
DEPOSIT_CLI_SRC_DIR="$HOME/.${DEPOSIT_CLI_NAME}"
DEPOSIT_CLI_REPO="https://github.com/ethstaker/ethstaker-deposit-cli.git"
WITHDRAWAL_TYPE=""
NUM_VALIDATORS=""
WITHDRAWAL_ADDRESS=""
KEYSTORE_PASSWORD=""
OUTPUT_DIR=""
IMPORT_KEYS=false
INSTALL_DEPS=false
NON_INTERACTIVE=false
AMOUNT=""

# =============================================================================
# CLIENT DETECTION (reuse from validator_list.sh)
# =============================================================================

detect_client() {
    local exec_start
    exec_start=$(systemctl show validator --property=ExecStart --value 2>/dev/null || true)
    if [[ -z "$exec_start" ]]; then
        echo "unknown"
        return
    fi
    if echo "$exec_start"   | grep -qi "lighthouse"; then echo "lighthouse"
    elif echo "$exec_start" | grep -qi "prysm";      then echo "prysm"
    elif echo "$exec_start" | grep -qi "teku";       then echo "teku"
    elif echo "$exec_start" | grep -qi "lodestar";   then echo "lodestar"
    elif echo "$exec_start" | grep -qi "nimbus";     then echo "nimbus"
    elif echo "$exec_start" | grep -qi "grandine";   then echo "grandine"
    else echo "unknown"
    fi
}

get_client_keystore_dir() {
    local client="$1"
    case "$client" in
        lighthouse)
            echo "$HOME/.lighthouse/mainnet/validators"
            ;;
        prysm)
            echo "$HOME/prysm"
            ;;
        teku)
            echo "$HOME/.local/share/teku/validator/keys"
            ;;
        lodestar)
            echo "$HOME/.local/share/lodestar/validators/keystores"
            ;;
        nimbus)
            echo "$HOME/.local/share/nimbus/validators"
            ;;
        grandine)
            echo "$HOME/.local/share/grandine/validator/keystores"
            ;;
        *)
            echo ""
            ;;
    esac
}

# =============================================================================
# CONFIRMATION HELPER
# =============================================================================

confirm_destructive() {
    local message="$1"
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        return 0
    fi
    printf "\n${YELLOW}[WARNING]${NC} %s\n" "$message"
    read -rp "  Continue? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_warn "Aborted by user."
        exit 0
    fi
}

# =============================================================================
# DEPOSIT CLI INSTALLATION
# =============================================================================

install_deposit_cli() {
    log_info "Installing $DEPOSIT_CLI_NAME..."

    if check_deposit_cli; then
        log_info "$DEPOSIT_CLI_NAME already installed (source: $DEPOSIT_CLI_SRC_DIR, venv: $DEPOSIT_CLI_VENV_DIR)"
        return 0
    fi

    # Install dependencies
    if ! command -v python3 &>/dev/null; then
        log_error "python3 not found. Please install Python 3.10+ first."
        return 1
    fi

    if ! python3 -c "import venv" &>/dev/null; then
        log_error "python3-venv not found. Install with: sudo apt-get install python3-venv"
        return 1
    fi

    # Persistent clone: the CLI must be RUN from its source tree (intl/*.json are
    # resolved relative to the working directory and are not packaged by pip).
    if [[ ! -d "$DEPOSIT_CLI_SRC_DIR/.git" ]]; then
        rm -rf "$DEPOSIT_CLI_SRC_DIR"
        log_info "Cloning $DEPOSIT_CLI_NAME repository to $DEPOSIT_CLI_SRC_DIR..."
        if ! git clone --depth 1 "$DEPOSIT_CLI_REPO" "$DEPOSIT_CLI_SRC_DIR" 2>/dev/null; then
            log_error "Failed to clone $DEPOSIT_CLI_NAME repository"
            return 1
        fi
    fi

    if [[ ! -x "$DEPOSIT_CLI_VENV_DIR/bin/python" ]]; then
        log_info "Creating virtual environment..."
        python3 -m venv "$DEPOSIT_CLI_VENV_DIR"
    fi

    log_info "Installing $DEPOSIT_CLI_NAME dependencies into the venv..."
    if ! "$DEPOSIT_CLI_VENV_DIR/bin/pip" install "$DEPOSIT_CLI_SRC_DIR" > /dev/null 2>&1; then
        log_error "Failed to install $DEPOSIT_CLI_NAME"
        # Remove the half-built venv so check_deposit_cli does not false-positive later.
        rm -rf "$DEPOSIT_CLI_VENV_DIR"
        return 1
    fi

    log_info "$DEPOSIT_CLI_NAME installed (source: $DEPOSIT_CLI_SRC_DIR, venv: $DEPOSIT_CLI_VENV_DIR)"
    return 0
}

check_deposit_cli() {
    # Need BOTH the venv (deps) and the source tree (intl text files).
    if [[ -x "$DEPOSIT_CLI_VENV_DIR/bin/python" && -d "$DEPOSIT_CLI_SRC_DIR/ethstaker_deposit/intl" ]]; then
        return 0
    fi
    return 1
}

# =============================================================================
# KEY GENERATION
# =============================================================================

generate_keys() {
    local num_validators="$1"
    local withdrawal_type="$2"
    local withdrawal_address="$3"
    local keystore_password="$4"
    local output_dir="$5"

    local output_subdir="$output_dir/validator_keys"
    ensure_directory "$output_subdir"

    local deposit_cmd=()
    local cli_python="$DEPOSIT_CLI_VENV_DIR/bin/python"

    if ! check_deposit_cli; then
        log_error "$DEPOSIT_CLI_NAME not installed. Run with --install-deps first, or install manually:"
        printf "\n  Manual installation (must be RUN from the source tree):\n"
        printf "    git clone --depth 1 %s %s\n" "$DEPOSIT_CLI_REPO" "$DEPOSIT_CLI_SRC_DIR"
        printf "    python3 -m venv %s\n" "$DEPOSIT_CLI_VENV_DIR"
        printf "    %s/bin/pip install %s\n" "$DEPOSIT_CLI_VENV_DIR" "$DEPOSIT_CLI_SRC_DIR"
        printf "    cd %s && %s/bin/python -m ethstaker_deposit --non_interactive new-mnemonic --help\n\n" "$DEPOSIT_CLI_SRC_DIR" "$DEPOSIT_CLI_VENV_DIR"
        return 1
    fi

    # Build command based on withdrawal type. --non_interactive does NOT
    # suppress missing-option prompts, so pass every choice explicitly
    # (notably the mnemonic word-list language, which otherwise prompts and
    # aborts when stdin is not a TTY).
    deposit_cmd=(
        "$cli_python" -m ethstaker_deposit
        --language english
        --non_interactive
        new-mnemonic
        --mnemonic_language english
        --num_validators "$num_validators"
        --chain mainnet
        --keystore_password "$keystore_password"
        --folder "$output_dir"
    )

    case "$withdrawal_type" in
        0x01)
            if [[ -z "$withdrawal_address" ]]; then
                log_error "0x01 (execution withdrawal) requires --withdrawal-address"
                return 1
            fi
            deposit_cmd+=(--withdrawal_address "$withdrawal_address")
            ;;
        0x02)
            if [[ -z "$withdrawal_address" ]]; then
                log_error "0x02 (compounding) requires --withdrawal-address"
                return 1
            fi
            deposit_cmd+=(
                --withdrawal_address "$withdrawal_address"
                --compounding
                --amount "${AMOUNT:-32}"
            )
            ;;
        *)
            log_error "Invalid withdrawal type: $withdrawal_type (must be 0x01 or 0x02)"
            return 1
            ;;
    esac

    log_info "Generating $num_validators validator key(s) with withdrawal type $withdrawal_type..."
    log_info "Output directory: $output_subdir"

    # NOTE: ethstaker-deposit-cli's --non_interactive mode takes --keystore_password
    # as an argument, so the value is briefly visible in the child process command
    # line (e.g. `ps`) for the duration of key generation. This is a limitation of
    # the upstream tool's non-interactive interface; the mnemonic itself is never
    # echoed and all generated files are locked to 600 below.

    # Lock down the output dir + generation log up front: the log can capture
    # secret material emitted by the deposit CLI.
    chmod 700 "$output_dir" 2>/dev/null || true
    # Run deposit CLI from its source tree (intl text files resolve from CWD);
    # capture output but don't echo mnemonic. output_dir is absolute.
    if ! ( cd "$DEPOSIT_CLI_SRC_DIR" && "${deposit_cmd[@]}" > "$output_dir/generation.log" 2>&1 ); then
        chmod 600 "$output_dir/generation.log" 2>/dev/null || true
        log_error "Key generation failed. Check $output_dir/generation.log for details."
        return 1
    fi
    chmod 600 "$output_dir/generation.log" 2>/dev/null || true

    # Secure the output directory
    chmod 700 "$output_subdir"
    find "$output_subdir" -type f -exec chmod 600 {} \;

    log_info "Keys generated successfully in $output_subdir"
    return 0
}

# =============================================================================
# KEY IMPORT
# =============================================================================

import_keys_to_client() {
    local client="$1"
    local keystore_dir="$2"

    if [[ -z "$client" || "$client" == "unknown" ]]; then
        log_warn "No validator client detected. Import the keystores manually from: $keystore_dir"
        return 0
    fi

    # Most clients require their own import command — a bare file copy does NOT
    # activate keys for prysm/lighthouse/nimbus/lodestar, and teku needs matching
    # password files. Print the exact client command instead of pretending a copy
    # worked (preview-first, consistent with the rest of this repo).
    log_info "Detected client: $client"
    log_info "Generated keystores are staged at: $keystore_dir"
    printf "\n  Run the import for %s (it prompts for the keystore password):\n\n" "$client"
    case "$client" in
        lighthouse)
            printf "    lighthouse account validator import --network mainnet --directory %s\n" "$keystore_dir"
            ;;
        prysm)
            printf "    prysm.sh validator accounts import --mainnet --keys-dir=%s\n" "$keystore_dir"
            ;;
        teku)
            printf "    # Teku loads keystore/password-file pairs from its keys dir:\n"
            printf "    cp %s/keystore-*.json %s/\n" "$keystore_dir" "$(get_client_keystore_dir teku)"
            printf "    # then create a matching <keystore-name>.txt password file per keystore\n"
            ;;
        lodestar)
            printf "    lodestar validator import --dataDir \$HOME/.local/share/lodestar --importKeystores %s\n" "$keystore_dir"
            ;;
        nimbus)
            printf "    nimbus_beacon_node deposits import --data-dir=\$HOME/.local/share/nimbus %s\n" "$keystore_dir"
            ;;
        grandine)
            printf "    cp %s/keystore-*.json %s/\n" "$keystore_dir" "$(get_client_keystore_dir grandine)"
            ;;
        *)
            printf "    # See your client's documentation for keystore import.\n"
            ;;
    esac
    printf "\n"
    log_info "After importing, restart the validator service: sudo systemctl restart validator"
}

# =============================================================================
# DEPOSIT COMMAND PRINTING
# =============================================================================

print_deposit_command() {
    local deposit_data_file="$1"

    if [[ ! -f "$deposit_data_file" ]]; then
        log_error "deposit_data file not found: $deposit_data_file"
        return 1
    fi

    printf "\n"
    log_info "=== Deposit Command ==="
    printf "\n"
    cat <<'EOF'
  To stake your validators, visit the Ethereum Launchpad:
  https://launchpad.ethereum.org/

  Upload the deposit_data.json file and follow the instructions.
  Your deposit_data file is located at:

EOF
    printf "    %s\n\n" "$deposit_data_file"

    cat <<'EOF'
  IMPORTANT:
  - Double-check the deposit contract address on the Launchpad
  - Verify you are on the correct network (mainnet)
  - Keep your mnemonic and keystore password secure
  - Never share your mnemonic or private keys

EOF
}

# =============================================================================
# MAIN
# =============================================================================

print_usage() {
    cat <<'EOF'
Usage: ./install/utils/validator_deploy.sh [options]

Options:
  --num-validators <N>           Number of validators to generate [required]
  --withdrawal-type <type>       Withdrawal type: 0x01 (execution address) or 0x02 (compounding) [required]
  --withdrawal-address <addr>    Execution withdrawal address (required for 0x01 and 0x02)
  --keystore-password <pwd>      Password for keystore encryption [required]
  --output-dir <dir>             Output directory for keystores [default: $HOME/secrets/validator_keys_<timestamp>]
  --amount <eth>                 Deposit amount in ETH for 0x02 compounding (32-2048, default 32)
  --import-keys                  Print the exact client-specific import command for the generated keys
  --install-deps                 Install ethstaker-deposit-cli if missing, then continue (standalone if no other args)
  --non-interactive              Skip confirmation prompts
  --help, -h                     Show this help message

The keystore password is taken from the ETHQS_KEYSTORE_PASSWORD env var or an
interactive prompt; --keystore-password also works but is discouraged (visible
in process listings and shell history).

Examples:
  # Generate 1 validator with execution withdrawal (0x01)
  ETHQS_KEYSTORE_PASSWORD=... ./validator_deploy.sh --num-validators 1 \\
    --withdrawal-type 0x01 --withdrawal-address 0x1234... --install-deps

  # Generate 2 compounding validators (0x02, 64 ETH each) and show import commands
  ETHQS_KEYSTORE_PASSWORD=... ./validator_deploy.sh --num-validators 2 \\
    --withdrawal-type 0x02 --amount 64 --withdrawal-address 0x1234... --import-keys

  # Install the deposit CLI only
  ./validator_deploy.sh --install-deps

EOF
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --num-validators)
                [[ $# -ge 2 ]] || { echo "Error: --num-validators requires a value" >&2; exit 2; }
                NUM_VALIDATORS="$2"
                shift
                ;;
            --withdrawal-type)
                [[ $# -ge 2 ]] || { echo "Error: --withdrawal-type requires a value" >&2; exit 2; }
                WITHDRAWAL_TYPE="$2"
                case "$WITHDRAWAL_TYPE" in
                    0x01|0x02) ;;
                    *) echo "Error: --withdrawal-type must be 0x01 or 0x02" >&2; exit 2 ;;
                esac
                shift
                ;;
            --withdrawal-address)
                [[ $# -ge 2 ]] || { echo "Error: --withdrawal-address requires a value" >&2; exit 2; }
                WITHDRAWAL_ADDRESS="$2"
                shift
                ;;
            --keystore-password)
                [[ $# -ge 2 ]] || { echo "Error: --keystore-password requires a value" >&2; exit 2; }
                KEYSTORE_PASSWORD="$2"
                log_warn "Passing --keystore-password on the command line is visible in process listings and shell history. Prefer the ETHQS_KEYSTORE_PASSWORD env var or the interactive prompt."
                shift
                ;;
            --output-dir)
                [[ $# -ge 2 ]] || { echo "Error: --output-dir requires a value" >&2; exit 2; }
                OUTPUT_DIR="$2"
                shift
                ;;
            --import-keys)
                IMPORT_KEYS=true
                ;;
            --install-deps)
                INSTALL_DEPS=true
                ;;
            --amount)
                [[ $# -ge 2 ]] || { echo "Error: --amount requires a value (ETH, 32-2048, 0x02 only)" >&2; exit 2; }
                AMOUNT="$2"
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                print_usage
                exit 1
                ;;
        esac
        shift
    done

    # Install tooling first if requested. Standalone mode: --install-deps with no
    # generation args installs and exits cleanly.
    if [[ "$INSTALL_DEPS" == "true" ]]; then
        if ! install_deposit_cli; then
            exit 1
        fi
        if [[ -z "$NUM_VALIDATORS" && -z "$WITHDRAWAL_TYPE" ]]; then
            log_info "Dependencies installed. Re-run with --num-validators/--withdrawal-type to deploy validators."
            exit 0
        fi
    fi

    # Validate --amount (compounding only; 0x01 deposits are fixed at 32 ETH)
    if [[ -n "$AMOUNT" ]]; then
        if [[ "$WITHDRAWAL_TYPE" != "0x02" ]]; then
            log_error "--amount is only valid with --withdrawal-type 0x02 (compounding)"
            exit 1
        fi
        if [[ ! "$AMOUNT" =~ ^[0-9]+$ ]] || (( AMOUNT < 32 || AMOUNT > 2048 )); then
            log_error "--amount must be an integer between 32 and 2048 (ETH)"
            exit 1
        fi
    fi

    # Validate required arguments
    if [[ -z "$NUM_VALIDATORS" ]]; then
        log_error "--num-validators is required"
        print_usage
        exit 1
    fi

    if [[ -z "$WITHDRAWAL_TYPE" ]]; then
        log_error "--withdrawal-type is required (0x01 or 0x02)"
        print_usage
        exit 1
    fi

    # Resolve keystore password securely: flag (discouraged) -> env var -> interactive prompt.
    if [[ -z "$KEYSTORE_PASSWORD" && -n "${ETHQS_KEYSTORE_PASSWORD:-}" ]]; then
        KEYSTORE_PASSWORD="$ETHQS_KEYSTORE_PASSWORD"
    fi
    if [[ -z "$KEYSTORE_PASSWORD" ]]; then
        if [[ "$NON_INTERACTIVE" != "true" && -t 0 ]]; then
            read -rs -p "Keystore password: " KEYSTORE_PASSWORD; echo
            read -rs -p "Confirm keystore password: " _kp_confirm; echo
            if [[ "$KEYSTORE_PASSWORD" != "$_kp_confirm" ]]; then
                log_error "Passwords do not match"
                exit 1
            fi
        else
            log_error "Keystore password required: set ETHQS_KEYSTORE_PASSWORD, run interactively, or pass --keystore-password (discouraged; visible in process listings)."
            exit 1
        fi
    fi

    # Set default output directory
    if [[ -z "$OUTPUT_DIR" ]]; then
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        OUTPUT_DIR="$SECRETS_DIR/validator_keys_$timestamp"
    fi
    # Generation runs with CWD inside the deposit-cli source tree, so the
    # output directory must be absolute.
    OUTPUT_DIR=$(realpath -m "$OUTPUT_DIR")

    # Ensure secrets directory exists
    ensure_directory "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"

    # Confirmation
    confirm_destructive "This will generate $NUM_VALIDATORS validator key(s) and store sensitive data in $OUTPUT_DIR"

    # Generate keys
    if ! generate_keys "$NUM_VALIDATORS" "$WITHDRAWAL_TYPE" "$WITHDRAWAL_ADDRESS" "$KEYSTORE_PASSWORD" "$OUTPUT_DIR"; then
        log_error "Key generation failed"
        exit 1
    fi

    local keystore_dir="$OUTPUT_DIR/validator_keys"
    local deposit_data_file
    deposit_data_file=$(find "$keystore_dir" -name "deposit_data*.json" | head -1)

    if [[ -z "$deposit_data_file" ]]; then
        log_error "deposit_data.json not found in $keystore_dir"
        exit 1
    fi

    # Show client-specific import instructions if requested
    if [[ "$IMPORT_KEYS" == "true" ]]; then
        local client
        client=$(detect_client)
        import_keys_to_client "$client" "$keystore_dir"
    fi

    # Print deposit command
    print_deposit_command "$deposit_data_file"

    log_info "Validator deployment complete!"
    log_info "Keystore directory: $keystore_dir"
    log_info "The mnemonic and full CLI output were captured in: $OUTPUT_DIR/generation.log (mode 600)"
    log_warn "Back up the mnemonic OFFLINE now, then delete generation.log. Never share the mnemonic or password."
}

main "$@"