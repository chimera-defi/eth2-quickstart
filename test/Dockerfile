# Test Environment Dockerfile
# 
# Uses the centralized install_dependencies.sh script with --test mode
# This ensures test and production dependencies stay in sync

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Pre-seed debconf to prevent apt from hanging on interactive config
# (postfix, cron, tzdata, needrestart often prompt during install/upgrade)
RUN echo "postfix postfix/mailname string localhost" | debconf-set-selections 2>/dev/null || true && \
    echo "postfix postfix/main_mailer_type string 'Local only'" | debconf-set-selections 2>/dev/null || true && \
    echo "cron cron/upgrade_available boolean false" | debconf-set-selections 2>/dev/null || true && \
    echo "cron cron/upgrade_available_seen boolean true" | debconf-set-selections 2>/dev/null || true && \
    echo "tzdata tzdata/Areas select Etc" | debconf-set-selections 2>/dev/null || true && \
    echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections 2>/dev/null || true && \
    echo "needrestart needrestart/restart-services string" | debconf-set-selections 2>/dev/null || true && \
    echo 'DPkg::options { "--force-confdef"; "--force-confold"; };' > /etc/apt/apt.conf.d/99local-noninteractive
# Note: debconf-set-selections may fail if package not installed yet; || true ensures build continues

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

# Enable SSH for run_1 E2E (configure_ssh needs sshd running under systemd)
RUN systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true

# Create a non-root user for testing (mimics real deployment)
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set ownership
RUN chown -R testuser:testuser /workspace

# Default to running as testuser (non-root, like real usage)
USER testuser

# Default command runs the test suite
CMD ["/workspace/test/docker_test.sh"]
