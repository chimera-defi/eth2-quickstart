# Test Environment Dockerfile
# 
# Uses the centralized install_dependencies.sh script with --test mode
# This ensures test and production dependencies stay in sync

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up working directory first (needed for sourcing scripts)
WORKDIR /workspace

# Copy the project (needed for install_dependencies.sh)
COPY . /workspace/

# Make scripts executable
RUN find /workspace -name "*.sh" -exec chmod +x {} \;

# Install test dependencies using the centralized script
# This runs as root in Docker, which the script now handles
RUN apt-get update && \
    /workspace/install/utils/install_dependencies.sh --test && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for testing (mimics real deployment)
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set ownership
RUN chown -R testuser:testuser /workspace

# Default to running as testuser (non-root, like real usage)
USER testuser

# Default command runs the test suite
CMD ["/workspace/test/docker_test.sh"]
