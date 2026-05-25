#!/usr/bin/env bash
# run_once_11-lazyvim.sh
# Installs the LazyVim starter configuration for Neovim.
# Uses run_once_ so it only ever runs once per machine.
# Your plugin customizations in ~/.config/nvim/lua/plugins/ are managed
# as chezmoi dotfiles and will overlay on top of the starter config.

set -euo pipefail

NVIM_CONFIG="$HOME/.config/nvim"
LAZYVIM_MARKER="$NVIM_CONFIG/lua/config/lazy.lua"

if [[ -f "$LAZYVIM_MARKER" ]] && grep -qi "lazyvim" "$LAZYVIM_MARKER" 2>/dev/null; then
  echo "==> [lazyvim] Already installed, skipping."
  exit 0
fi

if ! command -v nvim &>/dev/null; then
  echo "ERROR: neovim not found. Install it via brew or pacman first." >&2
  exit 1
fi

# Backup existing nvim config if present
if [[ -d "$NVIM_CONFIG" ]]; then
  BACKUP="${NVIM_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
  echo "==> [lazyvim] Backing up existing nvim config to $BACKUP"
  mv "$NVIM_CONFIG" "$BACKUP"
fi

echo "==> [lazyvim] Cloning LazyVim starter..."
# Disable SSH URL rewriting temporarily for HTTPS clone
git -c url."https://".insteadOf="git@" \
    -c url."https://github.com/".insteadOf="git@github.com:" \
    clone --depth 1 https://github.com/LazyVim/starter "$NVIM_CONFIG"

# Remove .git so it doesn't conflict with our dotfiles repo
rm -rf "$NVIM_CONFIG/.git"

echo "==> [lazyvim] Done. Chezmoi will apply your plugin customizations on top."
