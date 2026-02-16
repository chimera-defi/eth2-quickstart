#!/bin/bash

# Help System Validation
# Validates scripts.manifest and help.sh output per HELP_SYSTEM_REARCH_SPEC.md
# Run: ./test/validate_help.sh
# Or via: ./test/run_tests.sh (includes this when --lint-only or default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PROJECT_ROOT/scripts.manifest"
HELP_SCRIPT="$PROJECT_ROOT/help.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

FAILED=0

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; FAILED=1; }

# Manifest exists
if [[ -f "$MANIFEST" ]]; then
    pass "scripts.manifest exists"
else
    fail "scripts.manifest not found"
    exit 1
fi

# help.sh exists
if [[ -f "$HELP_SCRIPT" ]]; then
    pass "help.sh exists"
else
    fail "help.sh not found"
    exit 1
fi

# help.sh exits 0
cd "$PROJECT_ROOT" || exit 1
if ./help.sh &>/dev/null; then
    pass "help.sh exits 0"
else
    fail "help.sh exits non-zero"
fi

# help.sh --help exits 0
if ./help.sh --help &>/dev/null; then
    pass "help.sh --help exits 0"
else
    fail "help.sh --help exits non-zero"
fi

# help.sh --markdown exits 0
if ./help.sh --markdown &>/dev/null; then
    pass "help.sh --markdown exits 0"
else
    fail "help.sh --markdown exits non-zero"
fi

# Manifest parses (has data lines with ::)
DATA_LINES=$(grep -c ' :: ' "$MANIFEST" 2>/dev/null || echo 0)
if [[ "$DATA_LINES" -gt 0 ]]; then
    pass "Manifest has parseable lines (:: delimiter)"
else
    fail "Manifest has no parseable lines"
fi

# All manifest paths exist
PATHS_OK=true
while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    path=$(echo "$line" | awk -F' :: ' '{print $1}')
    [[ -z "$path" ]] && continue
    if [[ -f "$PROJECT_ROOT/$path" ]]; then
        : # ok
    elif [[ "$path" == "install_phase1.sh" || "$path" == "install_phase2.sh" ]]; then
        : # generated - skip
    else
        fail "Manifest path does not exist: $path"
        PATHS_OK=false
    fi
done < "$MANIFEST"
[[ "$PATHS_OK" == "true" ]] && pass "All manifest paths exist (or are generated)"

# help.sh output contains TWO-PHASE
OUTPUT=$(./help.sh 2>/dev/null || true)
if echo "$OUTPUT" | grep -q "TWO-PHASE"; then
    pass "help.sh output contains TWO-PHASE"
else
    fail "help.sh output missing TWO-PHASE"
fi

# help.sh output contains run_1.sh
if echo "$OUTPUT" | grep -q "run_1.sh"; then
    pass "help.sh output contains run_1.sh"
else
    fail "help.sh output missing run_1.sh"
fi

# help.sh output contains doctor
if echo "$OUTPUT" | grep -q "doctor"; then
    pass "help.sh output contains doctor"
else
    fail "help.sh output missing doctor"
fi

# help.sh output contains post-install section
if echo "$OUTPUT" | grep -qi "post-install\|keep your node healthy"; then
    pass "help.sh output contains post-install section"
else
    fail "help.sh output missing post-install section"
fi

# Markdown has ## Two-Phase
MD_OUTPUT=$(./help.sh --markdown 2>/dev/null || true)
if echo "$MD_OUTPUT" | grep -q "## Two-Phase"; then
    pass "Markdown has ## Two-Phase header"
else
    fail "Markdown missing ## Two-Phase header"
fi

# Markdown has post-install section
if echo "$MD_OUTPUT" | grep -qi "post-install\|keep your node healthy"; then
    pass "Markdown has post-install section"
else
    fail "Markdown missing post-install section"
fi

# No duplicate paths in manifest
DUPES=$(grep -v '^#' "$MANIFEST" | grep ' :: ' | awk -F' :: ' '{print $1}' | sort | uniq -d)
if [[ -z "$DUPES" ]]; then
    pass "No duplicate paths in manifest"
else
    fail "Duplicate paths in manifest: $DUPES"
fi

if [[ $FAILED -eq 1 ]]; then
    echo ""
    echo -e "${RED}Help validation failed.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}All help validation tests passed.${NC}"
