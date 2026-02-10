# Product Requirements Document: Dotfiles Bootstrap

**Version:** 1.0  
**Last Updated:** February 5, 2026  
**Status:** Production Ready

---

## 1. Executive Summary

### Purpose

The Dotfiles Bootstrap Tool is an automated development environment setup system that transforms a fresh machine into a fully configured development workstation with a single command. The tool manages system packages, GUI applications, runtime environments, and personal dotfiles across macOS and Linux platforms.

### Goals

1. **Quick Setup:** Bootstrap a new machine to a working development state in under 30 minutes with minimal manual intervention
2. **Reproducibility:** Ensure identical development environments across multiple machines
3. **Maintainability:** Centralize all configuration in a single YAML file for easy package management
4. **Cross-Platform:** Support both macOS (Homebrew) and Linux (Fedora with DNF/Flatpak) with explicit OS-specific handling

### Non-Goals

- Desktop customization or "ricing" (themes, widgets, etc.)
- System-level configurations outside the user's home directory
- Support for every Linux distribution (Fedora only for v1.0)
- Encrypted secrets management or password vault integration
- Automated login to cloud services or applications

### Success Criteria

- User runs `./main.sh` and receives a fully functional development environment
- Script is idempotent: safe to run multiple times without errors or duplication
- Clear, actionable error messages guide users through any failures
- Container tests pass on both Fedora and Homebrew environments
- Installation completes in under 30 minutes on standard hardware

---

## 2. Technical Architecture

### Technology Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Language | Bash 4+ with strict mode (`set -euo pipefail`) | Simple orchestration, no compilation, available everywhere |
| Terminal UI | gum (charmbracelet) | Beautiful, consistent terminal output without complex ncurses |
| Configuration | YAML parsed with yq v4 | Human-readable, queryable, widely supported |
| Dotfiles | GNU Stow | Industry standard, symlink-based, reversible |
| Package Managers | Homebrew (macOS) / DNF + Flatpak (Linux) | Native to each platform, well-maintained |
| Version Management | asdf | Cross-language runtime manager, community-driven |
| Testing | Docker containers + justfile | Local reproducible testing without CI/CD dependency |

### Project Structure

```
dotfiles/
├── main.sh                      # Entry point - orchestrates all phases
├── packages.yaml                # Single source of truth for packages (~200 lines)
├── justfile                     # Test orchestration commands
├── README.md                    # User-facing documentation
├── AGENTS.md                    # Guidelines for AI agents
├── scripts/                     # Modular components
│   ├── utils.sh                 # Logging, OS detection, argument parsing
│   ├── prerequisites.sh         # Auto-install package managers and tools
│   ├── packages.sh              # Parse YAML and install packages
│   ├── stow.sh                  # Backup and symlink dotfiles
│   ├── asdf.sh                  # Runtime version management
│   ├── vscode.sh                # VSCode extension installation
│   ├── lazyvim.sh               # Neovim LazyVim configuration
│   └── ohmyzsh.sh               # Oh My Zsh shell setup
├── .devcontainer/               # Testing infrastructure
│   ├── fedora/                  # Native Linux (DNF + Flatpak)
│   └── homebrew/                # Homebrew on Linux (macOS simulation)
└── dev/                         # Project documentation
    ├── PRD.md                   # This document
    └── ROADMAP.md               # Future enhancements
```

### Design Principles

1. **Idempotency:** Every operation checks existing state before modifying; safe to run multiple times
2. **Fail-Fast:** Strict error handling with `set -euo pipefail`; stop on critical failures
3. **Modularity:** Separate scripts for each concern; easy to test and extend
4. **Testability:** Docker containers provide clean, reproducible testing environments
5. **Transparency:** Dry-run mode shows exactly what will happen; verbose logging available
6. **User-Friendly:** Beautiful terminal output with progress indicators and clear summaries

---

## 3. Core Features

### 3.1 Prerequisites Auto-Installation

**Requirement:** The system must automatically install all required tools and package managers if missing, without user intervention.

#### Components

**Package Managers:**
- macOS: Homebrew (installed via official script if missing)
- Linux: DNF (pre-installed on Fedora) and Flatpak (configured if missing)

**Essential Tools:**
- GNU Stow: Dotfiles symlink management
- gum: Terminal UI for beautiful output
- yq v4: YAML parsing and querying

**Runtime Management:**
- asdf v0.17.0: Cross-language version manager (pre-built binaries from GitHub)

**Fedora COPR Repositories:**
- `atim/lazygit`: LazyGit TUI for Git
- `che/nerd-fonts`: Nerd Fonts collection
- `atim/starship`: Starship shell prompt
- `scottames/ghostty`: Ghostty terminal emulator
- `lihaohong/yazi`: Yazi file manager

#### Behavior

1. Detect operating system and CPU architecture automatically
2. Check if each tool is already installed (idempotent)
3. Install missing tools without requiring user confirmation
4. Verify successful installation before proceeding
5. Add asdf to PATH for current session (user must add to shell config permanently)
6. Enable COPR repositories on Fedora before package installation

#### Error Handling

- **Network failures:** Display clear error message suggesting connectivity check
- **Permission issues:** Provide instructions for sudo or Homebrew ownership fixes
- **Missing system dependencies:** Auto-install git/curl if needed
- **Critical failures:** Stop execution with actionable error message

---

### 3.2 Unified Package Management

**Requirement:** A single YAML configuration file manages all packages across platforms with explicit OS-specific overrides.

#### Configuration Schema

The `packages.yaml` file uses a unified schema that eliminates duplication while making platform differences explicit:

```yaml
packages:
  - name: string           # Default package name (used if no override)
    description: string    # Human-readable purpose
    gui: boolean          # false = CLI tool (brew/dnf), true = GUI app (cask/flatpak)
    work: boolean         # false = personal use, true = work-only
    overrides:            # Optional: OS-specific package names
      macos: string|null  # macOS override (null = skip on macOS)
      linux: string|null  # Linux override (null = skip on Linux)
```

#### Package Resolution Rules

1. **Cross-platform packages:** If name is identical on both platforms, no overrides needed
2. **Different names:** Use `overrides.macos` or `overrides.linux` for platform-specific names
3. **Platform-exclusive:** Set the opposite platform's override to `null` to skip
4. **Flatpak apps:** Use full Flatpak ID (e.g., `com.visualstudio.code`) in `overrides.linux`

#### Examples

```yaml
# Cross-platform package (same name everywhere)
- name: neovim
  description: Modern text editor
  gui: false
  work: false

# Different names per platform
- name: dust
  description: Intuitive du replacement
  gui: false
  work: false
  overrides:
    linux: du-dust      # Different package name on Linux

# macOS-only package
- name: rectangle
  description: Window management tool
  gui: true
  work: false
  overrides:
    linux: null         # Not available on Linux

# Linux Flatpak application
- name: bruno
  description: Fast API client
  gui: true
  work: false
  overrides:
    macos: null
    linux: com.usebruno.Bruno  # Flatpak ID

# Work-only package
- name: kubectl
  description: Kubernetes CLI
  gui: false
  work: true           # Only installed with --work flag
```

#### Package Installation

**Requirement:** The system must install all configured packages using the appropriate package manager for the current platform.

**Installation Methods:**

| Platform | CLI Packages | GUI Applications |
|----------|-------------|------------------|
| macOS | `brew install <name>` | `brew install --cask <name>` |
| Linux | `sudo dnf install -y <name>` | `flatpak install -y flathub <flatpak-id>` |

**Process:**

1. Parse `packages.yaml` using yq
2. Filter packages by `gui` flag (respect `--no-gui`)
3. Filter packages by `work` flag (respect `--work`)
4. Resolve package names using OS-specific overrides
5. Check if each package is already installed (idempotent)
6. Skip packages with `null` override for current OS
7. Install missing packages sequentially
8. Log warnings for failures, continue with remaining packages
9. Display summary: X installed, Y already present, Z skipped, W failed

**Requirements for Correct Operation:**

1. **Loop Integrity:** Installation loop must process ALL packages in the list
2. **Safe Arithmetic:** Counter increments must not cause script exit in strict mode
3. **Output Isolation:** Package manager output must not interfere with loop processing
4. **Input Protection:** Interactive package managers must not consume loop input

**Error Handling:**

- **Package not found:** Log warning, continue with next package
- **Network failure:** Display error, stop installation to prevent partial state
- **Permission denied:** Suggest sudo or Homebrew ownership fix
- **Dependency conflicts:** Display package manager error, suggest resolution steps

---

### 3.3 Dotfiles Management

**Requirement:** Deploy personal dotfiles to `$HOME` using GNU Stow with automatic backup of existing files.

#### Process

1. **Scan:** Identify all files in `dotfiles/` directory to be deployed
2. **Backup:** For each file that exists in `$HOME`:
   - Create timestamped backup directory: `~/.dotfiles-backup/<YYYY-MM-DD_HH-MM-SS>/`
   - Copy existing file to backup, preserving directory structure
   - Structure is stow-compatible for easy rollback
3. **Deploy:** Execute `cd dotfiles/ && stow . --target=$HOME`
4. **Conflict Handling:** Detect and report conflicts (non-regular files), don't overwrite

#### Rollback Process

Backups are stow-compatible, allowing easy restoration:

```bash
cd ~/.dotfiles-backup/<timestamp>/
stow . --target=$HOME
```

#### Dry-Run Preview

When run with `--dry-run`, the system compares `dotfiles/` with `$HOME` and shows:

- **New files (+):** Present in dotfiles/ but not in $HOME (will be created)
- **Modified (~):** Present in both but content differs (will be replaced, original backed up)
- **Identical (=):** Present in both with same content (no action needed)
- **Symlinked (@):** Already a symlink to dotfiles/ directory (no action needed)
- **Conflict (!):** Exists but is not a regular file or symlink (manual intervention required)

---

### 3.4 Runtime & Development Tools

#### asdf Version Management

**Requirement:** Install asdf and manage language runtime versions.

**Installation:**
1. Download asdf v0.17.0 pre-built binary from GitHub releases
2. Detect system architecture (darwin/linux, amd64/arm64)
3. Extract to `~/.asdf/`
4. Add to PATH for current session
5. Print reminder for user to add to shell configuration

**Plugin & Version Setup:**
1. Install language plugins: nodejs, python, rust, uv, bun
2. Read `~/.tool-versions` if present for version pins
3. Install pinned versions via `asdf install`
4. Install global packages for each runtime

**Global Package Installation:**

| Package Manager | Command | Source in packages.yaml |
|----------------|---------|------------------------|
| npm | `npm install -g <package>` | `npm:` section |
| pip | `pip install <package>` or `uv pip install` | `pip:` section |
| cargo | `cargo install <package>` | `cargo:` section |
| bun | `bun install -g <package>` | `bun:` section |
| uv tools | `uv tool install <name> --from <source>` | `uv_tools:` section |

**Error Handling:**
- asdf binary download fails: Suggest manual installation
- Plugin installation fails: Display plugin URL and troubleshooting steps
- Version installation fails: Show asdf error output, suggest checking `.tool-versions`

---

#### VSCode Extensions

**Requirement:** Automatically install configured Visual Studio Code extensions.

**Process:**
1. Check if `code` CLI is available (skip gracefully if VSCode not installed)
2. Parse `vscode_extensions` list from packages.yaml
3. Query installed extensions via `code --list-extensions`
4. Check each extension (case-insensitive matching)
5. Install missing extensions via `code --install-extension <id>`
6. Display progress and summary (X installed, Y already present)

**Configuration:** 30 extensions defined in packages.yaml covering:
- Language support (Python, Go, Java, Rust, Terraform)
- Tools (Docker, GitHub Actions, remote containers)
- AI assistance (Gemini Code Assist, IntelliCode)
- Utilities (file icons, TODO tree, Prettier, Markdown)

---

#### LazyVim Configuration

**Requirement:** Install LazyVim Neovim distribution if Neovim is present.

**Detection:** Check for `~/.config/nvim/lua/config/lazy.lua` containing "lazyvim" string

**Process:**
1. Detect if LazyVim is already installed (skip if yes)
2. If `~/.config/nvim` exists but is not LazyVim, back it up to `~/.dotfiles-backup/<timestamp>/nvim`
3. Clone LazyVim starter repository: `https://github.com/LazyVim/starter`
4. Remove `.git` folder (per official LazyVim instructions)
5. Inform user to run `nvim` to complete plugin installation

**Integration:** Tied to `--skip-packages` flag (when skipping packages, also skip LazyVim)

---

#### Oh My Zsh

**Requirement:** Install Oh My Zsh framework for zsh shell enhancement.

**Process:**
1. Install zsh if missing (via system package manager)
2. Detect if Oh My Zsh is already installed at `~/.oh-my-zsh` (skip if yes)
3. Run official Oh My Zsh installer in non-interactive mode
4. Set environment variable `KEEP_ZSHRC=yes` to preserve existing `.zshrc`
5. Attempt to set zsh as default shell via `chsh` (graceful failure in containers)

**Container Handling:** The `chsh` command may fail in containerized environments; log warning and continue

**Integration:** Tied to `--skip-packages` flag (when skipping packages, also skip Oh My Zsh)

---

### 3.5 Testing Infrastructure

**Requirement:** Provide local testing in reproducible Docker container environments.

#### Container Environments

| Container | Base Image | Purpose |
|-----------|-----------|---------|
| **Fedora** | `fedora:latest` | Test native Linux with DNF and Flatpak |
| **Homebrew** | `ghcr.io/homebrew/ubuntu22.04` | Simulate macOS environment (Homebrew pre-installed) |

#### justfile Commands

| Command | Description |
|---------|-------------|
| `just test` | Interactive menu to select test environment |
| `just test-fedora` | Run full bootstrap in Fedora container |
| `just test-brew` | Run full bootstrap in Homebrew container with `--force-brew` |
| `just test-fedora-shell` | Open interactive bash shell in Fedora container |
| `just test-brew-shell` | Open interactive bash shell in Homebrew container |
| `just test-fedora-debug` | Run Fedora container and keep it alive for inspection |
| `just test-brew-debug` | Run Homebrew container and keep it alive for inspection |
| `just clean` | Remove test container images |
| `just clean-all` | Remove images and Docker build cache |

#### Container Behavior

- **Ephemeral:** Containers are removed after test completes (unless using debug mode)
- **Volume Mounting:** Project directory mounted at `/workspace` for live testing
- **Verbose Logging:** Run with `--verbose` flag for comprehensive debug output
- **Full Installation:** Execute complete bootstrap (not dry-run) for end-to-end validation

---

### 3.6 Operational Features

#### Dry-Run Mode

**Requirement:** Preview all planned changes without modifying the system.

**Behavior:**
- Enable with `--dry-run` flag
- Use native package manager dry-run capabilities:
  - **Homebrew:** `brew install --dry-run <package>`
  - **DNF:** `dnf install --assumeno <package>`
  - **Flatpak:** `flatpak install --no-deploy <package>`
- Compare `dotfiles/` with `$HOME` and show differences
- Display comprehensive summary of planned actions
- Exit with code 0 (no modifications made)

**Output:** Shows whether each package is already installed or would be installed, and which dotfiles would be created, modified, or left unchanged.

---

#### Verbose Logging

**Requirement:** Comprehensive debug logging for troubleshooting.

**Behavior:**
- Enable with `--verbose` or `-v` flag
- Write detailed logs to `debug.log` in working directory
- Capture:
  - All package processing steps and loop iterations
  - Command outputs (especially on failures)
  - OS detection and package name resolution
  - Timestamps for each log entry
- Automatically excluded from git via `.gitignore`

**Use Case:** When installation fails, review `debug.log` to identify the exact point of failure and error details.

---

#### Idempotency

**Requirement:** Safe to execute multiple times without errors, duplication, or unnecessary work.

**Implementation:**
- Check if tool/package already installed before attempting installation
- Skip already-installed items with success message
- LazyVim detection: Check for specific configuration file
- Oh My Zsh detection: Check for `~/.oh-my-zsh` directory
- asdf detection: Check for `~/.asdf/bin/asdf` binary
- VSCode extensions: Query installed extensions before installing
- Package managers: Use built-in check commands (rpm -q, brew list, flatpak list)

**Expected Behavior:** Second run shows "already installed" for all components, completes quickly.

---

## 4. CLI Interface

### Command Structure

```bash
./main.sh [OPTIONS]
```

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `--work` | false | Include work packages (excluded by default) |
| `--no-gui` | false | Skip GUI applications, install CLI tools only |
| `--skip-packages` | false | Skip package installation, LazyVim, VSCode extensions, and Oh My Zsh |
| `--skip-stow` | false | Skip dotfiles symlinking, only install packages |
| `--force-brew` | - | Force Homebrew on Linux (for container testing to simulate macOS) |
| `--dry-run` | false | Preview all changes without applying them |
| `--verbose`, `-v` | false | Enable comprehensive debug logging to debug.log |
| `--help`, `-h` | - | Display usage information and exit |

### Usage Examples

```bash
# Standard personal setup (CLI + GUI packages)
./main.sh

# Include work packages in addition to personal
./main.sh --work

# Install CLI tools only (useful for servers or containers)
./main.sh --no-gui

# Install work CLI tools only
./main.sh --work --no-gui

# Preview all changes without making any modifications
./main.sh --dry-run

# Run with comprehensive debug logging
./main.sh --verbose

# Only symlink dotfiles, skip package installation
./main.sh --skip-packages

# Only install packages, skip dotfiles
./main.sh --skip-stow

# Container testing: force Homebrew on Linux
./main.sh --force-brew
```

### Flag Combinations

| Command | Personal CLI | Personal GUI | Work CLI | Work GUI |
|---------|-------------|-------------|----------|----------|
| `./main.sh` | ✓ | ✓ | ✗ | ✗ |
| `./main.sh --work` | ✓ | ✓ | ✓ | ✓ |
| `./main.sh --no-gui` | ✓ | ✗ | ✗ | ✗ |
| `./main.sh --work --no-gui` | ✓ | ✗ | ✓ | ✗ |

---

## 5. Platform Support

### macOS

**Supported Versions:** macOS 11 (Big Sur) and later

**Architecture:**
- Intel (x86_64)
- Apple Silicon (arm64)

**Package Management:**
- CLI packages: Homebrew formulas via `brew install`
- GUI applications: Homebrew casks via `brew install --cask`

**Prerequisites:**
- Xcode Command Line Tools (automatically installed by Homebrew if missing)
- Administrator access for certain installations

**Package Count:**
- Personal CLI: ~25 packages
- Personal GUI: ~5 applications  
- Work packages: ~5 additional tools

**Special Considerations:**
- macOS ships with Bash 3.2; Homebrew installs Bash 5.x
- asdf binary architecture detection handles both Intel and Apple Silicon

---

### Linux (Fedora)

**Supported Versions:** Fedora 39 and later

**Architecture:**
- x86_64 (Intel/AMD)
- aarch64 (ARM64)

**Package Management:**
- CLI packages: DNF via `sudo dnf install`
- GUI applications: Flatpak via `flatpak install flathub`

**COPR Repositories:**

The following COPR repositories are enabled for packages not in official Fedora repos:

- `atim/lazygit` - LazyGit TUI for Git
- `che/nerd-fonts` - Nerd Fonts collection (all variants)
- `atim/starship` - Starship cross-shell prompt
- `scottames/ghostty` - Ghostty terminal emulator
- `lihaohong/yazi` - Yazi file manager

**Prerequisites:**
- sudo access for DNF package installations
- Flatpak configured (automatically configured by prerequisites script if missing)

**Package Count:**
- Personal CLI: ~25 packages
- Personal GUI: ~4 applications (via Flatpak)
- Work packages: ~4 additional tools

---

## 6. Requirements & Constraints

### Functional Requirements

**FR-001: Complete Package Installation**
- System MUST install ALL packages defined in packages.yaml that match current filters
- Installation loop MUST process every package in the list without early termination
- No silent failures that stop processing mid-list

**FR-002: OS-Specific Package Resolution**
- System MUST correctly resolve package names using platform-specific overrides
- Packages with `null` override for current OS MUST be skipped gracefully
- Cross-platform packages without overrides MUST use the default name

**FR-003: Idempotency**
- System MUST detect already-installed packages and skip reinstallation
- Running script multiple times MUST NOT cause errors or duplicate installations
- Second execution MUST display "already installed" status for all existing components

**FR-004: Backup Before Modification**
- System MUST backup existing dotfiles before overwriting with stow
- Backups MUST be timestamped with format `YYYY-MM-DD_HH-MM-SS`
- Backup directory structure MUST be stow-compatible for rollback capability

**FR-005: Error Handling & Recovery**
- System MUST continue on non-critical errors (e.g., optional package unavailable)
- System MUST stop on critical errors (e.g., package manager unavailable)
- Error messages MUST be actionable and guide user to resolution

**FR-006: Package Filtering**
- `--work` flag MUST include work packages (excluded by default)
- `--no-gui` flag MUST exclude GUI packages (included by default)
- Default behavior MUST install personal CLI and GUI packages

**FR-007: Dry-Run Accuracy**
- Dry-run mode MUST show accurate preview of all planned changes
- Dry-run mode MUST NOT make any system modifications
- Dry-run mode MUST leverage native package manager dry-run commands

**FR-008: Container Compatibility**
- System MUST work in containerized environments without TTY
- System MUST NOT require interactive user input
- Container tests MUST pass on both Fedora and Homebrew environments

---

### Non-Functional Requirements

**NFR-001: Performance**
- Full installation MUST complete in under 30 minutes on standard hardware
- Package processing MUST be sequential (reliable) not parallel (adds complexity)

**NFR-002: Reliability**
- Script MUST exit with code 0 on success
- Script MUST exit with non-zero code on failure
- Script MUST use strict error handling mode (`set -euo pipefail`)

**NFR-003: Usability**
- Terminal output MUST be readable and aesthetically pleasing (using gum)
- Progress indicators MUST show current step and operation
- Final summary MUST show counts of installed, skipped, and failed items

**NFR-004: Maintainability**
- Code MUST be modular with clear separation of concerns
- Package configuration MUST be in YAML, not hardcoded
- Adding new packages MUST require only editing packages.yaml

**NFR-005: Debuggability**
- Verbose mode MUST capture complete execution trace
- Debug log MUST include timestamps for all critical operations
- Error messages MUST include sufficient context for diagnosis

---

### Technical Constraints

**TC-001: Bash Version**
- Requires Bash 4.0 or later
- Note: macOS ships with Bash 3.2; Homebrew installs Bash 5.x
- Note: Fedora ships with Bash 5.x

**TC-002: Strict Error Handling**
- All scripts MUST use strict mode: `set -euo pipefail`
- Arithmetic operations MUST use assignment form: `count=$((count + 1))`
- Avoid increment form: `((count++))` as it returns exit code 1 when count=0

**TC-003: Loop Processing**
- Installation loops MUST use file descriptor 4 for input to prevent stdin consumption
- Pattern: `while read -u 4 var; do ... done 4<<< "$data"`
- Commands in loop body MUST redirect stdin: `command </dev/null`
- Package manager output MUST be suppressed in success case: `command &>/dev/null`

**TC-004: Non-Interactive Mode**
- All installations MUST be non-interactive
- Package managers: Use `-y` or `--assumeyes` flags
- Oh My Zsh: Set `RUNZSH=no` and `KEEP_ZSHRC=yes` environment variables
- Flatpak: Use `-y` and `--noninteractive` flags

**TC-005: Cross-Platform Compatibility**
- File paths MUST use portable formats
- Commands MUST check OS before execution
- Architecture detection MUST support Intel (x86_64) and ARM (arm64/aarch64)

---

## 7. Testing Requirements

### Automated Testing

**Test Environments:**
1. Fedora container: Native Linux with DNF and Flatpak
2. Homebrew container: Homebrew on Linux (macOS simulation)

### Test Scenarios

| Scenario | Command | Validation |
|----------|---------|------------|
| Default install | `./main.sh` | Personal CLI + GUI packages installed successfully |
| CLI only | `./main.sh --no-gui` | Personal CLI packages only, no GUI applications |
| With work packages | `./main.sh --work` | Personal + work packages (CLI + GUI) installed |
| Work CLI only | `./main.sh --work --no-gui` | Personal + work CLI packages only |
| Dry-run preview | `./main.sh --dry-run` | No system changes, accurate preview displayed |
| Idempotency | Run twice | Second run shows "already installed" for all items |
| Verbose logging | `./main.sh --verbose` | debug.log created with comprehensive execution trace |

### Validation Criteria

**1. Package Installation Completeness**
- All packages in filtered list are processed (not just first few)
- Validation: `grep -c 'Processing package' debug.log` matches expected count
- Expected: 25 CLI packages with `--no-gui`, 30+ total without

**2. Exit Code**
- Script completes successfully with exit code 0
- Validation: `echo $?` after execution
- Expected: 0 on success, non-zero on critical failure

**3. Container Tests**
- Fedora: DNF and Flatpak installations work correctly
- Homebrew: Brew installations work with `--force-brew` flag
- Validation: Container tests complete without errors

**4. Idempotency**
- Second run shows all items already installed
- No duplicate installations or errors
- Validation: Output contains "already installed" messages

---

### Manual Validation

After installation, verify the following:

**Package Managers:**
```bash
# macOS
brew --version

# Linux
dnf --version
flatpak --version
```

**Essential Tools:**
```bash
stow --version
gum --version
yq --version
asdf --version
```

**Runtime Versions:**
```bash
node --version
python --version
cargo --version
```

**Dotfiles Deployment:**
```bash
# Check for symlinks to dotfiles directory
ls -la ~/

# Verify backup exists
ls -la ~/.dotfiles-backup/
```

**Shell Configuration:**
```bash
# Verify Oh My Zsh installed
echo $ZSH

# Check default shell
echo $SHELL  # Should show /bin/zsh
```

---

## 8. Dependencies & Prerequisites

### Auto-Installed by Script

The following components are automatically installed if missing:

**Package Managers:**
- macOS: Homebrew (from https://brew.sh)
- Linux: DNF (pre-installed on Fedora), Flatpak (enabled if missing)

**Essential Tools:**
- GNU Stow (for dotfiles symlinking)
- gum (for beautiful terminal UI)
- yq v4 (for YAML parsing)
- asdf v0.17.0 (for runtime version management)

**Fedora COPR Repositories:**
- `atim/lazygit`
- `che/nerd-fonts`
- `atim/starship`
- `scottames/ghostty`
- `lihaohong/yazi`

---

### Required by User

**System Requirements:**
- Bash 4.0 or later
- Git (for Oh My Zsh, LazyVim, asdf plugin management)
- curl or wget (for downloading installers)
- Internet connection
- sudo access (Linux only, for DNF installations)

**Optional Components:**
- Neovim (required for LazyVim configuration)
- Visual Studio Code (required for extension installation)
- zsh shell (auto-installed if missing for Oh My Zsh)

---

### External Services

**GitHub:**
- asdf pre-built binaries: `github.com/asdf-vm/asdf/releases`
- LazyVim starter: `github.com/LazyVim/starter`
- Oh My Zsh: `github.com/ohmyzsh/ohmyzsh`

**Package Repositories:**
- Homebrew: `brew.sh`
- Flathub: `flathub.org`
- Fedora COPR: `copr.fedorainfracloud.org`
- PyPI: `pypi.org`
- npm: `npmjs.com`
- crates.io: `crates.io`

---

## 9. Out of Scope

The following features are explicitly excluded from v1.0:

### Not Supported

- ❌ Encrypted secrets management (1Password CLI configuration, age, sops)
- ❌ Remote dotfiles repository cloning (git-based dotfiles syncing)
- ❌ Interactive TUI for package selection (gum choose interface)
- ❌ Linux distributions beyond Fedora (Ubuntu, Arch, Debian)
- ❌ Windows support (WSL or native)
- ❌ System-level configurations outside `$HOME`
- ❌ User account creation or system user management
- ❌ Automated SSH key generation (requires user passphrase)
- ❌ Application login automation (cloud services, 1Password)
- ❌ Git configuration (name, email, signing key setup)

### Future Consideration

The following may be considered for future versions:

- 🔮 Support for Ubuntu and Arch Linux
- 🔮 Remote dotfiles repository cloning and syncing
- 🔮 Interactive package selection TUI
- 🔮 Secrets management integration
- 🔮 Automated SSH key generation with ssh-agent
- 🔮 Git configuration automation from template

### Explicitly Deferred

The following are outside the project scope:

- Desktop environment customization (GNOME, KDE tweaks)
- Window manager configurations (i3, sway, Hyprland)
- Theme management (GTK themes, Qt themes)
- Font rendering and subpixel configuration
- Power management and laptop-specific settings

---

## 10. Manual Steps Required

After running the bootstrap script successfully, the user must complete these manual steps:

### 1. asdf PATH Configuration

Add asdf to your shell configuration file:

```bash
# For zsh users (~/.zshrc)
echo 'export PATH="$HOME/.asdf/bin:$PATH"' >> ~/.zshrc

# For bash users (~/.bashrc)
echo 'export PATH="$HOME/.asdf/bin:$PATH"' >> ~/.bashrc
```

Restart your shell or source the configuration:
```bash
source ~/.zshrc  # or source ~/.bashrc
```

---

### 2. SSH Key Generation

Generate an SSH key for Git operations:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

Add the public key to GitHub/GitLab:
```bash
cat ~/.ssh/id_ed25519.pub
# Copy output and add to GitHub Settings → SSH Keys
```

---

### 3. Application Logins

Log in to installed applications that require authentication:
- 1Password
- Raycast (macOS)
- Cloud services (AWS CLI, GCP CLI, etc.)
- Spotify

---

### 4. Git Configuration

Configure Git with your personal information:

```bash
git config --global user.name "Your Name"
git config --global user.email "your_email@example.com"

# Optional: Enable GPG signing
git config --global commit.gpgsign true
git config --global user.signingkey <your-gpg-key-id>
```

---

### 5. Verify Installation

Run these commands to confirm the bootstrap was successful:

```bash
# Check shell
echo $SHELL                    # Should show /bin/zsh

# Check asdf
asdf --version                 # Should show v0.17.0

# Check runtimes
node --version                 # Should show installed Node.js version
python --version               # Should show installed Python version
cargo --version                # Should show installed Rust version

# Check dotfiles symlinks
ls -la ~/                      # Should show symlinks to dotfiles/ directory

# Check Oh My Zsh
echo $ZSH                      # Should show ~/.oh-my-zsh
```

---

## 11. Appendix

### Package Count Summary

| Category | macOS | Linux | Total |
|----------|-------|-------|-------|
| Personal CLI | 25 | 25 | 25 |
| Personal GUI | 5 | 4 | 9 |
| Work CLI | 4 | 4 | 4 |
| Work GUI | 1 | 0 | 1 |
| **Total** | **35** | **33** | **39** |

### Runtime Packages

| Category | Count | Examples |
|----------|-------|----------|
| npm | 2 | @anthropics/claude-code, @fresh-editor/fresh-editor |
| pip | 1 | jrnl |
| cargo | 4 | cargo-watch, cargo-nextest, cargo-expand, cargo-udeps |
| bun | 0 | (none configured) |
| uv_tools | 1 | specify-cli |
| VSCode Extensions | 30 | Python, Go, Rust, Docker, GitHub Actions, etc. |

### Execution Flow

1. **Parse Arguments:** Process CLI flags and set global variables
2. **Prerequisites:** Install package managers and essential tools
3. **Oh My Zsh:** Install and configure zsh shell framework
4. **Packages:** Install system packages (CLI and GUI)
5. **asdf:** Setup runtime environments and global packages
6. **VSCode:** Install editor extensions
7. **LazyVim:** Configure Neovim with LazyVim distribution
8. **Stow:** Backup and symlink dotfiles
9. **Manual Steps:** Display remaining tasks for user

---

**End of Document**
