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
    unzip
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
    build-essential
    python3
    python3-pip
    chrony
    ufw
    aide
    cron
    fail2ban
    openssh-server
    snapd
    cmake
    libssl-dev
    libgmp-dev
    libtinfo6
    libprotobuf-dev
    pkg-config
    openjdk-25-jdk
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
# SHARED PHASE1 / PRODUCTION STEPS
# =============================================================================
# install_phase1() and install_production() both install the same root-level
# apt/snap/time-sync stack (production is the legacy Docker/CI combined mode
# that runs Phase 1 + Phase 2 together). These helpers are the single copy of
# that logic; both callers keep their own EUID guards/conditionals untouched.

# apt_update + base packages + Phase 1 system packages.
install_phase1_apt_stack() {
    apt_update
    install_base
    install_packages "${PHASE1_PACKAGES[@]}"
}

# Go + certbot via snap (skipped in Docker/CI or when snap is unavailable).
# EUID-branched so it's safe to call from a caller that may run as root or
# non-root; install_phase1() always runs as root, so it always takes the
# unprefixed branch below (identical to its pre-refactor behavior).
install_snap_tools() {
    if [[ "${CI_E2E:-}" != "true" ]] && ! is_docker && command -v snap &>/dev/null; then
        log_info "Installing Go via snap..."
        if [[ $EUID -eq 0 ]]; then
            snap install --classic go
            ln -sf /snap/bin/go /usr/bin/go
            log_info "Installing certbot via snap..."
            snap install core
            snap install --classic certbot
            ln -sf /snap/bin/certbot /usr/bin/certbot
        else
            sudo snap install --classic go
            sudo ln -sf /snap/bin/go /usr/bin/go
            log_info "Installing certbot via snap..."
            sudo snap install core
            sudo snap install --classic certbot
            sudo ln -sf /snap/bin/certbot /usr/bin/certbot
        fi
    else
        log_warn "Skipping snap installs (Docker or snap unavailable)"
    fi
}

# NTP time sync via timedatectl (skipped in Docker -- no timedatectl there).
# Same EUID-branch rationale as install_snap_tools() above.
configure_time_sync() {
    if ! is_docker && command -v timedatectl &>/dev/null; then
        log_info "Configuring time synchronization..."
        if [[ $EUID -eq 0 ]]; then
            TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP (chrony uses pool.ntp.org by default)"
        else
            sudo TZ=UTC timedatectl set-ntp true 2>/dev/null || log_warn "Could not enable NTP (chrony uses pool.ntp.org by default)"
        fi
    fi
}

# Rustup install command itself (the literal, byte-identical command both
# install_phase2() and install_production() run). Callers keep their own
# surrounding guard conditionals unchanged -- phase2's "skip if cargo already
# installed" check is intentionally NOT folded in here, since production's
# caller never had that check and folding it in would change production's
# existing behavior.
install_rust_toolchain() {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
    [[ -d "$HOME/.cargo/bin" ]] && export PATH="$HOME/.cargo/bin:${PATH:-}"
}

# =============================================================================
# VALIDATOR TOOL INSTALLATION
# =============================================================================

# Install ethdo (validator management tool)
# Graceful: if installation fails, script continues and prints manual instructions
install_ethdo() {
    log_info "Installing ethdo (validator management tool)..."

    # Check if Go is available
    if ! command -v go &>/dev/null; then
        log_warn "Go not found. Skipping ethdo installation."
        log_info "Manual install: go install github.com/wealdtech/ethdo@latest"
        return 0
    fi

    # Check if already installed
    if command -v ethdo &>/dev/null; then
        log_info "ethdo already installed: $(ethdo --version 2>/dev/null || echo 'unknown')"
        return 0
    fi

    # Install ethdo
    if go install github.com/wealdtech/ethdo@latest &>/dev/null; then
        # Ensure GOPATH/bin is in PATH
        local go_bin
        go_bin="$(go env GOPATH)/bin"
        if [[ -d "$go_bin" ]] && [[ ":$PATH:" != *":$go_bin:"* ]]; then
            export PATH="$go_bin:$PATH"
            echo "export PATH=\"$go_bin:\$PATH\"" >> "$HOME/.bashrc" 2>/dev/null || true
        fi
        log_info "ethdo installed successfully"
    else
        log_warn "Failed to install ethdo via Go"
        log_info "Manual install: go install github.com/wealdtech/ethdo@latest"
    fi
}

# Install ethstaker-deposit-cli (validator key generation tool)
# Graceful: if installation fails, script continues and prints manual instructions
install_ethstaker_deposit_cli() {
    log_info "Installing ethstaker-deposit-cli (validator key generation tool)..."

    local deposit_cli_name="ethstaker-deposit-cli"
    local venv_dir="$HOME/.${deposit_cli_name}-venv"
    local repo_url="https://github.com/ethstaker/ethstaker-deposit-cli.git"

    # Check if already installed
    if [[ -d "$venv_dir" && -x "$venv_dir/bin/python" ]]; then
        log_info "$deposit_cli_name already installed at $venv_dir"
        return 0
    fi

    # Check Python requirements
    if ! command -v python3 &>/dev/null; then
        log_warn "python3 not found. Skipping $deposit_cli_name installation."
        log_info "Manual install: git clone $repo_url && python3 -m venv venv && ./venv/bin/pip install -e ."
        return 0
    fi

    if ! python3 -c "import venv" &>/dev/null; then
        log_warn "python3-venv not found. Skipping $deposit_cli_name installation."
        log_info "Manual install: sudo apt-get install python3-venv"
        log_info "Then: git clone $repo_url && python3 -m venv venv && ./venv/bin/pip install -e ."
        return 0
    fi

    # Create temporary directory for clone
    local tmp_dir
    tmp_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp_dir'" EXIT

    log_info "Cloning $deposit_cli_name repository..."
    if ! git clone --depth 1 "$repo_url" "$tmp_dir/repo" 2>/dev/null; then
        log_warn "Failed to clone $deposit_cli_name repository"
        log_info "Manual install: git clone $repo_url && python3 -m venv venv && ./venv/bin/pip install -e ."
        return 0
    fi

    log_info "Creating virtual environment at $venv_dir..."
    if ! python3 -m venv "$venv_dir" 2>/dev/null; then
        log_warn "Failed to create virtual environment"
        log_info "Manual install: git clone $repo_url && python3 -m venv venv && ./venv/bin/pip install -e ."
        return 0
    fi

    log_info "Installing $deposit_cli_name..."
    # shellcheck disable=SC1090
    if ! source "$venv_dir/bin/activate" 2>/dev/null; then
        log_warn "Failed to activate virtual environment"
        return 0
    fi

    if ! pip install -e "$tmp_dir/repo" &>/dev/null; then
        log_warn "Failed to install $deposit_cli_name"
        deactivate 2>/dev/null || true
        log_info "Manual install: git clone $repo_url && python3 -m venv venv && ./venv/bin/pip install -e ."
        return 0
    fi
    deactivate 2>/dev/null || true

    # Secure the venv directory
    chmod 700 "$venv_dir"

    log_info "$deposit_cli_name installed successfully at $venv_dir"
}

# Install validator tools (ethdo + ethstaker-deposit-cli)
# Called from Phase 2 (user-level)
install_validator_tools() {
    log_info "Installing validator management tools..."

    install_ethdo
    install_ethstaker_deposit_cli

    log_info "Validator tools installation complete"
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

    install_phase1_apt_stack
    install_snap_tools
    configure_time_sync

    log_info "Phase 1 system dependencies installed successfully!"
}

# Phase 2: User-level tools only (runs as eth user from run_2.sh)
# Installs Rust (per-user, in $HOME/.cargo) and validator tools. No sudo apt-get calls.
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
        install_rust_toolchain
    fi

    # Validator tools (ethdo + ethstaker-deposit-cli)
    install_validator_tools

    log_info "Phase 2 user-level tools installed successfully!"
}

# Legacy --production mode: installs everything (Phase 1 + Phase 2).
# Used in Docker/CI where a single root user runs the full stack.
install_production() {
    log_info "Installing all production dependencies (Docker/CI combined mode)..."

    install_phase1_apt_stack
    install_snap_tools

    # Rust (user-level)
    if ! is_docker || [[ "${CI_E2E:-}" == "true" ]]; then
        log_info "Installing Rust..."
        install_rust_toolchain
    fi

    # Validator tools (ethdo + ethstaker-deposit-cli)
    install_validator_tools

    configure_time_sync

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
