#!/bin/bash
# Bake-off shared library. Source me; do not execute.
# shellcheck disable=SC2034

# Canonical default-data directories. KEEP IN SYNC with the DATA_DIRS array in
# install/utils/purge_ethereum_data.sh — test_data_dirs_sync.sh enforces this.
BAKEOFF_DATA_DIRS=(
  "$HOME/.ethereum"
  "$HOME/.local/share/nethermind"
  "$HOME/.local/share/besu"
  "$HOME/.local/share/erigon"
  "$HOME/.local/share/reth"
  "$HOME/.local/share/nimbus-eth1"
  "$HOME/ethrex/data"
  "$HOME/.local/share/prysm"
  "$HOME/.eth2"
  "$HOME/.lighthouse"
  "$HOME/.local/share/teku"
  "$HOME/.local/share/nimbus"
  "$HOME/.local/share/lodestar"
  "$HOME/.local/share/grandine"
  "$HOME/mev-boost"
  "$HOME/commit-boost"
  "$HOME/ethgas"
)

bakeoff_snapshot_disk() {
  local outfile="$1"
  {
    printf 'path\tbytes\thuman\n'
    local path bytes human
    for path in "${BAKEOFF_DATA_DIRS[@]}"; do
      if [[ -e "$path" ]]; then
        bytes="$(du -sb "$path" 2>/dev/null | awk '{print $1}')"
        human="$(du -sh "$path" 2>/dev/null | awk '{print $1}')"
        printf '%s\t%s\t%s\n' "$path" "${bytes:-0}" "${human:-0}"
      fi
    done
    df -B1 / | awk 'NR==2{print "filesystem:/\tused_bytes="$3"\tavailable_bytes="$4}'
  } > "$outfile"
}

bakeoff_probe_execution_sync() {
  curl -sS --max-time 5 -H 'Content-Type: application/json' \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    http://127.0.0.1:8545 2>/dev/null \
    || printf '{"error":"execution_rpc_unavailable"}'
}

bakeoff_probe_beacon_sync() {
  local url body
  for url in \
    http://127.0.0.1:3500/eth/v1/node/syncing \
    http://127.0.0.1:5051/eth/v1/node/syncing \
    http://127.0.0.1:5052/eth/v1/node/syncing \
    http://127.0.0.1:9596/eth/v1/node/syncing; do
    body="$(curl -sS --max-time 5 "$url" 2>/dev/null || true)"
    if [[ -n "$body" ]]; then
      printf '%s' "$body"
      return 0
    fi
  done
  printf '{"error":"beacon_rest_unavailable"}'
}

bakeoff_snapshot_processes() {
  ps -eo pid=,comm=,%cpu=,%mem=,rss=,vsz=,etime=,args= \
    | awk '/geth|erigon|reth|Nethermind|besu|ethrex|nimbus|prysm|beacon-chain|lighthouse|teku|lodestar|grandine/ {print}' \
    | jq -R -s 'split("\n")[:-1]'
}

bakeoff_services_alive() {
  systemctl is-active --quiet eth1.service && systemctl is-active --quiet cl.service
}

bakeoff_write_sample() {
  local out_dir="$1" repo_root="$2" tmp_dir
  tmp_dir="$out_dir/tmp"
  mkdir -p "$tmp_dir"
  bakeoff_snapshot_disk "$tmp_dir/disk.tsv" || true
  bakeoff_probe_execution_sync > "$tmp_dir/execution-sync.json" || true
  bakeoff_probe_beacon_sync   > "$tmp_dir/beacon-sync.json"   || true
  bakeoff_snapshot_processes  > "$tmp_dir/processes.json"     || true
  ( cd "$repo_root" && timeout 30 ./scripts/eth2qs.sh doctor --json ) > "$tmp_dir/doctor.json" 2>&1 || true
  ( cd "$repo_root" && timeout 30 ./scripts/eth2qs.sh stats  --json ) > "$tmp_dir/stats.json"  2>&1 || true

  local alive="down"
  if bakeoff_services_alive; then alive="up"; fi

  if ! jq -cn \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg alive "$alive" \
    --rawfile disk "$tmp_dir/disk.tsv" \
    --rawfile execution "$tmp_dir/execution-sync.json" \
    --rawfile beacon "$tmp_dir/beacon-sync.json" \
    --rawfile processes "$tmp_dir/processes.json" \
    --rawfile doctor "$tmp_dir/doctor.json" \
    --rawfile stats "$tmp_dir/stats.json" \
    '{
      timestamp_utc: $ts,
      services_alive: $alive,
      disk_tsv: $disk,
      execution_sync: (($execution | fromjson?) // {raw: $execution}),
      beacon_sync: (($beacon | fromjson?) // {raw: $beacon}),
      processes: (($processes | fromjson?) // []),
      doctor: (($doctor | fromjson?) // {raw: $doctor}),
      stats: (($stats | fromjson?) // {raw: $stats})
    }' >> "$out_dir/samples.jsonl"; then
    log_warn "sample write failed (non-fatal)"
    return 0
  fi
}

bakeoff_is_synced() {
  # Returns 0 only when the node is fully synced to head.
  local b e
  b="$(bakeoff_probe_beacon_sync)"; e="$(bakeoff_probe_execution_sync)"
  # Beacon: data present, sync_distance<=4, not optimistic, EL not offline.
  echo "$b" | jq -e '.data and (.data.sync_distance|tonumber) <= 4 and (.data.is_optimistic==false) and (.data.el_offline==false)' >/dev/null 2>&1 || return 1
  # Execution: synced when eth_syncing is boolean false OR when it returns a
  # progress object where currentBlock==highestBlock (nethermind-style caught-up).
  # highestBlock != "0x0" guards against the pre-sync zero state.
  echo "$e" | jq -e '
    (.result == false)
    or ( ((.result|type) == "object")
         and (.result.currentBlock == .result.highestBlock)
         and (.result.highestBlock != "0x0") )
  ' >/dev/null 2>&1 || return 1
  return 0
}

# bakeoff_check_config_optimal <el> <cl> <out_dir>
#
# Inspects the running config (via systemctl cat) for history-prune tokens.
# Writes config_optimal=yes|no and config_optimal_detail=<...> to <out_dir>/env.txt.
# On a miss: touches <out_dir>/.config-not-optimal and logs an error.
# Never aborts the run — always returns 0.
#
# Token table (must stay in sync with WS2/WS3 flags):
#   EL:
#     geth        -> --history.chain (postmerge)
#     nethermind  -> AncientBodiesBarrier AND PivotNumber != 0
#     erigon      -> prune.mode=full  (or prune.mode = full)
#     reth        -> --prune.bodies.pre-merge AND --prune.receipts.pre-merge
#     besu        -> history-expiry-prune=true
#     nimbus_eth1 -> prune = true
#     ethrex      -> optimal-by-absence: no lever; check --syncmode snap present
#   CL:
#     prysm       -> --beacon-db-pruning or beacon-db-pruning:
#     lighthouse  -> checkpoint-sync-url (default prune ok)
#     teku        -> data-storage-mode.*minimal  (case-insensitive)
#     nimbus      -> history.*prune  (persistent config; checkpoint-sync is a
#                    one-shot bootstrap step, out of scope for this gate)
#     lodestar    -> pruneHistory.*true
#     grandine    -> --prune-storage
bakeoff_check_config_optimal() {
  local el="$1" cl="$2" out_dir="$3"
  local el_exec cl_exec el_conf cl_conf
  local miss_tokens="" found_tokens="" optimal="yes" detail=""

  # Collect running ExecStart lines from systemd units.
  el_exec="$(systemctl cat eth1.service 2>/dev/null | grep -i ExecStart || true)"
  cl_exec="$(systemctl cat cl.service   2>/dev/null | grep -i ExecStart || true)"

  # Also pull any config files referenced on the ExecStart lines.
  # Most clients pass --config-file, but lodestar uses --rcConfig
  # (install/consensus/lodestar.sh) — match both so cl_conf isn't silently empty.
  local el_conf_path cl_conf_path
  el_conf_path="$(echo "$el_exec" | grep -oP '(?<=--config-file[= ])\S+|(?<=--rcConfig[= ])\S+' | head -1 || true)"
  cl_conf_path="$(echo "$cl_exec" | grep -oP '(?<=--config-file[= ])\S+|(?<=--rcConfig[= ])\S+' | head -1 || true)"
  if [[ -n "$el_conf_path" && -f "$el_conf_path" ]]; then el_conf="$(cat "$el_conf_path")"; else el_conf=""; fi
  if [[ -n "$cl_conf_path" && -f "$cl_conf_path" ]]; then cl_conf="$(cat "$cl_conf_path")"; else cl_conf=""; fi

  # Helper: check a token in exec+conf combined text; append to found/miss lists.
  # NOTE: pattern is passed after `--` so leading-dash patterns (e.g. --prune-storage)
  # are treated as the PATTERN operand, not misparsed as a grep option (which would
  # otherwise exit 2 and be silently swallowed by the 2>/dev/null as a false "miss").
  _has_token() {
    local label="$1" pattern="$2" haystack="$3"
    if echo "$haystack" | grep -qP -- "$pattern" 2>/dev/null; then
      found_tokens="${found_tokens:+$found_tokens;}$label"
    else
      miss_tokens="${miss_tokens:+$miss_tokens;}$label"
      optimal="no"
    fi
  }

  # --- EL checks ---
  local el_combined="$el_exec $el_conf"
  case "$el" in
    geth)
      _has_token "geth:history.chain" 'history\.chain' "$el_combined"
      ;;
    nethermind)
      _has_token "nethermind:AncientBodiesBarrier" 'AncientBodiesBarrier' "$el_combined"
      # PivotNumber must be non-zero (zero pivot means snap is inert)
      local pivot
      pivot="$(echo "$el_combined" | grep -oP 'PivotNumber\s*[=:]\s*\K[0-9]+' | head -1 || echo "0")"
      if [[ "${pivot:-0}" -gt 0 ]]; then
        found_tokens="${found_tokens:+$found_tokens;}nethermind:PivotNumber=$pivot"
      else
        miss_tokens="${miss_tokens:+$miss_tokens;}nethermind:PivotNumber!=0"
        optimal="no"
      fi
      ;;
    erigon)
      _has_token "erigon:prune.mode=full" 'prune\.mode\s*=\s*full' "$el_combined"
      ;;
    reth)
      _has_token "reth:prune.bodies.pre-merge"   '--prune\.bodies\.pre-merge'   "$el_combined"
      _has_token "reth:prune.receipts.pre-merge" '--prune\.receipts\.pre-merge' "$el_combined"
      ;;
    besu)
      _has_token "besu:history-expiry-prune=true" 'history-expiry-prune\s*=\s*true' "$el_combined"
      ;;
    nimbus_eth1)
      _has_token "nimbus_eth1:prune=true" 'prune\s*=\s*true' "$el_combined"
      ;;
    ethrex)
      # ethrex has no history-prune lever; optimal == snap sync present.
      _has_token "ethrex:syncmode=snap" 'syncmode\s*[= ]\s*snap' "$el_combined"
      ;;
    *)
      found_tokens="${found_tokens:+$found_tokens;}el:$el=unchecked"
      ;;
  esac

  # --- CL checks ---
  local cl_combined="$cl_exec $cl_conf"
  case "$cl" in
    prysm)
      _has_token "prysm:beacon-db-pruning" 'beacon-db-pruning' "$cl_combined"
      ;;
    lighthouse)
      _has_token "lighthouse:checkpoint-sync-url" 'checkpoint-sync-url' "$cl_combined"
      ;;
    teku)
      _has_token "teku:data-storage-mode=minimal" 'data-storage-mode[=: ]+["\047]?[Mm]inimal' "$cl_combined"
      ;;
    nimbus)
      # trustedNodeSync/--trusted-node-url only appear in the one-shot bootstrap
      # subcommand run before the service starts (install/consensus/nimbus.sh) —
      # never in the persistent ExecStart or nimbus.toml — so they can't be
      # observed here and checkpoint sync is out of scope for this "is the
      # running config optimal" gate. Check the persistent history-prune
      # setting instead (configs/nimbus/nimbus_base.toml sets history = "prune").
      _has_token "nimbus:history=prune" 'history\s*=\s*"?prune"?' "$cl_combined"
      ;;
    lodestar)
      _has_token "lodestar:pruneHistory=true" 'pruneHistory.*true|chain\.pruneHistory' "$cl_combined"
      ;;
    grandine)
      _has_token "grandine:prune-storage" '--prune-storage' "$cl_combined"
      ;;
    *)
      found_tokens="${found_tokens:+$found_tokens;}cl:$cl=unchecked"
      ;;
  esac

  # Build detail string.
  detail="found=${found_tokens:-none};missed=${miss_tokens:-none}"

  # Write to env.txt.
  {
    echo "config_optimal=$optimal"
    echo "config_optimal_detail=$detail"
  } >> "$out_dir/env.txt"

  if [[ "$optimal" != "yes" ]]; then
    touch "$out_dir/.config-not-optimal"
    log_error "config not optimal for ${el}/${cl}: $detail"
  fi

  return 0
}
