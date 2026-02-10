# Homebrew/Ubuntu container for simulating macOS environment
# Tests Homebrew package installation with --system=macos override

FROM homebrew/brew:latest

# The homebrew image already has:
# - Homebrew installed at /home/linuxbrew/.linuxbrew
# - User 'linuxbrew' with sudo access

USER linuxbrew

# Ensure Homebrew is in PATH
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_AUTO_UPDATE=1
ENV HOMEBREW_NO_INSTALL_CLEANUP=1

# Install additional prerequisites
# yq is needed for dry-run mode to parse YAML (package listing)
RUN brew install git curl yq

# Set up home directory
ENV HOME=/home/linuxbrew
WORKDIR /home/linuxbrew

# The dotfiles repo will be mounted at /workspace
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
