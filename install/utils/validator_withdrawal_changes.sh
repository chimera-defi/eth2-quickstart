#!/bin/bash

# Eth2 Quick Start — Validator Withdrawal Credential Changes
# Generates and optionally submits BLS-to-execution change messages for
# validators that still use 0x00 withdrawal credentials.
#
# Usage:
#   ./install/utils/validator_withdrawal_changes.sh
#   ./install/utils/validator_withdrawal_changes.sh --generate --submit --yes
#   ./scripts/eth2qs.sh validator-withdrawal-changes --generate --submit

set -euo pipefail

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

SELECTOR="0x00"
CHAIN="mainnet"
OUT_DIR="$ROOT_DIR/validator_withdrawal_changes"
WITHDRAWAL_ADDRESS=""
VALIDATORS_JSON_FILE=""
MNEMONIC_FILE=""
MNEMONIC_PASSWORD_FILE=""
DEPOSIT_TOOL="auto"
YES=false
GENERATE=false
SUBMIT=false
BEACON_URL_OVERRIDE=""
SELECTED_INDICES=""
SELECTED_WITHDRAWAL_CREDENTIALS=""
GENERATED_OUTPUT_DIR=""
MANIFEST_FILENAME=".eth2qs-withdrawal-manifest"
DRY_RUN=false

usage() {
    cat <<'USAGE'
Usage: ./install/utils/validator_withdrawal_changes.sh [options]

Options:
  --credential-type <0x00|0x01|0x02|all>
                              Filter the local inventory before taking action.
                              Default: 0x00.
  --generate                  Generate BLS-to-execution change JSON files.
  --submit                    Submit generated JSON files to the beacon node.
  --yes                       Skip the final confirmation prompt before submit.
  --dry-run                   Print the planned actions without writing or submitting.
  --withdrawal-address <addr> Execution address to write into the change message.
  --mnemonic-file <path>      File containing the withdrawal mnemonic.
  --mnemonic-password-file <path>
                              File containing the mnemonic password (optional).
  --validators-json <path>    Use a fixture or captured validator_list --json output.
  --beacon-url <url>          Override the beacon REST API base URL.
  --chain <name>              Signing chain for the deposit CLI (default: mainnet).
  --out-dir <path>            Folder to write generated messages (default: validator_withdrawal_changes/).
  --deposit-tool <auto|deposit|deposit-sh>
                              Select the local deposit CLI launcher.
  --help                      Show this help.

This helper focuses on BLS-to-execution changes for 0x00 validators.
It shows the local validator inventory, filters by withdrawal credential type,
generates signed change messages with the deposit CLI, and can submit them
to the local beacon node REST API.
USAGE
}

load_inventory_json() {
    if [[ -n "$VALIDATORS_JSON_FILE" ]]; then
        cat "$VALIDATORS_JSON_FILE"
        return
    fi
    if [[ ! -x "$SCRIPT_DIR/validator_list.sh" ]]; then
        log_error "validator_list.sh not found or not executable at $SCRIPT_DIR"
        return 1
    fi
    "$SCRIPT_DIR/validator_list.sh" --json
}

filter_inventory_json() {
    local input_file="$1"
    local output_file="$2"
    local selector="$3"

    python3 - "$input_file" "$output_file" "$selector" <<'PYEOF'
import json, sys

input_path, output_path, selector = sys.argv[1:4]
with open(input_path) as fh:
    raw = json.load(fh)

validators = raw.get('validators', [])
selected = []
selector = selector.lower()
allowed = {s.strip().lower() for s in selector.split(',') if s.strip()}
if not allowed:
    allowed = {'all'}

for item in validators:
    cred = item.get('validator', {}).get('withdrawal_credentials', '') or ''
    cred_type = cred[:4].lower() if cred.startswith('0x') and len(cred) >= 4 else 'unknown'
    if 'all' not in allowed and cred_type not in allowed:
        continue
    row = dict(item)
    row['withdrawal_credential_type'] = cred_type
    selected.append(row)

raw['validators'] = selected
with open(output_path, 'w') as fh:
    json.dump(raw, fh, indent=2)
    fh.write('\n')
PYEOF
}

list_json_files() {
    local data_dir="$1"
    if [[ ! -d "$data_dir" ]]; then
        return 0
    fi
    find "$data_dir" -maxdepth 1 -type f -name '*.json' | sort
}

write_generation_manifest() {
    local target_dir="$1"
    local manifest_path="$target_dir/$MANIFEST_FILENAME"

    python3 - "$manifest_path" "$CHAIN" "$SELECTOR" "$SELECTED_INDICES" "$SELECTED_WITHDRAWAL_CREDENTIALS" "$WITHDRAWAL_ADDRESS" <<'PYEOF'
import json, sys
from datetime import datetime, timezone

manifest_path, chain, selector, selected_indices, selected_credentials, withdrawal_address = sys.argv[1:7]
manifest = {
    'generated_at_utc': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
    'tool': 'validator_withdrawal_changes',
    'chain': chain,
    'selector': selector,
    'validator_indices': selected_indices,
    'withdrawal_credentials': selected_credentials,
    'withdrawal_address': withdrawal_address,
    'expected_files': [
        f'bls_to_execution_change-{idx}.json'
        for idx in selected_indices.split(',')
        if idx
    ],
}
with open(manifest_path, 'w') as fh:
    json.dump(manifest, fh, indent=2, sort_keys=True)
    fh.write('\n')
PYEOF
}

validate_submission_manifest() {
    local input_dir="$1"
    local manifest_path="$input_dir/$MANIFEST_FILENAME"

    if [[ ! -f "$manifest_path" ]]; then
        log_error "Missing generation manifest in $input_dir. Run --generate first and submit from the generated staging directory."
        return 1
    fi

    python3 - "$manifest_path" "$SELECTOR" "$CHAIN" "$SELECTED_INDICES" "$SELECTED_WITHDRAWAL_CREDENTIALS" "$WITHDRAWAL_ADDRESS" "$input_dir" <<'PYEOF'
import json, os, sys

manifest_path, selector, chain, selected_indices, selected_credentials, withdrawal_address, input_dir = sys.argv[1:8]
with open(manifest_path) as fh:
    manifest = json.load(fh)

errors = []
expected = {
    'chain': chain,
    'selector': selector,
    'validator_indices': selected_indices,
    'withdrawal_credentials': selected_credentials,
}
if withdrawal_address:
    expected['withdrawal_address'] = withdrawal_address
for key, value in expected.items():
    if str(manifest.get(key, '')) != str(value):
        errors.append(f"{key} mismatch: manifest={manifest.get(key, '')!r} current={value!r}")

expected_files = sorted(manifest.get('expected_files', []))
actual_files = sorted(
    entry for entry in os.listdir(input_dir)
    if entry.endswith('.json') and entry != os.path.basename(manifest_path)
)
if expected_files != actual_files:
    errors.append(f"file set mismatch: expected={expected_files!r} actual={actual_files!r}")

if errors:
    for error in errors:
        sys.stderr.write(error + '\n')
    sys.exit(1)
PYEOF
}

format_command() {
    printf '%q ' "$@"
    printf '\n'
}

cleanup_stale_staging_dirs() {
    if [[ ! -d "$OUT_DIR" ]]; then
        return 0
    fi

    local removed=0
    while IFS= read -r -d '' dir; do
        rm -rf "$dir"
        removed=$((removed + 1))
    done < <(find "$OUT_DIR" -mindepth 1 -maxdepth 1 -type d -name 'run-*' -mtime +7 -print0 2>/dev/null || true)

    if [[ "$removed" -gt 0 ]]; then
        log_info "Removed $removed stale staging director$( [[ "$removed" -eq 1 ]] && echo 'y' || echo 'ies' )."
    fi
}

print_inventory_table() {
    local data_file="$1"
    python3 - "$data_file" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as fh:
    raw = json.load(fh)

rows = raw.get('validators', [])
if not rows:
    print('  No matching validators found.')
    sys.exit(0)

hdr = f"{'Index':<12} {'Public Key':<98} {'Status':<22} {'Balance (ETH)':<16} {'WCred'}"
print()
print(hdr)
print('-' * len(hdr))
for v in rows:
    idx = v.get('index', '?')
    pubkey = v.get('validator', {}).get('pubkey', '?')
    status = v.get('status', '?')
    bal = int(v.get('balance', 0)) / 1e9
    cred = v.get('validator', {}).get('withdrawal_credentials', '') or ''
    cred_type = cred[:4].lower() if cred.startswith('0x') and len(cred) >= 4 else v.get('withdrawal_credential_type', 'unknown')
    print(f"{idx:<12} {pubkey:<98} {status:<22} {bal:<16.6f} {cred_type}")
print('-' * len(hdr))
print(f"  {len(rows)} validator(s)")
print()
PYEOF
}

detect_deposit_launcher() {
    case "$DEPOSIT_TOOL" in
        deposit)
            if command -v deposit >/dev/null 2>&1; then
                printf '%s\n' deposit
                return 0
            fi
            ;;
        deposit-sh)
            if command -v deposit.sh >/dev/null 2>&1; then
                printf '%s\n' deposit.sh
                return 0
            fi
            ;;
        auto)
            if command -v deposit.sh >/dev/null 2>&1; then
                printf '%s\n' deposit.sh
                return 0
            fi
            if command -v deposit >/dev/null 2>&1; then
                printf '%s\n' deposit
                return 0
            fi
            ;;
        *)
            log_error "Unknown deposit tool selection: $DEPOSIT_TOOL"
            return 1
            ;;
    esac

    return 1
}

read_file_or_prompt() {
    local label="$1"
    local path="$2"
    local prompt_hidden="${3:-false}"
    local value=""

    if [[ -n "$path" ]]; then
        if [[ ! -f "$path" ]]; then
            log_error "$label file not found: $path"
            return 1
        fi
        value="$(tr -d '\n' < "$path")"
    else
        if [[ "$prompt_hidden" == "true" ]]; then
            read -rsp "  $label: " value
            printf '\n'
        else
            read -rp "  $label: " value
        fi
    fi

    if [[ -z "$value" ]]; then
        log_error "$label is required."
        return 1
    fi

    printf '%s\n' "$value"
}

generate_changes() {
    local launcher
    launcher=$(detect_deposit_launcher) || return 1

    if [[ -z "$WITHDRAWAL_ADDRESS" ]]; then
        log_error "--withdrawal-address is required when generating BLS-to-execution changes."
        return 1
    fi

    local mnemonic
    mnemonic=$(read_file_or_prompt "Withdrawal mnemonic" "$MNEMONIC_FILE" true) || return 1
    local mnemonic_password=""
    if [[ -n "$MNEMONIC_PASSWORD_FILE" ]]; then
        mnemonic_password=$(read_file_or_prompt "Mnemonic password" "$MNEMONIC_PASSWORD_FILE" true) || return 1
    fi

    cleanup_stale_staging_dirs

    local target_dir="$OUT_DIR"
    if [[ -d "$OUT_DIR" ]] && find "$OUT_DIR" -maxdepth 1 -type f -name '*.json' -print -quit | grep -q .; then
        target_dir="$(mktemp -d "$OUT_DIR/run-XXXXXX")"
        log_info "Using fresh staging directory: $target_dir"
    fi
    mkdir -p "$target_dir"
    GENERATED_OUTPUT_DIR="$target_dir"

    local args=(
        generate-bls-to-execution-change
        --bls_to_execution_changes_folder="$target_dir"
        --chain="$CHAIN"
        --mnemonic="$mnemonic"
        --validator_indices="$SELECTED_INDICES"
        --bls_withdrawal_credentials_list="$SELECTED_WITHDRAWAL_CREDENTIALS"
        --execution_address="$WITHDRAWAL_ADDRESS"
    )
    if [[ -n "$mnemonic_password" ]]; then
        args+=(--mnemonic_password="$mnemonic_password")
    fi

    log_info "Generating BLS-to-execution changes with $launcher"
    "$launcher" "${args[@]}"
    write_generation_manifest "$target_dir" || return 1
}

preview_generation() {
    local launcher="$1"
    local target_dir_hint="$2"

    log_info "Dry run: generation is disabled, but the planned command is:"
    if [[ -n "$launcher" ]]; then
        format_command "$launcher" \
            generate-bls-to-execution-change \
            --bls_to_execution_changes_folder="$target_dir_hint" \
            --chain="$CHAIN" \
            --mnemonic="<hidden>" \
            --validator_indices="$SELECTED_INDICES" \
            --bls_withdrawal_credentials_list="$SELECTED_WITHDRAWAL_CREDENTIALS" \
            --execution_address="$WITHDRAWAL_ADDRESS"
    else
        log_warn "Deposit CLI not found; install deposit.sh or deposit before generating for real."
    fi
}

preview_submission() {
    local input_dir="$1"
    local beacon_url="$2"

    if [[ -z "$beacon_url" ]]; then
        log_warn "Dry run: beacon URL is empty, submission cannot be previewed."
        return 0
    fi

    mapfile -t files < <(list_json_files "$input_dir")
    if [[ ${#files[@]} -eq 0 ]]; then
        if [[ -n "$SELECTED_INDICES" ]]; then
            local idx
            IFS=',' read -r -a idxs <<< "$SELECTED_INDICES"
            log_info "Dry run: submission would target these generated files:"
            for idx in "${idxs[@]}"; do
                [[ -n "$idx" ]] || continue
                printf '  %s\n' "bls_to_execution_change-${idx}.json"
            done
        else
            log_warn "Dry run: no JSON files are available to submit."
        fi
        return 0
    fi

    log_info "Dry run: submission would POST these files to ${beacon_url}/eth/v1/beacon/pool/bls_to_execution_changes:"
    local file
    for file in "${files[@]}"; do
        printf '  %s\n' "$(basename "$file")"
    done
}

submit_changes() {
    local input_dir="$1"
    local beacon_url="$2"

    if [[ -z "$beacon_url" ]]; then
        log_error "Beacon URL is required to submit changes."
        return 1
    fi

    validate_submission_manifest "$input_dir" || return 1

    if [[ "$YES" != true ]]; then
        printf '\n'
        read -rp "  Submit generated BLS-to-execution changes to $beacon_url? [y/N] " answer
        case "$answer" in
            y|Y|yes|YES) ;;
            *) log_warn "Submission aborted."; return 0 ;;
        esac
    fi

    mapfile -t files < <(list_json_files "$input_dir")
    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "No JSON files found in $input_dir"
        return 1
    fi

    local submitted=0
    local failed=0
    local file
    for file in "${files[@]}"; do
        log_info "Submitting $(basename "$file")"
        local response_file http_code
        response_file=$(mktemp /tmp/vwc_submit_XXXXXX.response)
        http_code=$(curl -sS \
            -X POST \
            -H "Content-Type: application/json" \
            --data-binary "@$file" \
            -o "$response_file" \
            -w '%{http_code}' \
            "$beacon_url/eth/v1/beacon/pool/bls_to_execution_changes" || true)

        if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
            submitted=$((submitted + 1))
            log_info "Accepted $(basename "$file") (HTTP $http_code)"
        else
            failed=$((failed + 1))
            log_error "Beacon rejected $(basename "$file") (HTTP ${http_code:-none})"
            if [[ -s "$response_file" ]]; then
                sed 's/^/  /' "$response_file" >&2
            fi
        fi
        rm -f "$response_file"
    done

    if [[ "$failed" -gt 0 ]]; then
        log_error "Submission summary: $submitted accepted, $failed failed."
        return 1
    fi

    log_info "Submission summary: $submitted accepted, 0 failed."
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --credential-type|--select)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --credential-type" >&2; exit 1; }
                SELECTOR="$1"
                ;;
            --generate)
                GENERATE=true
                ;;
            --submit)
                SUBMIT=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --yes)
                YES=true
                ;;
            --withdrawal-address|--execution-address|--eth1-withdrawal-address)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --withdrawal-address" >&2; exit 1; }
                WITHDRAWAL_ADDRESS="$1"
                ;;
            --mnemonic-file)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --mnemonic-file" >&2; exit 1; }
                MNEMONIC_FILE="$1"
                ;;
            --mnemonic-password-file)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --mnemonic-password-file" >&2; exit 1; }
                MNEMONIC_PASSWORD_FILE="$1"
                ;;
            --validators-json)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --validators-json" >&2; exit 1; }
                VALIDATORS_JSON_FILE="$1"
                ;;
            --beacon-url)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --beacon-url" >&2; exit 1; }
                BEACON_URL_OVERRIDE="$1"
                ;;
            --chain)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --chain" >&2; exit 1; }
                CHAIN="$1"
                ;;
            --out-dir)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --out-dir" >&2; exit 1; }
                OUT_DIR="$1"
                ;;
            --deposit-tool)
                shift
                [[ $# -gt 0 ]] || { echo "Missing value for --deposit-tool" >&2; exit 1; }
                DEPOSIT_TOOL="$1"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done

    local inventory_file
    inventory_file=$(mktemp /tmp/vwc_inventory_XXXXXX.json)
    local selected_file
    selected_file=$(mktemp /tmp/vwc_selected_XXXXXX.json)
    # shellcheck disable=SC2064
    trap "rm -f '$inventory_file' '$selected_file'" EXIT

    if ! load_inventory_json > "$inventory_file"; then
        log_error "Unable to load local validator inventory."
        return 1
    fi

    filter_inventory_json "$inventory_file" "$selected_file" "$SELECTOR"

    local client
    client=$(python3 - "$selected_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    raw = json.load(fh)
print(raw.get('client', 'unknown'))
PYEOF
)
    local beacon_url
    beacon_url=$(python3 - "$selected_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    raw = json.load(fh)
print(raw.get('beacon_url', ''))
PYEOF
)
    if [[ -n "$BEACON_URL_OVERRIDE" ]]; then
        beacon_url="$BEACON_URL_OVERRIDE"
    fi

    log_info "Detected consensus client: ${client}"
    log_info "Beacon API: ${beacon_url}"
    log_info "Credential filter: ${SELECTOR}"
    local beacon_query_status
    beacon_query_status=$(python3 - "$selected_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    raw = json.load(fh)
print(raw.get('beacon_query_status', 'unknown'))
PYEOF
)
    local inventory_snapshot
    inventory_snapshot=$(python3 - "$selected_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    raw = json.load(fh)
print(raw.get('generated_at_utc', 'unknown'))
PYEOF
)
    log_info "Inventory snapshot: ${inventory_snapshot}"
    if [[ "$beacon_query_status" != "ok" ]]; then
        log_warn "Validator inventory beacon query status: $beacon_query_status"
        log_warn "The snapshot may be incomplete or stale."
    fi

    print_inventory_table "$selected_file"

    local selection_snapshot
    selection_snapshot=$(python3 - "$selected_file" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as fh:
    raw = json.load(fh)
rows = raw.get('validators', [])
indices = []
creds = []
for v in rows:
    idx = str(v.get('index', '')).strip()
    if idx not in ('', 'None', '?'):
        indices.append(idx)
    cred = v.get('validator', {}).get('withdrawal_credentials', '') or ''
    if cred:
        creds.append(cred)
print('|'.join([
    str(len(rows)),
    ','.join(indices),
    ','.join(creds),
]))
PYEOF
)
    local count indices credentials
    IFS='|' read -r count indices credentials <<< "$selection_snapshot"
    if [[ "$count" -eq 0 ]]; then
        log_warn "No validators matched credential filter '$SELECTOR'."
        return 0
    fi
    SELECTED_INDICES="$indices"
    SELECTED_WITHDRAWAL_CREDENTIALS="$credentials"

    if [[ "$GENERATE" != true && "$SUBMIT" != true ]]; then
        log_info "Run again with --generate to create signed messages or --submit to POST existing JSON files."
        return 0
    fi

    if [[ "$SELECTOR" != "all" && "$SELECTOR" != "0x00" ]]; then
        log_warn "This helper is intended for 0x00 validators; selection '$SELECTOR' may not require a withdrawal change."
    fi

    if [[ "$DRY_RUN" == true ]]; then
        local launcher=""
        if [[ "$GENERATE" == true ]]; then
            launcher=$(detect_deposit_launcher 2>/dev/null || true)
        fi

        log_info "Dry run: no files will be written or submitted."
        log_info "Would affect ${count} validator(s): ${SELECTED_INDICES}"
        if [[ -n "$beacon_url" ]]; then
            if ! curl -sf --max-time 5 "$beacon_url/eth/v1/node/health" >/dev/null 2>&1; then
                log_warn "Beacon URL does not appear reachable right now: $beacon_url"
            fi
        fi

        if [[ "$GENERATE" == true ]]; then
            local planned_dir="$OUT_DIR"
            if [[ -d "$OUT_DIR" ]] && find "$OUT_DIR" -maxdepth 1 -type f -name '*.json' -print -quit | grep -q .; then
                log_info "Would stage into a fresh run-* directory under $OUT_DIR because JSON files already exist there."
            else
                log_info "Would stage into $planned_dir."
            fi
            preview_generation "$launcher" "$planned_dir"
        fi

        if [[ "$SUBMIT" == true ]]; then
            preview_submission "${GENERATED_OUTPUT_DIR:-$OUT_DIR}" "$beacon_url"
        fi
        return 0
    fi

    if [[ "$GENERATE" == true ]]; then
        generate_changes
        local generated_count
        generated_count=$(list_json_files "${GENERATED_OUTPUT_DIR:-$OUT_DIR}" | wc -l | tr -d ' ')
        if [[ "$generated_count" -eq 0 ]]; then
            log_error "Generation completed but no JSON files were produced."
            return 1
        fi
        log_info "Generated $generated_count JSON file(s) in ${GENERATED_OUTPUT_DIR:-$OUT_DIR}"
    fi

    if [[ "$SUBMIT" == true ]]; then
        submit_changes "${GENERATED_OUTPUT_DIR:-$OUT_DIR}" "$beacon_url"
    fi
}

main "$@"
