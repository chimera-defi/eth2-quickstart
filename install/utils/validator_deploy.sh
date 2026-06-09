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
DEPOSIT_CLI_REPO="https://github.com/ethstaker/ethstaker-deposit-cli.git"
WITHDRAWAL_TYPE=""
NUM_VALIDATORS=""
WITHDRAWAL_ADDRESS=""
KEYSTORE_PASSWORD=""
OUTPUT_DIR=""
IMPORT_KEYS=false
NON_INTERACTIVE=false

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

    # Check if already installed
    if [[ -d "$DEPOSIT_CLI_VENV_DIR" ]]; then
        log_info "$DEPOSIT_CLI_NAME already installed at $DEPOSIT_CLI_VENV_DIR"
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

    # Create temporary directory for clone
    local tmp_dir
    tmp_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp_dir'" EXIT

    log_info "Cloning $DEPOSIT_CLI_NAME repository..."
    if ! git clone --depth 1 "$DEPOSIT_CLI_REPO" "$tmp_dir/repo" 2>/dev/null; then
        log_error "Failed to clone $DEPOSIT_CLI_NAME repository"
        return 1
    fi

    log_info "Creating virtual environment..."
    python3 -m venv "$DEPOSIT_CLI_VENV_DIR"

    log_info "Installing $DEPOSIT_CLI_NAME..."
    # shellcheck disable=SC1090
    source "$DEPOSIT_CLI_VENV_DIR/bin/activate"
    if ! pip install -e "$tmp_dir/repo" &>/dev/null; then
        log_error "Failed to install $DEPOSIT_CLI_NAME"
        deactivate
        return 1
    fi
    deactivate

    log_info "$DEPOSIT_CLI_NAME installed successfully at $DEPOSIT_CLI_VENV_DIR"
    return 0
}

check_deposit_cli() {
    if [[ -d "$DEPOSIT_CLI_VENV_DIR" && -x "$DEPOSIT_CLI_VENV_DIR/bin/python" ]]; then
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
        printf "\n  Manual installation:\n"
        printf "    git clone %s /tmp/ethstaker-deposit-cli\n" "$DEPOSIT_CLI_REPO"
        printf "    cd /tmp/ethstaker-deposit-cli\n"
        printf "    python3 -m venv venv\n"
        printf "    ./venv/bin/pip install -e .\n"
        printf "    ./venv/bin/python -m ethstaker_deposit --non_interactive new-mnemonic --help\n\n"
        return 1
    fi

    # Build command based on withdrawal type
    deposit_cmd=(
        "$cli_python" -m ethstaker_deposit
        --non_interactive
        new-mnemonic
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
                --amount 32
            )
            ;;
        *)
            log_error "Invalid withdrawal type: $withdrawal_type (must be 0x01 or 0x02)"
            return 1
            ;;
    esac

    log_info "Generating $num_validators validator key(s) with withdrawal type $withdrawal_type..."
    log_info "Output directory: $output_subdir"

    # Run deposit CLI (capture output but don't echo mnemonic)
    if ! "${deposit_cmd[@]}" > "$output_dir/generation.log" 2>&1; then
        log_error "Key generation failed. Check $output_dir/generation.log for details."
        return 1
    fi

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
    local password="$3"

    local client_keystore_dir
    client_keystore_dir=$(get_client_keystore_dir "$client")

    if [[ -z "$client_keystore_dir" ]]; then
        log_warn "Unknown client '$client'. Cannot auto-import keys."
        log_info "Manual import required. Copy keystores from $keystore_dir to your client's keystore directory."
        return 0
    fi

    if [[ "$client" == "unknown" ]]; then
        log_warn "No validator client detected. Cannot auto-import keys."
        log_info "Manual import required. Copy keystores from $keystore_dir to your client's keystore directory."
        return 0
    fi

    log_info "Importing keys to $client client at $client_keystore_dir"

    ensure_directory "$client_keystore_dir"

    # Copy keystores
    if ! cp -r "$keystore_dir"/* "$client_keystore_dir"/ 2>/dev/null; then
        log_error "Failed to copy keystores to $client_keystore_dir"
        return 1
    fi

    # Set permissions
    chmod 700 "$client_keystore_dir"
    find "$client_keystore_dir" -type f -exec chmod 600 {} \;

    log_info "Keys imported successfully. Restart validator service to activate."
    log_info "  sudo systemctl restart validator"
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
  --import-keys                  Import generated keys into detected consensus client
  --install-deps                 Install ethstaker-deposit-cli if not present
  --non-interactive              Skip confirmation prompts
  --help, -h                     Show this help message

Examples:
  # Generate 1 validator with execution withdrawal (0x01)
  ./validator_deploy.sh --num-validators 1 --withdrawal-type 0x01 \\
    --withdrawal-address 0x1234... --keystore-password mypass --install-deps

  # Generate 2 compounding validators (0x02) and import keys
  ./validator_deploy.sh --num-validators 2 --withdrawal-type 0x02 \\
    --withdrawal-address 0x1234... --keystore-password mypass --import-keys --install-deps

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
                install_deposit_cli
                exit $?
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

    # Import keys if requested
    if [[ "$IMPORT_KEYS" == "true" ]]; then
        local client
        client=$(detect_client)
        if ! import_keys_to_client "$client" "$keystore_dir" "$KEYSTORE_PASSWORD"; then
            log_warn "Key import failed, but keys were generated successfully"
        fi
    fi

    # Print deposit command
    print_deposit_command "$deposit_data_file"

    log_info "Validator deployment complete!"
    log_info "Keystore directory: $keystore_dir"
    log_info "Mnemonic and secrets are stored in: $OUTPUT_DIR"
    log_warn "Keep your mnemonic and password secure. Never share them."
}

main "$@"