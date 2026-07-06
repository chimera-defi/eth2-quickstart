#!/bin/bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/test/bakeoff/lib.sh"

# Extract the $HOME/... entries from purge_ethereum_data.sh DATA_DIRS block.
# shellcheck disable=SC2016
purge_list="$(awk '/^DATA_DIRS=\(/{f=1;next} /^\)/{f=0} f' \
  "$REPO_ROOT/install/utils/purge_ethereum_data.sh" \
  | grep -oE '\$HOME[^"]*' | sort -u)"
# shellcheck disable=SC2016
lib_list="$(printf '%s\n' "${BAKEOFF_DATA_DIRS[@]}" \
  | sed "s#$HOME#\$HOME#" | grep -E '^\$HOME' | sort -u)"

if [[ "$purge_list" == "$lib_list" ]]; then
  echo "PASS: BAKEOFF_DATA_DIRS matches purge_ethereum_data.sh DATA_DIRS"
else
  echo "FAIL: data-dir drift detected" >&2
  diff <(echo "$purge_list") <(echo "$lib_list") || true
  exit 1
fi
