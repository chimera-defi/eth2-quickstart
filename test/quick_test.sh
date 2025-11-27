#!/bin/bash

# Quick Local Test Script
# Runs basic tests WITHOUT Docker - safe for local development
# Uses mocks to prevent any system modifications

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Enable mocks for safety
export USE_MOCKS=true
export TEST_MODE=quick

echo "========================================"
echo "Quick Local Test (Safe Mode)"
echo "========================================"
echo "Project root: $PROJECT_ROOT"
echo "Using mocks: $USE_MOCKS"
echo ""

# Run the test suite with lint and unit tests only
# (no integration tests that might try to execute scripts)
bash "$SCRIPT_DIR/run_tests.sh" --unit

echo ""
echo "Quick test complete!"
echo "For full Docker-based testing, run: ./docker_test.sh"
