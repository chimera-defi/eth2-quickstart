#!/bin/bash

# Centralized Dependency Installation Script
# Single source of truth for all apt packages
#
# Two-phase architecture (security model):
#   Phase 1 (root, run_1.sh):  System packages, snap, time sync -- no sudo needed
#   Phase 2 (eth user, run_2.sh): User-level tools only (Rust) -- no sudo apt-get
#
# Usage:
#   ./install_dependencies.sh --phase1     # Root: system packages, snap, time sync
#   ./install_dependencies.sh --phase2     # Non-root: user-level tools (Rust)
#   ./install_dependencies.sh --test       # Test env (shellcheck, systemd, aide, cron, fail2ban)
#   ./install_dependencies.sh --base       # Base packages only
#   ./install_dependencies.sh --production # Legacy alias (same as --phase1, for Docker/CI)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=../../lib/common_functions.sh
source "$SCRIPT_DIR/../../lib/common_functions.sh"

# =============================================================================
# PACKAGE DEFINITIONS
# =============================================================================

BASE_PACKAGES=(
    bash
    curl
    wget
    git
    tar
    gzip
    sudo
    jq
    openssl
    ca-certificates
    gnupg
    lsb-release
    software-properties-common
    apt-transport-https
)

TEST_PACKAGES=(
    shellcheck
    ufw
    systemd
    systemd-sysv
    openssh-server
    aide
    cron
    fail2ban
)

# System-level packages installed as root in Phase 1.
# Client-specific deps (Ethereum PPA, Node.js, Bazel) are installed
# by individual client scripts so we only pull what's actually needed.
PHASE1_PACKAGES=(
    unzip
    build-essential
    python3
    python3-pip
    chrony
    ufw
    aide
    cron
    fail2ban
    snapd
    cmake
    libssl-dev
    libgmp-dev
    libtinfo6
    libprotobuf-dev
    pkg-config
    openjdk-17-jdk
    libclang-dev
    nginx
    apache2-utils
    bmon
    tcptrack
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

install_packages() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    log_info "Installing packages: ${packages[*]}"

    if [[ $EUID -eq 0 ]]; then
        DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 apt-get install -y --no-install-recommends "${packages[@]}"
    else
        sudo env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical NEEDRESTART_MODE=a NEEDRESTART_SUSPEND=1 apt-get install -y --no-install-recommends "${packages[@]}"
    fi
}

apt_update() {
    if [[ $EUID -eq 0 ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y
    else
        sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
    fi
}

# =============================================================================
# INSTALLATION MODES
# =============================================================================

install_base() {
    log_info "Installing base packages..."
    install_packages "${BASE_PACKAGES[@]}"
}

install_test() {
    log_info "Installing test environment packages..."
    install_base
    install_packages "${TEST_PACKAGES[@]}"
    log_info "Test dependencies installed successfully!"
}

# Phase 1: System-level packages (runs as root from run_1.sh)
# Installs all apt packages, snap tools (Go, certbot), and configures time sync.
# Client-specific repos (Ethereum PPA, Node.js, Bazel) are deferred to client scripts.
install_phase1() {
    log_info "Installing Phase 1 system packages (root)..."

    if [[ $EUID -ne 0 ]] && ! is_docker; then
        log_error "Phase 1 must run as root (called from run_1.sh)"
        exit 1
    fi

    apt_update

    install_base
    install_packages "${PHASE1_PACKAGES[@]}"

    # Snap installs: Go and certbot (skip in Docker -- snap doesn't work in containers)
    if ! is_docker && command -v snap &>/dev/null; then
        log_info "Installing Go via snap..."
        snap install --classic go
        ln -sf /snap/bin/go /usr/bin/go
        log_info "Installing certbot via snap..."
        snap install core
        snap install --classic certbot
        ln -sf /snap/bin/certbot /usr/bin/certbot
    else
        log_warn "Skipping snap installs (Docker or snap unavailable)"
    fi

    # Configure time synchronization (skip in Docker -- no timedatectl)
    if ! is_docker && command -v timedatectl &>/dev/null; then
        log_info "Configuring time synchronization..."
        TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP (chrony uses pool.ntp.org by default)"
    fi

    log_info "Phase 1 system dependencies installed successfully!"
}

# Phase 2: User-level tools only (runs as eth user from run_2.sh)
# Installs Rust (per-user, in $HOME/.cargo). No sudo apt-get calls.
install_phase2() {
    log_info "Installing Phase 2 user-level tools..."

    if [[ $EUID -eq 0 ]] && ! is_docker; then
        log_error "Phase 2 should run as non-root user (called from run_2.sh)"
        exit 1
    fi

    # Rust (user-level install in $HOME/.cargo -- needed for ETHGas build)
    if command -v cargo &>/dev/null; then
        log_info "Rust already installed: $(rustc --version 2>/dev/null || echo 'unknown')"
    elif ! is_docker || [[ "${CI_E2E:-}" == "true" ]]; then
        log_info "Installing Rust (user-level, $HOME/.cargo)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
        [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:${PATH:-}"
    fi

    log_info "Phase 2 user-level tools installed successfully!"
}

# Legacy --production mode: installs everything (Phase 1 + Phase 2).
# Used in Docker/CI where a single root user runs the full stack.
install_production() {
    log_info "Installing all production dependencies (Docker/CI combined mode)..."

    apt_update

    install_base
    install_packages "${PHASE1_PACKAGES[@]}"

    # Snap installs (skip in Docker)
    if ! is_docker && command -v snap &>/dev/null; then
        log_info "Installing Go via snap..."
        if [[ $EUID -eq 0 ]]; then
            snap install --classic go
            ln -sf /snap/bin/go /usr/bin/go
            snap install core
            snap install --classic certbot
            ln -sf /snap/bin/certbot /usr/bin/certbot
        else
            sudo snap install --classic go
            sudo ln -sf /snap/bin/go /usr/bin/go
            sudo snap install core
            sudo snap install --classic certbot
            sudo ln -sf /snap/bin/certbot /usr/bin/certbot
        fi
    else
        log_warn "Skipping snap installs (Docker or snap unavailable)"
    fi

    # Rust (user-level)
    if ! is_docker || [[ "${CI_E2E:-}" == "true" ]]; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
        [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:${PATH:-}"
    fi

    # Time sync (skip in Docker)
    if ! is_docker && command -v timedatectl &>/dev/null; then
        log_info "Configuring time synchronization..."
        if [[ $EUID -eq 0 ]]; then
            TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP"
        else
            sudo TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP"
        fi
    fi

    log_info "All production dependencies installed successfully!"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local mode="${1:-production}"

    case "$mode" in
        --phase1)
            install_phase1
            ;;
        --phase2)
            install_phase2
            ;;
        --test|-t)
            install_test
            ;;
        --base|-b)
            install_base
            ;;
        --production|-p|production|"")
            install_production
            ;;
        --help|-h)
            echo "Usage: $0 [--phase1|--phase2|--test|--base|--production]"
            echo ""
            echo "Modes:"
            echo "  --phase1         Phase 1 (root): system packages, snap, time sync"
            echo "  --phase2         Phase 2 (non-root): user-level tools (Rust)"
            echo "  --test, -t       Install test dependencies"
            echo "  --base, -b       Install base packages only"
            echo "  --production, -p All dependencies (Docker/CI combined mode)"
            ;;
        *)
            log_error "Unknown mode: $mode"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

main "$@"
