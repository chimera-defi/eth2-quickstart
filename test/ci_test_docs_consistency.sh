#!/bin/bash
# Validate active documentation consistency.
# - no broken local markdown links in active docs
# - no references to explicitly retired legacy files/flags

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

FAILED=0
# docs/blog/*.md is a real, published doc directory (the bake-off operator guide lives
# there and campaign-constants.yml already guards it). A non-recursive docs/*.md glob
# silently excluded it, so nothing under docs/blog/ was ever link-checked.
# nullglob keeps an empty subdirectory from degrading to a literal unexpanded pattern.
shopt -s nullglob
ACTIVE_DOCS=(README.md docs/*.md docs/blog/*.md)
shopt -u nullglob
RETIREMENT_SCOPE_DOCS=()

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

# Both checks below drive `rg`. Ripgrep is NOT preinstalled on GitHub's ubuntu-latest
# runners, and neither caller (ci.yml's docs-consistency job, shellcheck.yml) installed
# it. Because the link scan reads `rg` through a process substitution -- where a failure
# cannot trip errexit -- a missing rg made the loop iterate zero times and the script
# still exited 0, reporting "checks passed" while checking nothing at all. Fail closed
# instead: a dependency this check cannot run without must be an error, never a silent skip.
# Probe with --version rather than `command -v` alone: a shim that is present on PATH but
# non-functional fails the same way an absent binary does, and must be caught the same way.
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1 || ! "$1" --version >/dev/null 2>&1; then
        log_error "Required command '$1' is missing or not functional; this check cannot run without it."
        log_error "Install it first (Debian/Ubuntu: sudo apt-get install -y $2)."
        exit 1
    fi
}

check_local_markdown_links() {
    log_info "Checking local markdown links in active docs..."

    local file raw line rest target path dir resolved

    while IFS= read -r file; do
        while IFS= read -r raw; do
            line="${raw%%:*}"
            rest="${raw#*:}"
            target="$(printf '%s\n' "$rest" | sed -nE 's/.*\]\(([^)]+)\).*/\1/p')"
            [[ -z "$target" ]] && continue

            # Ignore non-local link targets.
            if [[ "$target" =~ ^# ]] || [[ "$target" =~ ^https?:// ]] || [[ "$target" =~ ^mailto: ]]; then
                continue
            fi

            # Remove optional markdown title and anchor/query suffixes.
            path=$(echo "$target" | sed -E 's/[[:space:]]+"[^"]*"$//')
            path=${path%%#*}
            path=${path%%\?*}
            [[ -z "$path" ]] && continue

            dir=$(dirname "$file")
            resolved=$(realpath -m "$dir/$path")

            if [[ ! -e "$resolved" ]]; then
                log_error "$file:$line broken link: $target"
                FAILED=1
            fi
        done < <(rg -n '\[[^]]+\]\(([^)]+)\)' "$file")
    done < <(printf "%s\n" "${ACTIVE_DOCS[@]}")
}

check_retired_reference_absence() {
    log_info "Checking active docs do not reference retired legacy artifacts..."

    # Explicitly retired/obsolete references that should not appear in active docs.
    local retired_patterns=(
        'install/examples/run_prysm_checkpt_sync.sh'
        'checkpoint_ssz'
        'checkpoint-block'
    )

    local pattern
    for pattern in "${retired_patterns[@]}"; do
        if rg -n "$pattern" "${RETIREMENT_SCOPE_DOCS[@]}" >/tmp/docs_consistency_match.txt 2>/dev/null; then
            log_error "Found retired reference pattern '$pattern' in active docs:"
            cat /tmp/docs_consistency_match.txt
            FAILED=1
        fi
    done
    rm -f /tmp/docs_consistency_match.txt
}

init_doc_scopes() {
    local file
    for file in "${ACTIVE_DOCS[@]}"; do
        # Keep handoff as session memory, not product documentation.
        if [[ "$file" == "docs/agent-handoff.md" ]]; then
            continue
        fi
        RETIREMENT_SCOPE_DOCS+=("$file")
    done
}

require_cmd rg ripgrep
init_doc_scopes
check_local_markdown_links
check_retired_reference_absence

if [[ "$FAILED" -ne 0 ]]; then
    log_error "Docs consistency checks failed"
    exit 1
fi

log_info "Docs consistency checks passed"
