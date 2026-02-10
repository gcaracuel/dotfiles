# Fedora container for testing dotfiles bootstrap
# Tests native Linux (DNF) package installation

FROM fedora:latest

# Install basic prerequisites that would normally exist on a real system
# Also install yq so dry-run mode can parse YAML (needed for package listing)
RUN dnf install -y \
    git \
    curl \
    sudo \
    which \
    procps-ng \
    yq \
    && dnf clean all

# Create a non-root user for testing
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to test user
USER testuser
WORKDIR /home/testuser

# Set up a clean home directory
ENV HOME=/home/testuser

# The dotfiles repo will be mounted at /workspace
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
