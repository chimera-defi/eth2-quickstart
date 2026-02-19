#!/bin/bash

# Centralized Dependency Installation Script
# Single source of truth for all apt packages
#
# Usage:
#   ./install_dependencies.sh --production-root  # Run from run_1 (root, no sudo)
#   ./install_dependencies.sh --verify           # Run from run_2 (check only, no install)
#   ./install_dependencies.sh --production       # Legacy: full production (non-root, uses sudo)
#   ./install_dependencies.sh --test             # Test env (shellcheck, systemd, aide, cron, fail2ban)
#   ./install_dependencies.sh --base            # Base packages only

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

PRODUCTION_PACKAGES=(
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
    libtinfo6  # Terminal info (ncurses) - LLVM/clang, Rust, build tools. libtinfo5 removed in Ubuntu 24.04.
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

install_production() {
    log_info "Installing production packages..."
    
    # Check we're not root (production should run as regular user)
    if [[ $EUID -eq 0 ]] && ! is_docker; then
        log_error "Production install should not run as root. Use a regular user with sudo."
        exit 1
    fi
    
    if [[ $EUID -eq 0 ]]; then
        DEBIAN_FRONTEND=noninteractive apt-get update -y
    else
        sudo env DEBIAN_FRONTEND=noninteractive apt-get update -y
    fi
    
    # Install all packages
    install_base
    install_packages "${PRODUCTION_PACKAGES[@]}"
    
    # Add Ethereum PPA and install ethereum package
    if command -v add_ppa_repository &>/dev/null; then
        add_ppa_repository "ppa:ethereum/ethereum"
        install_packages "ethereum"
    fi
    
    # Install Node.js LTS (for Lodestar). In Docker, only when CI_E2E (full client testing)
    if ! is_docker || [[ "${CI_E2E:-}" == "true" ]]; then
        log_info "Installing Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        install_packages "nodejs"
    fi

    # Snap installs: Go and certbot (skip in Docker - snap doesn't work)
    if ! is_docker && command -v snap &>/dev/null; then
        log_info "Installing Go via snap..."
        sudo snap install --classic go
        sudo ln -sf /snap/bin/go /usr/bin/go
        log_info "Installing certbot via snap..."
        sudo snap install core
        sudo snap install --classic certbot
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    else
        log_warn "Skipping snap installs (Docker or snap unavailable)"
    fi

    # Install Rust (for ETHGas build). In Docker, only when CI_E2E (full client testing)
    if ! is_docker || [[ "${CI_E2E:-}" == "true" ]]; then
        log_info "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:${PATH:-}"
    fi

    # Install Bazel (may not be available in all repos)
    if apt-cache show bazel &>/dev/null; then
        log_info "Installing Bazel..."
        install_packages "bazel"
    fi
    
    # Configure time synchronization (skip in Docker)
    if ! is_docker && command -v timedatectl &>/dev/null; then
        log_info "Configuring time synchronization..."
        TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP (chrony uses pool.ntp.org by default)"
    fi
    
    log_info "All production dependencies installed successfully!"
}

# Install production dependencies as root (no sudo). Used by run_1.sh.
# Requires: root, LOGIN_UNAME for Rust install.
install_production_root() {
    log_info "Installing production packages (root mode)..."

    if [[ $EUID -ne 0 ]]; then
        log_error "install_production_root must run as root. Use from run_1.sh."
        exit 1
    fi

    DEBIAN_FRONTEND=noninteractive apt-get update -y

    install_base
    install_packages "${PRODUCTION_PACKAGES[@]}"

    # Add Ethereum PPA and install ethereum package (geth). Skip if geth already present.
    if ! command -v geth &>/dev/null; then
        if command -v add_ppa_repository &>/dev/null; then
            add_ppa_repository "ppa:ethereum/ethereum"
            install_packages "ethereum"
        fi
    else
        log_info "geth already installed, skipping"
    fi

    # Node.js LTS (for Lodestar). Skip if already installed.
    if ! command -v node &>/dev/null; then
        log_info "Installing Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        install_packages "nodejs"
    else
        log_info "Node.js already installed ($(node --version 2>/dev/null || echo 'unknown')), skipping"
    fi

    # Go: snap in production, apt fallback in Docker/CI (snap doesn't work in containers). Skip if present.
    if ! command -v go &>/dev/null; then
        if ! is_docker && [[ "${CI_E2E:-}" != "true" ]] && command -v snap &>/dev/null; then
            log_info "Installing Go via snap..."
            snap install --classic go
            ln -sf /snap/bin/go /usr/bin/go
            log_info "Installing certbot via snap..."
            snap install core
            snap install --classic certbot
            ln -sf /snap/bin/certbot /usr/bin/certbot
        else
            log_warn "Skipping snap (Docker or unavailable). Installing Go from apt..."
            install_packages "golang-go"
        fi
    else
        log_info "Go already installed ($(go version 2>/dev/null | grep -oE 'go[0-9.]+' || echo 'unknown')), skipping"
    fi

    # Rust for LOGIN_UNAME (ethrex, ethgas). Installs to ~/.cargo. Skip if cargo present.
    local rust_user="${LOGIN_UNAME:-eth}"
    local rust_cargo="/home/$rust_user/.cargo/bin/cargo"
    if id -u "$rust_user" &>/dev/null; then
        if [[ -x "${rust_cargo}" ]]; then
            log_info "Rust already installed for $rust_user, skipping"
        else
            log_info "Installing Rust for user $rust_user..."
            sudo -u "$rust_user" bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
            # Ensure cargo in PATH for future logins
            local bashrc="/home/$rust_user/.bashrc"
            if [[ -f "$bashrc" ]] && ! grep -qF '.cargo/bin' "$bashrc" 2>/dev/null; then
                # shellcheck disable=SC2016
                echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$bashrc"
            fi
        fi
    else
        log_warn "User $rust_user not found, skipping Rust install (needed for ethrex/ethgas)"
    fi

    # Bazel (optional, for fb_mev_prysm). Skip if already installed.
    if command -v bazel &>/dev/null; then
        log_info "Bazel already installed, skipping"
    elif apt-cache show bazel &>/dev/null; then
        log_info "Installing Bazel..."
        install_packages "bazel"
    fi

    # Time sync (skip in Docker)
    if ! is_docker && command -v timedatectl &>/dev/null; then
        log_info "Configuring time synchronization..."
        TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP (chrony uses pool.ntp.org by default)"
    fi

    log_info "All production dependencies installed successfully!"
}

# Verify required dependencies exist. No install. Used by run_2.sh.
# Fails with clear message if any required tool is missing.
verify_dependencies() {
    log_info "Verifying dependencies..."

    local missing=()

    # Base commands
    for cmd in curl wget git jq openssl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    # Production tools
    for cmd in node nginx; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    # Go (golang-go or snap)
    if ! command -v go &>/dev/null; then
        missing+=("go")
    fi

    # Geth (ethereum package)
    if ! command -v geth &>/dev/null; then
        missing+=("geth")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_error "Run Phase 1 (run_1.sh) first to install dependencies."
        exit 1
    fi

    # Optional: cargo for ethrex/ethgas (warn only)
    if ! command -v cargo &>/dev/null && [[ ! -x "${HOME}/.cargo/bin/cargo" ]]; then
        log_warn "cargo not found (optional for ethrex/ethgas)"
    fi

    log_info "All required dependencies verified."
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local mode="${1:-production}"
    
    case "$mode" in
        --test|-t)
            install_test
            ;;
        --base|-b)
            install_base
            ;;
        --production-root)
            install_production_root
            ;;
        --verify|-v)
            verify_dependencies
            ;;
        --production|-p|production|"")
            install_production
            ;;
        --help|-h)
            echo "Usage: $0 [--production-root|--verify|--test|--base|--production]"
            echo ""
            echo "Modes:"
            echo "  --production-root  Install as root (run_1.sh). No sudo."
            echo "  --verify, -v        Verify dependencies exist (run_2.sh). No install."
            echo "  --test, -t         Install test dependencies"
            echo "  --base, -b         Install base packages only"
            echo "  --production, -p   Install full production (legacy, non-root with sudo)"
            ;;
        *)
            log_error "Unknown mode: $mode"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
}

main "$@"
