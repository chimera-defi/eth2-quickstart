#!/bin/bash
# Wrapper to run E2E tests in Docker with systemd
# Usage: ./run_e2e.sh [--phase=1|2]  or  ./run_e2e.sh -1|-2
#   Phase 1 = run_1.sh (system setup, root)
#   Phase 2 = run_2.sh (client installation, testuser)
# Builds image, starts container with systemd init, execs E2E test, cleans up
# Requires: Docker installed and running

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${E2E_IMAGE_NAME:-eth-node-test}"
CONTAINER_STARTED=false

# Parse --phase=N or -N
PHASE=""
for arg in "$@"; do
    case "$arg" in
        --phase=1|-1) PHASE=1 ;;
        --phase=2|-2) PHASE=2 ;;
    esac
done

if [[ -z "$PHASE" ]] || [[ "$PHASE" != "1" && "$PHASE" != "2" ]]; then
    echo "Usage: $0 --phase=1|2  (or -1|-2)"
    echo "  Phase 1 = run_1.sh (system setup)"
    echo "  Phase 2 = run_2.sh (client installation)"
    exit 1
fi

CONTAINER_NAME="e2e-phase${PHASE}-$$"

cleanup() {
    if [[ "$CONTAINER_STARTED" == "true" ]]; then
        echo "Cleaning up container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
    fi
}
trap cleanup EXIT

cd "$PROJECT_ROOT"

if ! command -v docker &>/dev/null; then
    echo "Error: Docker is required but not found. Install Docker and try again."
    exit 1
fi

echo "=== run_${PHASE}.sh - E2E ==="
if [[ "${SKIP_BUILD:-false}" != "true" ]]; then
    echo "Building image..."
    docker build -t "$IMAGE_NAME" -f test/Dockerfile .
else
    echo "Skipping build (SKIP_BUILD=true)"
fi

# Prevent tty hangs (tzdata, postfix, cron) - same as Phase 1
DOCKER_ENV=(-e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical)
[[ "$PHASE" == "2" ]] && DOCKER_ENV+=(-e CI_E2E=true)

echo "Starting container with systemd..."
if ! docker run -d --privileged \
    --user root \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --tmpfs /run --tmpfs /run/lock \
    --name "$CONTAINER_NAME" \
    "${DOCKER_ENV[@]}" \
    "$IMAGE_NAME" \
    /sbin/init; then
    echo "Error: Failed to start container"
    exit 1
fi
CONTAINER_STARTED=true

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: Container failed to start"
    docker logs "$CONTAINER_NAME" 2>/dev/null || true
    exit 1
fi

echo "Waiting for systemd to initialize..."
sleep 5
for _ in $(seq 1 30); do
    if docker exec "$CONTAINER_NAME" systemctl is-system-running --wait 2>/dev/null | grep -qE "running|degraded"; then
        break
    fi
    sleep 2
done

# Phase 1 = run_1 (root). Phase 2 = run_2 (testuser).
# Phase 2: E2E_EXECUTION, E2E_CONSENSUS, E2E_MEV select clients (for client matrix job)
# Pass CI/GITHUB_ACTIONS for expanded debug output (dump_log_tail 150 lines) on failure
if [[ "$PHASE" == "1" ]]; then
    DOCKER_EXEC_ENV=(-e PHASE=1 -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical)
    [[ -n "${CI:-}" ]] && DOCKER_EXEC_ENV+=(-e "CI=$CI")
    [[ -n "${GITHUB_ACTIONS:-}" ]] && DOCKER_EXEC_ENV+=(-e "GITHUB_ACTIONS=$GITHUB_ACTIONS")
    docker exec --user root "${DOCKER_EXEC_ENV[@]}" "$CONTAINER_NAME" /workspace/test/ci_test_e2e.sh || exit
else
    DOCKER_E2E=(-e PHASE=2 -e CI_E2E=true -e DEBIAN_FRONTEND=noninteractive -e DEBIAN_PRIORITY=critical)
    [[ -n "${E2E_EXECUTION:-}" ]] && DOCKER_E2E+=(-e "E2E_EXECUTION=$E2E_EXECUTION")
    [[ -n "${E2E_CONSENSUS:-}" ]] && DOCKER_E2E+=(-e "E2E_CONSENSUS=$E2E_CONSENSUS")
    [[ -n "${E2E_MEV:-}" ]] && DOCKER_E2E+=(-e "E2E_MEV=$E2E_MEV")
    [[ -n "${E2E_ETHGAS:-}" ]] && DOCKER_E2E+=(-e "E2E_ETHGAS=$E2E_ETHGAS")
    [[ -n "${GITHUB_TOKEN:-}" ]] && DOCKER_E2E+=(-e "GITHUB_TOKEN=$GITHUB_TOKEN")
    [[ -n "${CI:-}" ]] && DOCKER_E2E+=(-e "CI=$CI")
    [[ -n "${GITHUB_ACTIONS:-}" ]] && DOCKER_E2E+=(-e "GITHUB_ACTIONS=$GITHUB_ACTIONS")
    docker exec --user testuser "${DOCKER_E2E[@]}" "$CONTAINER_NAME" /workspace/test/ci_test_e2e.sh || exit
fi
