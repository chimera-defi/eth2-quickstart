#!/bin/bash
# Validate measured bake-off campaign constants agree across the corpus (issue #230 item 3).
#
# docs/CLIENT_BAKEOFF_RESULTS.md is the arbiter. The same measured claims are repeated across
# the operator guide, four rendered frontend/app/blog/*/page.tsx pages, the deck, and other
# in-repo markdown sources — a value corrected in one artifact and missed in another has shipped
# to production more than once (see issue #230 and the PRs it links).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if ! command -v rg >/dev/null 2>&1; then
    echo "[ERROR] ripgrep (rg) is required by this check but is not installed." >&2
    exit 2
fi

FAILED=0

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1"
}

ARBITER="docs/CLIENT_BAKEOFF_RESULTS.md"

# Every artifact that carries these measured claims.
ALL_ARTIFACTS=(
    "$ARBITER"
    "docs/blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md"
    "docs/CLIENT_BAKEOFF_BLOG.md"
    "docs/CLIENT_BAKEOFF_HARNESS.md"
    "docs/HOW_WE_TESTED_WITH_CLAUDE.md"
    "frontend/app/blog/bakeoff-harness/page.tsx"
    "frontend/app/blog/bakeoff-results/page.tsx"
    "frontend/app/blog/ethereum-client-bakeoff/page.tsx"
    "frontend/app/blog/how-we-tested-with-claude/page.tsx"
    "frontend/public/deck/bakeoff.html"
)

# The current-state result/guidance surface: files that state nethermind's footprint as an
# operator-facing headline. Excludes the two methodology/timeline narratives (HOW_WE_TESTED /
# its page, and the harness doc/page), where the same figure legitimately appears as a dated
# historical log entry (e.g. "2026-08-01: re-measured ~1.06 TiB") without repeating the
# minimal-history caveat every time, and where an unrelated "~1.06 TiB" also appears describing
# a reth compaction sample, not nethermind.
RESULTS_SURFACE=(
    "$ARBITER"
    "docs/blog/CLIENT_BAKEOFF_OPERATOR_GUIDE.md"
    "docs/CLIENT_BAKEOFF_BLOG.md"
    "frontend/app/blog/ethereum-client-bakeoff/page.tsx"
    "frontend/app/blog/bakeoff-results/page.tsx"
    "frontend/public/deck/bakeoff.html"
)

# ---------------------------------------------------------------------------
# 1. Restart-resume rate. The arbiter's measured EXP-A value is the source of truth; every
#    other artifact's "N blocks/min" mention must equal it.
# ---------------------------------------------------------------------------
check_restart_rate_consistency() {
    log_info "Checking restart-resume rate (blocks/min) consistency..."

    local canonical
    canonical=$(rg -o -r '$1' -e '~([0-9]+) blocks/min' "$ARBITER" | sort -u || true)

    if [[ -z "$canonical" ]]; then
        log_error "$ARBITER: no '~N blocks/min' restart-resume rate found — the arbiter claim was reworded; update this check's pattern"
        FAILED=1
        return
    fi
    if [[ "$(printf '%s\n' "$canonical" | wc -l)" -gt 1 ]]; then
        log_error "$ARBITER: multiple distinct blocks/min values found ($(printf '%s ' "$canonical")) — the arbiter is internally inconsistent"
        FAILED=1
        return
    fi

    local file line value
    for file in "${ALL_ARTIFACTS[@]}"; do
        [[ "$file" == "$ARBITER" ]] && continue
        [[ -f "$file" ]] || continue
        while IFS=: read -r line value; do
            [[ -z "$line" ]] && continue
            if [[ "$value" != "$canonical" ]]; then
                log_error "$file:$line restart rate '~${value} blocks/min' disagrees with $ARBITER's measured ~${canonical} blocks/min"
                FAILED=1
            fi
        done < <(rg -n -o -r '$1' -e '~?([0-9]+)[[:space:]]*(?:blocks|blk)/min' "$file" 2>/dev/null || true)
    done
}

# ---------------------------------------------------------------------------
# 2. Steady-state/restart-resume phase cutoff date ("the Aug 3 cutoff"). Two artifacts state it
#    as an explicit literal: the methodology doc's prose and the deck's campaign-range kicker.
# ---------------------------------------------------------------------------
check_campaign_cutoff_consistency() {
    log_info "Checking campaign steady-state cutoff date consistency..."

    local narrative="docs/HOW_WE_TESTED_WITH_CLAUDE.md"
    local deck="frontend/public/deck/bakeoff.html"

    local narrative_line narrative_day deck_line deck_day
    narrative_line=$(rg -n -m1 -e 'through August [0-9]+' "$narrative" 2>/dev/null | cut -d: -f1 || true)
    narrative_day=$(rg -o -m1 -r '$1' -e 'through August ([0-9]+)' "$narrative" 2>/dev/null || true)
    deck_line=$(rg -n -m1 -e '2026-06-22.{1,5}2026-08-[0-9]{2}' "$deck" 2>/dev/null | cut -d: -f1 || true)
    deck_day=$(rg -o -m1 -r '$1' -e '2026-06-22.{1,5}2026-08-([0-9]{2})' "$deck" 2>/dev/null || true)

    if [[ -z "${narrative_day:-}" ]]; then
        log_error "$narrative: no 'through August N' steady-state cutoff phrase found — the anchor this check relies on was reworded"
        FAILED=1
        return
    fi
    if [[ -z "${deck_day:-}" ]]; then
        log_error "$deck: no '2026-06-22 ... 2026-08-NN' campaign-range kicker found — the anchor this check relies on was reworded"
        FAILED=1
        return
    fi

    local narrative_num=$((10#$narrative_day))
    local deck_num=$((10#$deck_day))
    if [[ "$narrative_num" -ne "$deck_num" ]]; then
        log_error "$deck:$deck_line campaign cutoff '2026-08-${deck_day}' disagrees with $narrative:$narrative_line's 'through August ${narrative_day}'"
        FAILED=1
    fi
}

# ---------------------------------------------------------------------------
# 3. Fresh/rebuilt-datadir qualification. Nethermind's full-history footprint (~1.06 TiB) is an
#    opt-in, not the shipped default — any artifact that states the full-history headline must
#    also mention the minimal-history default it now ships with, or an operator reading only
#    that artifact will size for the wrong number.
# ---------------------------------------------------------------------------
check_nethermind_history_caveat() {
    log_info "Checking nethermind full-history headline pairs with the minimal-history caveat..."

    local trigger='1\.06 TiB'
    local required='minimal-history|NETHERMIND_FULL_HISTORY|25[0-9][^0-9]{1,3}28[0-9] ?GiB'

    local file first_line
    for file in "${RESULTS_SURFACE[@]}"; do
        [[ -f "$file" ]] || continue
        if rg -q -e "$trigger" "$file"; then
            if ! rg -q -e "$required" "$file"; then
                first_line=$(rg -n -m1 -e "$trigger" "$file" | cut -d: -f1)
                log_error "$file:$first_line states nethermind's full-history '~1.06 TiB' footprint but never mentions the minimal-history default (NETHERMIND_FULL_HISTORY / ~250-280 GiB) anywhere in this file — set on a fresh/rebuilt datadir, per $ARBITER — an operator reading only this file will size for the wrong default"
                FAILED=1
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
# 4. Regression guard: values already found wrong and corrected must not reappear anywhere.
# ---------------------------------------------------------------------------
check_no_stale_regressions() {
    log_info "Checking for regression to previously-corrected values..."

    # Word-boundary-anchored: a plain -F fixed-string match would also fire inside an unrelated
    # future number, e.g. "16.8×" contains "6.8×" and "1307 blocks/min" contains "307 blocks/min".
    # \b works here because digit-adjacent-to-digit is not a word-boundary transition in the
    # default (Unicode-aware) regex engine, so no lookbehind is needed.
    local display=("307 blocks/min" "307 blk/min" "6.8×")
    local patterns=('\b307 blocks/min\b' '\b307 blk/min\b' '\b6\.8×')
    local reasons=(
        "nethermind's restart-resume rate is measured at ~302 blocks/min, not 307 (see $ARBITER EXP-A)"
        "nethermind's restart-resume rate is measured at ~302 blocks/min, not 307 (see $ARBITER EXP-A)"
        "the nimbus/lighthouse CL footprint ratio is ~6.9x (6.856 rounds up), not 6.8x"
    )

    local i pattern file line
    for i in "${!patterns[@]}"; do
        pattern="${patterns[$i]}"
        for file in "${ALL_ARTIFACTS[@]}"; do
            [[ -f "$file" ]] || continue
            while IFS=: read -r line _; do
                [[ -z "$line" ]] && continue
                log_error "$file:$line found previously-corrected stale value '${display[$i]}' — ${reasons[$i]}"
                FAILED=1
            done < <(rg -n -e "$pattern" "$file" 2>/dev/null || true)
        done
    done
}

# ---------------------------------------------------------------------------
# 5. Corpus coverage: warn (don't fail — a deletion may be intentional) if a listed artifact has
#    gone missing, so a rename silently shrinking this check's coverage doesn't go unnoticed.
# ---------------------------------------------------------------------------
check_corpus_files_exist() {
    local file
    for file in "${ALL_ARTIFACTS[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "[WARN] $file is listed in ALL_ARTIFACTS but no longer exists — if renamed, update test/ci_test_campaign_constants.sh; if intentionally removed, drop it from the list"
        fi
    done
}

check_corpus_files_exist
check_restart_rate_consistency
check_campaign_cutoff_consistency
check_nethermind_history_caveat
check_no_stale_regressions

if [[ "$FAILED" -ne 0 ]]; then
    log_error "Campaign constants consistency checks failed"
    exit 1
fi

log_info "Campaign constants consistency checks passed"
