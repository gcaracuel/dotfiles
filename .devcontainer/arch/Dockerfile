# Arch Linux only has x86_64 images. On Apple Silicon this runs via Rosetta.
FROM --platform=linux/amd64 archlinux:latest

# pacman uses a sandbox user (alpm) that calls seccomp, which fails under
# Rosetta emulation in Docker Desktop. Disabling the sandbox in pacman.conf
# is the correct fix for containerised/emulated builds.
RUN sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf && \
    grep -q '^DisableSandbox' /etc/pacman.conf || echo 'DisableSandbox' >> /etc/pacman.conf

# Update and install essentials
RUN pacman -Syu --noconfirm && \
    pacman -S --needed --noconfirm \
      base-devel \
      git \
      curl \
      sudo \
      zsh \
      chezmoi \
      just \
    && pacman -Scc --noconfirm

# Create a non-root user (mirrors a real user setup)
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER testuser
WORKDIR /home/testuser

ENV HOME=/home/testuser
