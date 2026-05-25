# dotfiles

Personal development environment managed with [chezmoi](https://chezmoi.io).

Supports **macOS** (Homebrew) and **Arch Linux** (pacman).

---

## Quick Start

### Prerequisites

You need `git` and `just` before anything else. There is a chicken-and-egg situation here: the justfile manages setup, but `just` itself must be installed first.

**macOS**

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install just
brew install just
```

**Arch Linux**

```bash
sudo pacman -S --needed git just
```

---

### 1. Clone this repo

```bash
git clone https://github.com/gcaracuel/dotfiles.git ~/Projects/github/gcaracuel/dotfiles
cd ~/Projects/github/gcaracuel/dotfiles
```

### 2. Install Homebrew (if needed) + chezmoi, and link this repo as the source

```bash
just init
```

On macOS this will install Homebrew first if it is missing, then install chezmoi, then create the symlink:
`~/.local/share/chezmoi → <this-repo>/home`

On Arch Linux it installs chezmoi via pacman.

### 3. Initialise chezmoi config (prompts for work mode)

```bash
chezmoi init --source $PWD/home
```

This processes `.chezmoi.toml.tmpl` and writes `~/.config/chezmoi/chezmoi.toml` with your answers. You will be asked:
> **Include work packages?**

Only needs to be run once per machine. To change the answer later: `chezmoi init` again or `chezmoi edit-config`.

### 4. Apply

```bash
just apply
```

---

## What it does

| Step | What happens |
|---|---|
| `run_once_before_00` | Installs Homebrew (macOS) or validates pacman (Arch) |
| `run_onchange_01` | `brew bundle` — installs/uninstalls Homebrew packages |
| `run_onchange_02` | `pacman -S` — installs/uninstalls Arch packages |
| `run_onchange_03` | `mise install` — installs runtimes (node, python, rust, go, bun, ...) |
| `run_onchange_04-07` | npm / pip / cargo / bun global packages |
| `run_onchange_08` | VSCode extensions |
| `run_onchange_09` | kubectl krew plugins |
| `run_once_10` | Oh My Zsh |
| `run_once_11` | LazyVim starter for Neovim |
| `run_once_99` | Prints `MANUAL_STEPS.md` |

Dotfiles in `home/` are symlinked to `$HOME` by chezmoi.

---

## Where to add/remove packages

| What | File |
|---|---|
| Homebrew formulas/casks | `packages/Brewfile` |
| Homebrew work packages | `packages/Brewfile.work` |
| Arch/pacman packages | `packages/packages.txt` |
| Arch work packages | `packages/packages.work.txt` |
| Programming runtimes (node, python, rust...) | `home/dot_config/mise/config.toml` |
| npm global packages | `packages/npm-packages.txt` |
| pip packages | `packages/pip-packages.txt` |
| cargo packages | `packages/cargo-packages.txt` |
| bun packages | `packages/bun-packages.txt` |
| VSCode extensions | `packages/vscode-extensions.txt` |
| kubectl krew plugins | `packages/krew-plugins.txt` |

After editing any file, run `just apply` to sync.

**Uninstall detection:** removing a package from its list and running `just apply` will uninstall it.

---

## Package manager rule of thumb

- **Homebrew / pacman** — system CLI tools and GUI apps available on both platforms
- **Mise** — programming language runtimes (node, python, rust, go, bun, terraform...)
- **npm / pip / cargo / bun via Mise** — language-specific tooling not in brew/pacman
- **`.tool-versions`** — kept in `$HOME` for asdf coworker compatibility (auto-linked by chezmoi)

---

## Daily workflow

```bash
just apply          # Apply all changes
just update         # git pull + apply
just diff           # Preview pending changes
just add ~/.foo     # Add a new dotfile to chezmoi
just edit ~/.foo    # Edit a managed dotfile
```

---

## Migrating from the old stow-based setup

If you have existing stow symlinks pointing at the old `dotfiles/` directory:

```bash
just init     # installs Homebrew + chezmoi, creates symlink
just migrate  # runs chezmoi init (prompts work mode), removes old stow symlinks, applies chezmoi
```

---

## Testing

Tests run in isolated Docker containers — never on the host machine.

```bash
just test           # Interactive: choose Arch or Homebrew
just test-arch      # Arch Linux container
just test-brew      # Homebrew container
just test-arch-shell  # Interactive shell in Arch container
just test-brew-shell  # Interactive shell in Brew container
just clean          # Remove test images
```

---

## Manual steps

Some things can't be automated. After first setup, chezmoi prints `MANUAL_STEPS.md`.
You can also view it directly:

```bash
cat MANUAL_STEPS.md
```
