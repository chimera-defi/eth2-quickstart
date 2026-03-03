# Test Environment Dockerfile
#
# Uses Ubuntu 24.04 - production target. E2E runs install_dependencies --phase1
# (as root) + --phase2 (as testuser) at runtime, validating the two-phase model.

FROM ubuntu:24.04

# Prevent interactive prompts during package installation (batteries-included)
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_PRIORITY=critical

# Set up working directory and copy project first (needed for debconf_preseed.sh)
WORKDIR /workspace
COPY . /workspace/

# Pre-seed debconf (single source: install/utils/debconf_preseed.sh)
RUN bash /workspace/install/utils/debconf_preseed.sh

# Make scripts executable
RUN find /workspace -name "*.sh" -exec chmod +x {} \;

# Install full phase1 dependencies in-image so phase1 marker truthfully represents
# runtime readiness for matrix lanes (including Java-based clients).
RUN apt-get update && \
    CI_E2E=true bash /workspace/install/utils/install_dependencies.sh --phase1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    touch /etc/ethqs-phase1-deps-ready

# Install Caddy for config validation (validate_caddy_config.sh)
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg && \
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list && \
    apt-get update && apt-get install -y caddy && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable SSH for run_1 E2E (configure_ssh needs sshd running under systemd)
RUN systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true

# Create root SSH keys for run_1 E2E (collect_and_backup_authorized_keys requires keys or exits)
RUN mkdir -p /root/.ssh && echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test-key-for-e2e" > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys

# Create a non-root user for testing (mimics real deployment)
# Preserve DEBIAN_* through sudo so apt/dpkg stay noninteractive (prevents tzdata Readline hang)
RUN useradd -m -s /bin/bash testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && echo 'Defaults env_keep += "DEBIAN_FRONTEND DEBIAN_PRIORITY TZ"' > /etc/sudoers.d/99-noninteractive \
    && chmod 440 /etc/sudoers.d/99-noninteractive

# Set ownership
RUN chown -R testuser:testuser /workspace

# Pre-install phase2 user tools once per image so matrix lanes avoid repeated setup cost.
# CI_E2E=true is required because phase2 intentionally skips Rust installs in generic Docker.
RUN su - testuser -c "cd /workspace && CI_E2E=true ./install/utils/install_dependencies.sh --phase2"

# Marker consumed by ci_test_e2e.sh to avoid redundant dependency re-install in each lane
RUN touch /etc/ethqs-phase2-deps-ready

# Default to running as testuser (non-root, like real usage)
USER testuser

# Default command runs the test suite
CMD ["/workspace/test/docker_test.sh"]
