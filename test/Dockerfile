# Test Environment Dockerfile
# 
# PURPOSE: Minimal Ubuntu environment for TESTING scripts (not production)
#
# NOTE: This installs DIFFERENT packages than install/utils/install_dependencies.sh
# - install_dependencies.sh: Full production packages (build tools, languages, etc.)
# - This Dockerfile: Minimal test packages (shellcheck, curl, git, ufw for tests)
#
# We intentionally keep these separate because:
# 1. Tests should run fast (minimal packages)
# 2. Tests shouldn't need full build toolchain
# 3. Some production dependencies (snap, systemd services) don't work in Docker

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install ONLY packages needed for testing (not production)
# - Core utilities: bash, curl, wget, git, tar, gzip
# - Test tools: shellcheck, jq
# - For testing install scripts: sudo, ufw, systemd (limited), ca-certificates
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    git \
    sudo \
    systemd \
    systemd-sysv \
    ufw \
    jq \
    tar \
    gzip \
    openssl \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    shellcheck \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for testing (mimics real deployment)
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up working directory
WORKDIR /workspace

# Copy the entire project
COPY . /workspace/

# Make scripts executable
RUN find /workspace -name "*.sh" -exec chmod +x {} \;

# Set ownership
RUN chown -R testuser:testuser /workspace

# Default to running as testuser (non-root, like real usage)
USER testuser

# Default command runs the test suite
CMD ["/workspace/test/docker_test.sh"]
