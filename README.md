# dotfiles

A simple tool to quickly setup my development environment on a new machine or after a fresh OS installation.

## What It Does

- Installs packages listed at packages.yaml (Homebrew on macOS, DNF/Flatpak on Linux)
- Symlinks dotfiles to your home directory using GNU Stow
- Backs up existing dotfiles before replacing them
- Sets up asdf with plugins (nodejs, python, rust, uv, etc) and global npm/pip/cargo/bun packages. Check packages.yaml
- Installs VSCode extensions from your configuration
- Installs LazyVim for Neovim configuration
- Provides a dry-run mode to preview changes before applying

## Quick Start

```bash
# Clone the repository
git clone https://github.com/gcaracuel/dotfiles.git
cd dotfiles

# Run the setup (installs personal packages + dotfiles)
./main.sh

# Include work-related packages
./main.sh --work

# Preview what would happen without making changes
./main.sh --dry-run
```

No prerequisites needed - the script automatically installs Homebrew, GNU Stow, and other dependencies.

## Options

| Flag | Description |
|------|-------------|
| `--work` | Include work packages (excluded by default) |
| `--skip-packages` | Skip package installation, LazyVim, and VSCode extensions (only symlink dotfiles) |
| `--skip-stow` | Skip dotfiles, only install packages |
| `--force-brew` | Force using Homebrew on Linux (for container testing) |
| `--dry-run` | Preview changes without applying them |
| `--help` | Show usage information |

## Project Structure

```
dotfiles/
├── README.md
├── AGENTS.md            # Guidelines for AI agents
├── main.sh              # Entry point
├── packages.yaml        # Package definitions
├── justfile             # Container testing (requires just command runner)
├── scripts/
│   ├── prerequisites.sh
│   ├── packages.sh
│   ├── stow.sh
│   ├── asdf.sh
│   ├── vscode.sh
│   ├── lazyvim.sh
│   └── utils.sh
├── .devcontainer/       # Container testing
│   ├── fedora/
│   └── homebrew/
└── dotfiles/            # Stow-managed dotfiles (mirrors $HOME)
    ├── .zshrc
    ├── .gitconfig
    ├── .config/
    │   └── ...
    └── ...
```

## Configuration

Packages are defined in `packages.yaml` using a unified schema:

```yaml
packages:
  - name: neovim             # Default package name
    description: Text editor
    gui: false               # false=CLI, true=GUI
    work: false              # false=personal, true=work-only
    # No overrides = same name on all platforms
    
  - name: dust
    description: du replacement
    gui: false
    work: false
    overrides:
      linux: du-dust         # Different name on Linux
      
  - name: rectangle
    description: Window management
    gui: true
    work: false
    overrides:
      linux: null            # macOS-only (skip on Linux)
      
  - name: visual-studio-code
    description: Code editor
    gui: true
    work: false
    overrides:
      linux: com.visualstudio.code  # Flatpak ID on Linux

# VSCode extensions
vscode_extensions:
  - golang.go
  - ms-python.python
  - rust-lang.rust-analyzer
  # ... see packages.yaml for full list

# Language-specific packages
npm:
  - "@anthropics/claude-code"

pip:
  - jrnl

cargo:
  - eza      # ls replacement
  - zellij   # Terminal multiplexer

bun:
  - openportal  # Mobile-first web UI for OpenCode
```

### Unified Package Schema

Each package entry has:
- `name`: Default package name (used if no override)
- `description`: Human-readable description  
- `gui`: `false` for CLI tools (brew/dnf), `true` for GUI apps (cask/flatpak)
- `work`: `false` for personal packages, `true` for work-only packages
- `overrides` (optional): Platform-specific package names
  - `macos`: macOS package name (or `null` to skip on macOS)
  - `linux`: Linux package name (or `null` to skip on Linux)

**Benefits:**
- Single source of truth per package
- Cross-platform differences are explicit
- Easy to see which packages are available on which OS
- ~40% less YAML compared to old structure

### VSCode Extensions

VSCode extensions are installed via the `code --install-extension` command:

- Extensions are listed in the `vscode_extensions` array in `packages.yaml`
- Extension IDs can be found in the VSCode marketplace (e.g., `golang.go`)
- Installation is idempotent (skips already-installed extensions)
- Requires VSCode to be installed first (via GUI packages)
- Gracefully skips if VSCode is not available

## Backup & Rollback

Before stowing, existing dotfiles are backed up to:
```
~/.dotfiles-backup/<timestamp>/
```

To rollback:
```bash
cd ~/.dotfiles-backup/2026-01-30_10-30-45
stow . --target=$HOME
```

## Platform Support

- **macOS**: Full support (Homebrew + Casks)
- **Linux (Fedora)**: Full support (DNF + Flatpak)
- **Other Linux**: Use `--force-brew` flag to install Homebrew on Linux

## asdf Installation

The script automatically installs [asdf](https://asdf-vm.com/) version manager:

- **Version**: Pinned to `v0.17.0` (configurable in `scripts/prerequisites.sh`)
- **Note**: Pre-built binaries only available from v0.15.0 onwards
- **Location**: `~/.asdf/`
- **Architecture**: Auto-detects OS and CPU (darwin/linux, amd64/arm64)
- **Binary Download**: Downloads pre-built binaries from GitHub releases
- **PATH Management**: Temporarily added to PATH during script execution

After installation, **manually add asdf to your shell**:

```bash
echo 'export PATH="$HOME/.asdf/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

The script will remind you to do this at the end.

## Manual Steps

Some things still require manual setup after running the script:
- SSH key generation
- Git configuration (name, email)
- Application logins (1Password, etc.)

These are printed at the end of the script execution.

## Testing

Local testing uses Docker containers to verify the bootstrap script works correctly (requires [just](https://github.com/casey/just)):

```bash
# Interactive test selection
just test

# Test in Fedora (native Linux)
just test-fedora

# Test with forced Homebrew
just test-brew

# Open shell for manual testing
just test-fedora-shell
just test-brew-shell

# Clean up
just clean
```

The Homebrew container uses `--force-brew` to override OS detection and run brew commands.

## Editor Configuration

### VSCode Extensions

The script automatically installs VSCode extensions from `packages.yaml`:

- Installs after GUI packages (ensures VSCode is available)
- Uses `code --install-extension` command
- Idempotent: skips already-installed extensions
- Case-insensitive extension ID matching
- Gracefully skips if VSCode not installed (with warning)
- Tied to `--skip-packages` flag

Example extensions:
- Language support: Python, Go, Rust, Java, Terraform
- Tools: Docker, GitHub Actions, Jupyter
- AI: Gemini Code Assist, IntelliCode

### LazyVim

The script automatically installs [LazyVim](https://www.lazyvim.org/) for Neovim configuration:

- Detects if LazyVim is already installed (skips if present)
- Backs up existing `~/.config/nvim` before installation
- Clones the LazyVim starter repository
- Removes `.git` folder so you can add to your own repo

Both VSCode extensions and LazyVim installation are tied to `--skip-packages` - if you skip packages, these are also skipped.

## Old version of this repository

This repository used to to cover dotfiles and packages installation using a complicated Ansible approach which if desires is still accesible via git tag: https://github.com/gcaracuel/dotfiles/releases/tag/0.x

## Future plans for this project

I want to quit MacOS and fully switch back to Linux which will simplify (or not) a lot this repository.
The plan is to run Fedora Sway Atomic or NixOS running Sway/Hyprland as work machines and Fedora or another NixOs for personal use.
In that scenario Nix will be key point so home-manager sounds like the dotfiles substitute, even on Fedora Atomic Nix would be the thing to have very same features for packages than the atomicity of the system itself so is a win-win, even if combined with Faltpaks for simplicity around GUI applications.