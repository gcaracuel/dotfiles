# dotfiles

A simple tool to quickly setup my development environment on a new machine or after a fresh OS installation.

## Repository Overview

**Project:** Dotfiles Bootstrap Tool  
**Language:** Bash  
**Purpose:** Automate development environment setup on new machines

### Tech Stack
- **Language:** Bash 4+ (macOS/Linux compatible)
- **Style:** `set -euo pipefail` (strict error handling, no undefined variables)
- **Output:** [gum](https://github.com/charmbracelet/gum) for beautiful terminal UI
- **Config:** YAML (parsed with `yq`)
- **Dotfiles:** GNU Stow (symlink management)
- **Package Managers:** Homebrew (macOS), DNF (Fedora), Flatpak (Linux GUI)
- **Testing:** Docker devcontainers with justfile orchestration

### Code Style
- Shellcheck-compliant Bash
- Functions defined before usage
- Clear, descriptive variable names (`SCREAMING_SNAKE_CASE` for constants)
- Comments explain "why", not "what"
- Error messages include suggestions for resolution
- Idempotent operations (safe to run multiple times)

---

## Critical Rules for Agents

### 1. Always Run Tests After Changes

**MANDATORY:** After modifying any script, run devcontainer tests to verify nothing broke.

```bash
# Run interactive test selection
just test

# Or run both explicitly
just test-fedora
just test-brew
```

**Why:** The script runs on multiple OSes with different package managers. A change that works on macOS might break on Linux and vice versa.

**When to skip:** Only for documentation-only changes (README, PRD, etc.)

**CRITICAL:** 
- **NEVER run commands directly on the host machine** for testing or verification
- **ALWAYS use devcontainers** via `just test-fedora` or `just test-brew`
- **DO NOT use `docker run` commands** that execute against the host filesystem
- The devcontainers provide isolated, reproducible test environments

**Example - BAD (runs on host):**
```bash
./main.sh --dry-run  # Runs on your actual machine!
```

**Example - GOOD (runs in container):**
```bash
just test-fedora     # Runs in isolated Fedora container
just test-brew       # Runs in isolated Homebrew container
```

---

### 2. Maintain Idempotency

All operations must be safe to run multiple times:
- Check if package is installed before installing
- Check if file exists before copying/linking
- Check if plugin is added before adding
- Use `|| true` to handle expected failures gracefully

**Bad:**
```bash
brew install git
```

**Good:**
```bash
if ! brew list git &>/dev/null; then
    brew install git
fi
```

---

### 3. Respect Dry-Run Mode

Every new feature must respect the `--dry-run` flag:
- Check `if [[ "$DRY_RUN" == true ]]; then`
- Log what *would* happen with `log_dry_run`
- Never modify system state in dry-run mode
- Package manager checks are OK (they're read-only)

---

### 4. Use Utility Functions

Don't reinvent the wheel - use existing utilities from `scripts/utils.sh`:

**Logging:**
- `log_header` - Section headers
- `log_info` - Informational messages
- `log_success` - Success with checkmark
- `log_warning` - Warnings (yellow)
- `log_error` - Errors (red)
- `log_step` - Action being performed
- `log_dry_run` - Dry-run preview
- `log_box` - Boxed message (for summaries)

**Utilities:**
- `get_os()` - Get detected (or forced) OS
- `is_macos()`, `is_linux()`, `is_fedora()`, `is_generic_linux()` - OS checks
- `command_exists()` - Check if command is in PATH
- `ensure_dir()` - Create directory if missing
- `die()` - Exit with error message

---

### 5. Follow the Established Patterns

Each script follows a consistent structure:

```bash
#!/usr/bin/env bash
# script-name.sh - Brief description
# Additional context or behavior notes

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

# Constants and configuration arrays at the top
CONSTANT_NAME="value"
ARRAY_NAME=(
    "item1"
    "item2"
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

helper_function() {
    # Implementation
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main_function() {
    log_header "Doing Something"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would do something"
        return 0
    fi
    
    # Actual work here
    log_success "Something complete"
}

# =============================================================================
# DRY-RUN CHECK
# =============================================================================

check_something_dry_run() {
    log_header "SOMETHING"
    
    # Show what would happen
    log_dry_run "Would perform actions..."
}
```

### Important Configuration Variables

#### asdf Version Pinning

In `scripts/prerequisites.sh`, the asdf version is controlled by a top-level constant:

```bash
ASDF_VERSION="v0.17.0"  # Pin to specific version
# OR
ASDF_VERSION="latest"    # Always fetch latest release
```

**Note**: Pre-built binaries are only available from v0.15.0 onwards. If you specify an older version, the download will fail.

The script automatically:
- Detects system architecture (darwin/linux, amd64/arm64)
- Downloads pre-built binaries from GitHub releases
- Installs to `~/.asdf/`
- Temporarily adds to PATH during script execution
- Reminds user to add to shell config permanently

**PATH Management Pattern:**
asdf is added to PATH temporarily during bootstrap, but users must manually add it to their shell config. The script prints a reminder at the end.

#### Python Build Dependencies

In `scripts/asdf.sh`, Python installations require build dependencies (especially OpenSSL):

**Automatic Handling:**
- `ensure_python_build_deps()` - Installs OpenSSL and build tools before Python installation
- `get_python_build_env()` - Sets CFLAGS/LDFLAGS to help Python find OpenSSL
- Called automatically when Python is detected in `.tool-versions`

**Platform-specific dependencies:**
- **macOS/Homebrew**: `openssl@3` (with CFLAGS pointing to Homebrew's OpenSSL)
- **Fedora**: `openssl-devel bzip2-devel libffi-devel readline-devel sqlite-devel zlib-devel`
- **Other Linux**: Shows manual installation instructions for Debian/Arch

**Error Handling:**
- If Python build fails with SSL errors, provides platform-specific fix suggestions
- Non-fatal - user can install deps manually and re-run

---

### 6. Update Documentation

When adding features, update:
1. **README.md** - User-facing documentation
2. **dev/PRD.md** - Technical specification (mark completed when done)
3. **This file (AGENTS.md)** - If adding new patterns or rules
4. **packages.yaml comments** - If changing package structure

---

### 7. Handle Errors Gracefully

- Use `set -euo pipefail` at script start
- Provide actionable error messages
- Use `die()` for fatal errors with suggestions
- Use `log_warning` for non-fatal issues
- Avoid cryptic error codes
- **Show error context when package installations fail**

**Bad:**
```bash
npm install -g foo || exit 1
```

**Bad (suppresses error details):**
```bash
if ! npm install -g foo &>/dev/null; then
    log_warning "Failed to install foo"
fi
```

**Good:**
```bash
if ! npm install -g foo; then
    die "Failed to install npm package 'foo'" \
        "Check your network connection and npm configuration"
fi
```

**Best (for non-fatal package installations):**
```bash
local error_output
if error_output=$(npm install -g "$package" 2>&1); then
    log_success "$package installed"
else
    log_warning "Failed to install $package"
    # Show first 3 lines of error for context
    local error_preview
    error_preview=$(echo "$error_output" | head -3 | sed 's/^/  /')
    echo "$error_preview" >&2
fi
```

**Why show error context:**
- Users need to understand WHY a package failed to install
- Network issues, missing dependencies, version conflicts, etc.
- First few lines usually contain the most relevant error information
- Helps users troubleshoot without needing --verbose flag

---

### 8. Counter Arithmetic Safety

**Critical:** Bash arithmetic with `((i++))` returns exit code 1 when value is 0, causing scripts to fail with `set -e`.

**Bad:**
```bash
count=0
((count++))  # Returns 1, script exits!
```

**Good:**
```bash
count=0
count=$((count + 1))  # Always returns 0
```

---

## Testing Workflow

### Local Development
```bash
# 1. Make changes to scripts
# Use Read, Edit, Write tools to modify files

# 2. ALWAYS test in containers (NEVER on host)
just test
# Select option 1 (Fedora) or 2 (Homebrew)

# 3. If issues found, debug in container
just test-fedora-debug
# Container stays alive for inspection

# 4. For interactive debugging, use shell target
just test-fedora-shell
# Manually run commands inside container

# 5. Clean up
just clean
```

**IMPORTANT:** Never run `./main.sh` directly on the host machine for testing. Always use containers.

### What Each Test Validates

**`just test-fedora`:**
- DNF package installation
- Flatpak GUI apps
- asdf with Linux paths
- npm/pip packages
- Dotfiles stowing

**`just test-brew`:**
- Homebrew formula installation on Linux
- `--force-brew` flag works correctly
- Tests Homebrew as the primary package manager (simulates macOS environment)
- asdf with Homebrew paths
- npm/pip packages

### Manual Validation After Automated Tests

After the automated bootstrap completes successfully, it's recommended to manually validate the environment interactively:

```bash
# 1. Start an interactive debug shell
just test-fedora-debug
# OR
just test-brew-debug

# 2. Inside the container, switch to zsh (if installed)
zsh

# If zsh loads without errors, the dotfiles are properly configured!
# Any errors during zsh startup indicate dotfile configuration issues.

# 3. Test that aliases and tools work correctly:

# Test eza (aliased as ls in zshrc)
ls

# Test bat (syntax-highlighted file viewer)
bat README.md

# Test htop (interactive process viewer)
htop
# Press 'q' to quit

# 4. Test other commonly used commands from your dotfiles
# If all commands work without errors, validation is complete!
```

**Why this matters:**
- Loading zsh validates `.zshrc`, `.zshenv`, and all shell configurations
- Testing aliased commands confirms the tools are properly installed and in PATH
- Interactive validation catches issues that automated tests might miss

---

## Common Pitfalls

### 1. Hardcoded Paths
```bash
# Bad
cd ~/Projects/dotfiles

# Good
cd "$PROJECT_DIR"
```

### 2. Unquoted Variables
```bash
# Bad - breaks with spaces
cp $file $dest

# Good
cp "$file" "$dest"
```

### 3. Assuming OS
```bash
# Bad
brew install git

# Good
if is_macos; then
    brew install git
elif is_fedora; then
    sudo dnf install -y git
fi
```

### 4. Not Handling Missing Files
```bash
# Bad
source ~/.zshrc

# Good
if [[ -f ~/.zshrc ]]; then
    source ~/.zshrc
fi
```

---

## File Organization

```
dotfiles/
├── main.sh                 # Entry point - orchestrates everything
├── packages.yaml           # Package definitions (user-editable)
├── justfile               # Container testing
├── AGENTS.md              # This file
├── README.md              # User documentation
├── scripts/               # Modular implementation
│   ├── utils.sh           # Shared utilities (source this first!)
│   ├── prerequisites.sh   # Auto-install Homebrew, gum, yq, stow
│   ├── packages.sh        # Parse YAML, install packages
│   ├── stow.sh            # Backup and stow dotfiles
│   ├── asdf.sh            # Language runtime management
│   └── lazyvim.sh         # Neovim configuration
├── dev/                   # Development documentation
│   ├── PRD.md             # Product requirements (technical spec)
│   └── ROADMAP.md         # Future features and ideas
├── .devcontainer/         # Container testing
│   ├── fedora/
│   └── homebrew/
└── dotfiles/              # User's dotfiles (mirrors $HOME)
```

---

## Quick Reference

### Add a New Package
1. Edit `packages.yaml`
2. Add to appropriate section (OS -> category -> type)
3. Test in containers: `just test`

### Add a New Script
1. Create `scripts/new-feature.sh`
2. Follow structure pattern (see section 5)
3. Source `utils.sh` at the top
4. Implement main function + dry-run check
5. Integrate into `main.sh`
6. Update `README.md` with user-facing docs
7. Update `dev/PRD.md` with technical details
8. Test in containers: `just test`

### Add a New CLI Flag
1. Update `parse_args()` in `scripts/utils.sh`
2. Add global variable at top of `utils.sh`
3. Update `show_help()` with documentation
4. Handle flag in relevant scripts
5. Update `README.md` options table
6. Test in containers: `just test`

---

## Questions or Improvements?

This is a living document. If you notice patterns that should be documented or rules that should be added, update this file as part of your changes.

**Remember:** The goal is to make the codebase maintainable, testable, and easy to understand for both humans and AI agents.
