#!/usr/bin/env bash
# run_once_10-ohmyzsh.sh
# Installs Oh My Zsh if not already present.
# Uses run_once_ so it only ever runs once per machine.

set -euo pipefail

if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "==> [ohmyzsh] Already installed, skipping."
  exit 0
fi

echo "==> [ohmyzsh] Installing Oh My Zsh..."

# Ensure zsh is available
if ! command -v zsh &>/dev/null; then
  echo "ERROR: zsh not found. Install it via brew or pacman first." >&2
  exit 1
fi

# Non-interactive install — keep existing .zshrc
RUNZSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Set zsh as default shell if not already
if [[ "$SHELL" != *zsh* ]]; then
  echo "==> [ohmyzsh] Setting zsh as default shell..."
  ZSH_PATH="$(command -v zsh)"
  if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi
  chsh -s "$ZSH_PATH" || sudo chsh -s "$ZSH_PATH" "$USER"
fi

echo "==> [ohmyzsh] Done."
