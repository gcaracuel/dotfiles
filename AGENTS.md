# dotfiles — AGENTS.md

Developer and AI agent guide for this dotfiles repository.

## Repository Overview

**Project:** Dotfiles managed with [chezmoi](https://chezmoi.io)  
**Platforms:** macOS (Homebrew) and Arch Linux (pacman)  
**Runtime manager:** [Mise](https://mise.jdx.dev) (replaces asdf)  
**Package definitions:** plain text/TOML files in `packages/`  
**Dotfiles location:** `home/` (chezmoi source root, symlinked from `~/.local/share/chezmoi`)

---

## Directory Structure

```
dotfiles/
├── README.md                         # Quick start and reference
├── MANUAL_STEPS.md                   # Steps that cannot be automated
├── AGENTS.md                         # This file
├── justfile                          # Task runner (just)
│
├── packages/                         # Human-editable package lists
│   ├── Brewfile                      # Homebrew formulas + casks
│   ├── Brewfile.work                 # Work-only brew packages
│   ├── packages.txt                  # Arch/pacman packages
│   ├── packages.work.txt             # Work-only pacman packages
│   ├── npm-packages.txt              # npm globals (via mise node)
│   ├── pip-packages.txt              # pip/uv packages (via mise python/uv)
│   ├── cargo-packages.txt            # cargo packages (via mise rust)
│   ├── bun-packages.txt              # bun globals (via mise bun)
│   ├── vscode-extensions.txt         # VSCode extension IDs
│   └── krew-plugins.txt              # kubectl krew plugin names
│
├── home/                             # chezmoi source root
│   ├── .chezmoi.toml.tmpl            # Config template (prompts for .work)
│   ├── dot_zshrc                     # → ~/.zshrc
│   ├── dot_gitconfig                 # → ~/.gitconfig
│   ├── dot_gitignore_global          # → ~/.gitignore_global
│   ├── dot_tool-versions             # → ~/.tool-versions (asdf compat)
│   ├── dot_starship.toml             # → ~/.starship.toml
│   ├── dot_tmux.conf                 # → ~/.tmux.conf
│   ├── dot_tmux/                     # → ~/.tmux/ (tpm vendored)
│   ├── dot_gemini/                   # → ~/.gemini/
│   └── dot_config/
│       ├── mise/config.toml          # → ~/.config/mise/config.toml (runtimes)
│       ├── atuin/                    # → ~/.config/atuin/
│       ├── Code/User/                # → ~/.config/Code/User/
│       ├── eza/                      # → ~/.config/eza/
│       ├── gh-dash/                  # → ~/.config/gh-dash/
│       ├── ghostty/                  # → ~/.config/ghostty/
│       ├── k9s/                      # → ~/.config/k9s/
│       ├── nvim/lua/plugins/         # → ~/.config/nvim/lua/plugins/ (overlay on LazyVim)
│       ├── opencode/                 # → ~/.config/opencode/
│       ├── worktrunk/                # → ~/.config/worktrunk/
│       └── yazi/                     # → ~/.config/yazi/
│
│   └── .chezmoiscripts/              # Run scripts (executed by chezmoi apply)
│       ├── run_once_before_00-bootstrap.sh.tmpl      # Install brew/pacman
│       ├── run_onchange_01-brew-packages.sh.tmpl     # brew bundle + uninstall
│       ├── run_onchange_02-pacman-packages.sh.tmpl   # pacman -S + uninstall
│       ├── run_onchange_03-mise-tools.sh.tmpl        # mise install
│       ├── run_onchange_04-npm-packages.sh.tmpl      # npm -g + uninstall
│       ├── run_onchange_05-pip-packages.sh.tmpl      # uv tool install + uninstall
│       ├── run_onchange_06-cargo-packages.sh.tmpl    # cargo install + uninstall
│       ├── run_onchange_07-bun-packages.sh.tmpl      # bun add -g + uninstall
│       ├── run_onchange_08-vscode-extensions.sh.tmpl # code --install-extension
│       ├── run_onchange_09-krew-plugins.sh.tmpl      # krew install
│       ├── run_once_10-ohmyzsh.sh                    # Oh My Zsh (once)
│       ├── run_once_11-lazyvim.sh                    # LazyVim starter (once)
│       ├── run_onchange_10-macos-library-configs.sh.tmpl # macOS Library symlinks (VSCode, k9s)
│       └── run_once_99-manual-steps.sh               # Print MANUAL_STEPS.md
│
├── archive/                          # Old macOS configs (kept for reference)
└── .devcontainer/
    ├── arch/                         # Arch Linux test container
    └── homebrew/                     # Homebrew test container
```

---

## How Chezmoi Works Here

### Source root = `home/`

The `home/` directory is the chezmoi source. It is symlinked from `~/.local/share/chezmoi`:

```bash
~/.local/share/chezmoi -> /path/to/this/repo/home
```

Run `just init` to create this symlink.

### Dotfile naming convention

Chezmoi uses name prefixes to map files to `$HOME`:

| Source name | Destination |
|---|---|
| `dot_zshrc` | `~/.zshrc` |
| `dot_config/ghostty/config` | `~/.config/ghostty/config` |
| `dot_tmux/plugins/tpm/` | `~/.tmux/plugins/tpm/` |

### Templates

Files ending in `.tmpl` are Go templates processed by chezmoi. The main config template is `home/.chezmoi.toml.tmpl` which prompts for the `work` boolean on first run and stores it in `~/.config/chezmoi/chezmoi.toml`.

Scripts in `.chezmoiscripts/` that end in `.tmpl` use this to conditionally include work packages:

```bash
{{ if .chezmoi.config.data.work }}
# install work packages
{{ end }}
```

---

## Script Types

| Prefix | Behavior |
|---|---|
| `run_once_` | Runs exactly once per machine (tracked in chezmoi state) |
| `run_once_before_` | Same but runs before dotfiles are applied |
| `run_onchange_` | Re-runs whenever the script content changes (the file hash is the trigger) |

### How `run_onchange_` scripts detect file changes

Each `run_onchange_` script embeds a hash comment of its input package file using chezmoi templates:

```bash
# packages/Brewfile hash: {{ include (joinPath .chezmoi.sourceDir "../packages/Brewfile") | sha256sum }}
```

When the package file changes, the embedded hash changes → the script content changes → chezmoi re-runs it. **You never need to manually trigger re-runs.**

### Uninstall detection

Each `run_onchange_` script:
1. Reads the current desired package list
2. Compares against the last-applied list in `~/.local/share/dotfiles-state/<manager>-installed.txt`
3. Uninstalls packages present in the state file but missing from the current list
4. Installs any new packages
5. Writes the updated state file

**To uninstall a package:** remove it from its list file, then run `just apply`.

### macOS Library Application Support symlinks

Some macOS applications read configuration from `~/Library/Application Support/` instead of `~/.config/`. The `run_onchange_10-macos-library-configs.sh.tmpl` script handles this by creating symlinks or copying files from `~/.config/` to the macOS-specific location.

**Current mappings:**
- **VSCode:** `~/.config/Code/User/settings.json` → `~/Library/Application Support/Code/User/settings.json` (copied)
- **k9s:** `~/.config/k9s/config.yaml` → `~/Library/Application Support/k9s/config.yaml` (symlinked)
- **k9s:** `~/.config/k9s/skins/` → `~/Library/Application Support/k9s/skins` (symlinked)

The script embeds hashes of the source files and re-runs whenever they change. This keeps the macOS-specific locations in sync with the chezmoi-managed dotfiles.

**To add a new macOS Library mapping:**
1. Add a hash line at the top of the script for change detection
2. Add the copy/symlink logic in the script body
3. Test with `just apply`

---

## Package Manager Rule of Thumb

| What | Where |
|---|---|
| System CLI tools available on both macOS + Arch | `packages/Brewfile` + `packages/packages.txt` |
| GUI applications | `packages/Brewfile` (cask) + `packages/packages.txt` |
| Work-only tools | `packages/Brewfile.work` + `packages/packages.work.txt` |
| Programming language runtimes | `home/dot_config/mise/config.toml` |
| npm global tools | `packages/npm-packages.txt` |
| Python CLI tools (isolated) | `packages/pip-packages.txt` (uses uv tool install) |
| Rust CLI tools | `packages/cargo-packages.txt` |
| Bun global tools | `packages/bun-packages.txt` |
| VSCode extensions | `packages/vscode-extensions.txt` |
| kubectl plugins | `packages/krew-plugins.txt` |

**Prefer brew/pacman** when a tool is available natively on both platforms.  
**Use mise runtimes** for all programming language versions.  
**Use language package managers via mise** for tools not in brew/pacman on both platforms.

---

## Common Tasks

### Add a brew package

Edit `packages/Brewfile`, add a `brew "name"` or `cask "name"` line, then:

```bash
just apply
```

### Add an Arch package

Edit `packages/packages.txt`, add the package name on a new line.

### Add a new dotfile

```bash
just add ~/.config/foo/bar.toml
```

This copies the file into `home/` with the correct `dot_` naming and registers it with chezmoi.

### Add a new programming runtime

Edit `home/dot_config/mise/config.toml` under `[tools]`:

```toml
[tools]
node = "24.13.0"
deno = "2.0.0"   # new
```

Then run `just apply` — chezmoi will re-link the config and `mise install` will run via `run_onchange_03`.

Also update `home/dot_tool-versions` to keep asdf compatibility for coworkers.

### Add a cargo package from git

Edit `packages/cargo-packages.txt` using the `name|git-url` format:

```
my-tool|https://github.com/example/my-tool.git
```

### Add a manual step

Edit `MANUAL_STEPS.md`. It is printed automatically after first `chezmoi apply` via `run_once_99-manual-steps.sh`.

---

## Testing

**NEVER run scripts directly on the host machine. Always use containers.**

```bash
just test             # Interactive: choose Arch or Homebrew
just test-arch        # Arch Linux container (pacman)
just test-brew        # Homebrew container (simulates macOS)
just test-arch-shell  # Interactive shell in Arch container for debugging
just test-brew-shell  # Interactive shell in Brew container for debugging
just clean            # Remove test images
just clean-all        # Remove images + Docker build cache
```

### Platform note (Apple Silicon)

`archlinux:latest` only provides `x86_64` images. On Apple Silicon, the Arch container runs under Rosetta emulation (`--platform linux/amd64`). This is handled automatically by `just build-arch` and `just test-arch-shell`.

pacman's sandboxing (`alpm` user + seccomp) does not work under Rosetta. The Dockerfile disables it with `DisableSandbox` in `/etc/pacman.conf`. Do not remove this line.

The Homebrew container uses native `arm64` bottles and runs natively on Apple Silicon.

### What the tests validate

**`just test-arch`:**
- pacman package installation
- chezmoi dotfile application
- Arch-specific paths

**`just test-brew`:**
- Homebrew formula and cask installation
- chezmoi dotfile application
- Homebrew paths (simulates macOS environment)

---

## Work Mode

On `chezmoi init` (first run), chezmoi prompts:

> **Include work packages?**

The answer is stored in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
  work = true
```

To change it after the fact:

```bash
chezmoi init  # re-prompts
# or edit directly:
chezmoi edit-config
```

Work packages are defined in:
- `packages/Brewfile.work` (macOS)
- `packages/packages.work.txt` (Arch)

---

## Mise vs asdf

Mise is the runtime manager. It is API-compatible with asdf and reads `.tool-versions` files.

- `home/dot_config/mise/config.toml` — primary config, managed as a chezmoi dotfile
- `home/dot_tool-versions` — kept in `$HOME` for asdf coworker compatibility
- `.zshrc` uses `eval "$(mise activate zsh)"` instead of asdf PATH setup

The two files must stay in sync when updating runtime versions.

---

## Critical Rules for Agents

1. **Never test on the host machine.** Always use `just test-arch` or `just test-brew`.

2. **Keep package definitions in `packages/` files.** Never hardcode package names in scripts.

3. **`run_onchange_` scripts must embed the hash of their input file** so chezmoi knows when to re-run them. Use the pattern:
   ```
   # file hash: {{ include (joinPath .chezmoi.sourceDir "../packages/Brewfile") | sha256sum }}
   ```

4. **Maintain idempotency.** All operations must be safe to run multiple times. Check before installing, use `--needed` flags.

5. **Both `dot_config/mise/config.toml` and `dot_tool-versions` must stay in sync** when changing runtime versions. Update both files together.

6. **Scripts use `set -euo pipefail`.** Use `count=$((count + 1))` not `((count++))` to avoid exit-code-1 issues with strict mode.

7. **Error handling:** show error output for failed package installs (first few lines), don't suppress with `&>/dev/null`. Use `|| echo "WARNING: ..."` for non-fatal failures.

8. **Update `MANUAL_STEPS.md`** for anything that cannot be automated.

9. **Update this file (AGENTS.md)** when adding new scripts, new package list files, or new patterns.
