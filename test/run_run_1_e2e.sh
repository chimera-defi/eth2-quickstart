#!/bin/bash
# Wrapper to run run_1.sh E2E test in Docker with systemd
# Usage: ./run_run_1_e2e.sh [from repo root or test/]
# Builds image, starts container with systemd init, execs E2E test, cleans up

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${E2E_IMAGE_NAME:-eth-node-test}"
CONTAINER_NAME="run1-e2e-$$"

cd "$PROJECT_ROOT"

echo "=== run_1.sh E2E Test ==="
if [[ "${SKIP_BUILD:-false}" != "true" ]]; then
    echo "Building image..."
    docker build -t "$IMAGE_NAME" -f test/Dockerfile .
else
    echo "Skipping build (SKIP_BUILD=true)"
fi

echo "Starting container with systemd (required for SSH, fail2ban)..."
# Use systemd as init - required for configure_ssh, fail2ban, etc.
# --user root: Dockerfile defaults to testuser, but init must run as root
docker run -d --privileged \
    --user root \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --name "$CONTAINER_NAME" \
    -e DEBIAN_FRONTEND=noninteractive \
    "$IMAGE_NAME" \
    /sbin/init

# Wait for systemd to be ready
echo "Waiting for systemd to initialize..."
sleep 5
for i in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" systemctl is-system-running --wait 2>/dev/null | grep -qE "running|degraded"; then
        break
    fi
    sleep 2
done

# Ensure we're running as root for the exec
echo "Running run_1.sh E2E test..."
exit_code=0
docker exec --user root "$CONTAINER_NAME" /workspace/test/ci_test_run_1_e2e.sh || exit_code=$?

echo "Stopping container..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

exit $exit_code
