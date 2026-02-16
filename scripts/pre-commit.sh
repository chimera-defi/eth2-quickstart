#!/bin/bash
# Pre-commit checks matching CI. Run before pushing.
# Usage: ./scripts/pre-commit.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
echo "Running shellcheck + syntax..."
./test/run_tests.sh --lint-only
echo "Running common functions unit tests..."
bash install/test/test_common_functions.sh
echo "Pre-commit checks passed."
