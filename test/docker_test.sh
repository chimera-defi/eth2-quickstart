#!/bin/bash

# Docker-Based Test Runner
# Provides fully isolated test environment

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

show_help() {
    cat << EOF
Docker-Based Test Runner for Ethereum Node Setup Scripts

Usage: $0 [command] [options]

Commands:
  lint          Run shellcheck and static analysis only (fastest)
  unit          Run lint + unit tests with mocks
  integration   Run lint + unit + integration tests
  full          Run all tests in isolated container (slowest, most thorough)
  debug         Start interactive shell in test container
  clean         Remove test containers and images

Options:
  --rebuild     Force rebuild of Docker image
  --no-cache    Build Docker image without cache

Examples:
  $0 lint           # Quick lint check
  $0 unit           # Run unit tests
  $0 full           # Full test suite
  $0 debug          # Interactive debugging

EOF
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found. Installing or using local tests...${NC}"
        echo "Run ./quick_test.sh for local testing without Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${YELLOW}Docker daemon not running. Please start Docker.${NC}"
        exit 1
    fi
}

build_image() {
    local build_args=""
    
    if [[ "${NO_CACHE:-false}" == "true" ]]; then
        build_args="--no-cache"
    fi
    
    echo -e "${BLUE}Building test Docker image...${NC}"
    docker build $build_args -t eth-node-test -f "$SCRIPT_DIR/Dockerfile.test" "$SCRIPT_DIR/.."
}

run_test() {
    local test_type="$1"
    
    echo -e "${BLUE}Running $test_type tests in Docker...${NC}"
    
    case "$test_type" in
        lint)
            docker run --rm \
                -v "$SCRIPT_DIR/..:/workspace:ro" \
                -e TEST_MODE=lint \
                -e USE_MOCKS=true \
                eth-node-test \
                /workspace/test/run_tests.sh --lint-only
            ;;
        unit)
            docker run --rm \
                -v "$SCRIPT_DIR/..:/workspace:ro" \
                -e TEST_MODE=unit \
                -e USE_MOCKS=true \
                eth-node-test \
                /workspace/test/run_tests.sh --unit
            ;;
        integration)
            docker run --rm \
                -v "$SCRIPT_DIR/..:/workspace" \
                -e TEST_MODE=integration \
                -e USE_MOCKS=true \
                eth-node-test \
                /workspace/test/run_tests.sh --integration
            ;;
        full)
            docker run --rm \
                --privileged \
                -e TEST_MODE=full \
                -e USE_MOCKS=false \
                eth-node-test \
                /workspace/test/run_tests.sh --full
            ;;
        debug)
            docker run -it --rm \
                -v "$SCRIPT_DIR/..:/workspace" \
                -e TEST_MODE=debug \
                -e USE_MOCKS=true \
                eth-node-test \
                /bin/bash
            ;;
        *)
            echo "Unknown test type: $test_type"
            show_help
            exit 1
            ;;
    esac
}

clean_docker() {
    echo -e "${BLUE}Cleaning up Docker resources...${NC}"
    docker rmi eth-node-test 2>/dev/null || true
    docker volume rm test-results 2>/dev/null || true
    echo -e "${GREEN}Cleanup complete${NC}"
}

# Main
main() {
    local command="${1:-help}"
    shift || true
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --rebuild)
                REBUILD=true
                ;;
            --no-cache)
                NO_CACHE=true
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done
    
    case "$command" in
        help|--help|-h)
            show_help
            exit 0
            ;;
        clean)
            clean_docker
            exit 0
            ;;
        lint|unit|integration|full|debug)
            check_docker
            
            # Build image if needed
            if [[ "${REBUILD:-false}" == "true" ]] || ! docker image inspect eth-node-test &>/dev/null; then
                build_image
            fi
            
            run_test "$command"
            ;;
        *)
            echo "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
