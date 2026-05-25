# Dotfiles justfile — chezmoi workflow
# https://just.systems

import 'test.justfile'

REPO_DIR := justfile_directory()
CHEZMOI_SOURCE := REPO_DIR / "home"

# List available targets
default:
    @just --list

# =============================================================================
# Setup
# =============================================================================

# Initial setup: install Homebrew (macOS), chezmoi, and link this repo as the source directory
init:
    #!/usr/bin/env bash
    set -euo pipefail

    OS="$(uname -s)"

    # --- macOS: install Homebrew first if missing ---
    if [[ "$OS" == "Darwin" ]] && ! command -v brew &>/dev/null; then
      echo "==> Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Add brew to PATH for this session (Apple Silicon path takes precedence)
      if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi

    # --- Install chezmoi if missing ---
    if ! command -v chezmoi &>/dev/null; then
      echo "==> Installing chezmoi..."
      if command -v brew &>/dev/null; then
        brew install chezmoi
      elif command -v pacman &>/dev/null; then
        sudo pacman -S --needed --noconfirm chezmoi
      else
        sh -c "$(curl -fsLS get.chezmoi.io)"
      fi
    fi

    # Create symlink from chezmoi source to this repo's home/ dir
    LINK="${HOME}/.local/share/chezmoi"
    mkdir -p "$(dirname "$LINK")"
    if [[ -L "$LINK" ]]; then
      echo "==> Symlink already exists: $LINK -> $(readlink "$LINK")"
    elif [[ -d "$LINK" ]]; then
      echo "ERROR: $LINK exists as a real directory. Move or remove it first." >&2
      exit 1
    else
      ln -sf "{{REPO_DIR}}/home" "$LINK"
      echo "==> Created: $LINK -> {{REPO_DIR}}/home"
    fi

    # Initialize chezmoi config (prompts for work mode if not already configured)
    if [[ ! -f "${HOME}/.config/chezmoi/chezmoi.toml" ]]; then
      echo "==> Initializing chezmoi config (you'll be prompted for work mode)..."
      chezmoi init --source "{{CHEZMOI_SOURCE}}"
    else
      echo "==> chezmoi config already exists: ${HOME}/.config/chezmoi/chezmoi.toml"
    fi

    echo "==> Run 'just apply' to apply dotfiles."

# Apply dotfiles (runs chezmoi apply — run 'just init' first on a new machine)
apply:
    chezmoi apply --source {{CHEZMOI_SOURCE}}

# Show pending changes without applying
diff:
    chezmoi diff --source {{CHEZMOI_SOURCE}}

# Add a file to chezmoi management (e.g. just add ~/.config/foo/bar.toml)
add FILE:
    chezmoi add --source {{CHEZMOI_SOURCE}} {{FILE}}

# Edit a chezmoi-managed file
edit FILE:
    chezmoi edit --source {{CHEZMOI_SOURCE}} {{FILE}}

# =============================================================================
# Packages
# =============================================================================

# Bump the force-run timestamp in a package file (internal helper)
_bump file:
    #!/usr/bin/env bash
    set -euo pipefail
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    f="{{file}}"
    if grep -q '^# force-run:' "$f"; then
      sed -i.bak "s/^# force-run: .*/# force-run: $ts/" "$f" && rm -f "$f.bak"
    else
      echo "# force-run: $ts" >> "$f"
    fi

# Force re-run of all package install scripts
reinstall-packages:
    just _bump {{REPO_DIR}}/packages/Brewfile
    just _bump {{REPO_DIR}}/packages/packages.txt
    just _bump {{REPO_DIR}}/packages/npm-packages.txt
    just _bump {{REPO_DIR}}/packages/pip-packages.txt
    just _bump {{REPO_DIR}}/packages/cargo-packages.txt
    just _bump {{REPO_DIR}}/packages/bun-packages.txt
    just _bump {{REPO_DIR}}/packages/vscode-extensions.txt
    just _bump {{REPO_DIR}}/packages/krew-plugins.txt
    chezmoi apply --source {{CHEZMOI_SOURCE}}

# Force re-run of a specific package manager (e.g. just reinstall cargo)
# Managers: brew, pacman, npm, pip, cargo, bun, vscode, krew
reinstall manager:
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{manager}}" in
      brew)   f="{{REPO_DIR}}/packages/Brewfile" ;;
      pacman) f="{{REPO_DIR}}/packages/packages.txt" ;;
      vscode) f="{{REPO_DIR}}/packages/vscode-extensions.txt" ;;
      *)      f="{{REPO_DIR}}/packages/{{manager}}-packages.txt" ;;
    esac
    just _bump "$f"
    chezmoi apply --source {{CHEZMOI_SOURCE}}

