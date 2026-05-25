# Homebrew/Ubuntu container for simulating macOS Homebrew environment
FROM homebrew/brew:latest

USER linuxbrew

ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
ENV HOMEBREW_NO_INSTALL_CLEANUP=1
ENV HOME=/home/linuxbrew

# Update Homebrew and install chezmoi and just
RUN brew update && brew install git curl chezmoi just

WORKDIR /workspace

CMD ["/bin/bash"]
