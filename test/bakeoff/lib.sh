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
