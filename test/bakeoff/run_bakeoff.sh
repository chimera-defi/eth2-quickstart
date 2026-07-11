#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../../lib/common_functions.sh
source "$REPO_ROOT/lib/common_functions.sh"

stage=""
only=""
force="no"
for arg in "$@"; do
  case "$arg" in
    --stage=*) stage="${arg#*=}" ;;
    --only=*)  only="${arg#*=}" ;;
    --force)   force="yes" ;;
    *) echo "Unknown arg: $arg" >&2; exit 1 ;;
  esac
done
[[ "$stage" == "triage" || "$stage" == "full" ]] || { echo "Usage: run_bakeoff.sh --stage=triage|full [--only=a__b,...] [--force]" >&2; exit 1; }

artifact_root="$REPO_ROOT/artifacts/${ETH2QS_BAKEOFF_RUN_ID:-client-bakeoff-2026-06-22}"
manifest="$REPO_ROOT/test/bakeoff/candidates.tsv"
user_cfg="$REPO_ROOT/config/user_config.env"
bake_cfg="$REPO_ROOT/config/bakeoff.env"
backup="$REPO_ROOT/config/user_config.env.bakeoff-backup"
mkdir -p "$artifact_root/preflight"

if [[ "$stage" == "triage" ]]; then
  export ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-5400}"
  export ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-120}"
else
  # Full sync-to-completion: 72h ceiling, coarse sampling.
  export ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS="${ETH2QS_BAKEOFF_SYNC_WINDOW_SECONDS:-259200}"
  export ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS="${ETH2QS_BAKEOFF_SAMPLE_INTERVAL_SECONDS:-600}"
fi
export ETH2QS_BAKEOFF_INSTALL_TIMEOUT="${ETH2QS_BAKEOFF_INSTALL_TIMEOUT:-90m}"
[[ "$force" == "yes" ]] && export ETH2QS_BAKEOFF_FORCE=yes

# Install bake-off config overrides (restore on exit).
restore_cfg() {
  if [[ -f "$backup" ]]; then mv "$backup" "$user_cfg"; else rm -f "$user_cfg"; fi
  log_info "Restored original user_config.env"
}
trap restore_cfg EXIT
[[ -f "$user_cfg" ]] && cp "$user_cfg" "$backup"
cp "$bake_cfg" "$user_cfg"
log_info "Installed bake-off config overrides as user_config.env"

# Build candidate list.
mapfile -t all_pairs < <(awk -F'\t' 'NF>=2{print $1"__"$2}' "$manifest")
selected=()
if [[ -n "$only" ]]; then
  IFS=',' read -r -a selected <<< "$only"
elif [[ "$stage" == "full" ]]; then
  for pair in "${all_pairs[@]}"; do
    env_file="$artifact_root/$pair/env.txt"
    if [[ -f "$env_file" ]] && grep -q '^install_exit_code=0$' "$env_file"; then
      selected+=("$pair")
    fi
  done
  log_info "Full stage selecting triage-passing candidates: ${selected[*]:-none}"
else
  selected=("${all_pairs[@]}")
fi

# Run sequentially, tolerant of individual failures.
summary_log="$artifact_root/orchestrator-${stage}.log"
: > "$summary_log"
for pair in "${selected[@]}"; do
  execution="${pair%%__*}"
  consensus="${pair##*__}"
  log_info "=== [$stage] candidate: $execution + $consensus ==="
  set +e
  "$REPO_ROOT/test/bakeoff/run_candidate.sh" "$execution" "$consensus"
  rc=$?
  set -e
  echo "$pair rc=$rc" | tee -a "$summary_log"
done

log_info "Stage $stage complete. Per-candidate results in $summary_log"
"$REPO_ROOT/test/bakeoff/summarize.sh" || log_warn "summarize.sh reported an issue"
