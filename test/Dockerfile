FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies needed for testing
RUN apt-get update && apt-get install -y \
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
