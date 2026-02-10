#!/usr/bin/env bash
# utils.sh - Shared utility functions for dotfiles bootstrap
# Provides logging, error handling, and OS detection

set -euo pipefail

# Mark that utils has been sourced (used by other scripts to avoid double-sourcing)
UTILS_SOURCED=true

# =============================================================================
# CONSTANTS
# =============================================================================

readonly DOTFILES_BACKUP_DIR="$HOME/.dotfiles-backup"
readonly UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$UTILS_SCRIPT_DIR")"
readonly DOTFILES_DIR="$PROJECT_DIR/dotfiles"
readonly PACKAGES_YAML="$PROJECT_DIR/packages.yaml"

# =============================================================================
# GLOBAL STATE
# =============================================================================

DRY_RUN=false
INCLUDE_WORK=false
SKIP_PACKAGES=false
SKIP_STOW=false
GUM_AVAILABLE=false
FORCE_BREW=false  # Force using Homebrew even on Linux (for container testing)
FORCE_STOW=false  # Force stow to adopt existing files (uses --adopt)
VERBOSE=false     # Enable verbose/debug logging

# Timestamp for this run (used for backups)
RUN_TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"

# Debug log file descriptor (set up in init_debug_logging)
DEBUG_FD=3

# =============================================================================
# OS DETECTION
# =============================================================================

detect_os() {
    local os=""
    case "$(uname -s)" in
        Darwin)
            os="macos"
            ;;
        Linux)
            # Detect specific distros
            if command -v dnf &>/dev/null; then
                os="linux-fedora"
            else
                os="linux"  # Generic Linux (non-Fedora)
            fi
            ;;
        *)
            os="unknown"
            ;;
    esac
    echo "$os"
}

# Cached OS value
DETECTED_OS=""

get_os() {
    # If FORCE_BREW is set on Linux, pretend we're on macOS for package routing
    if [[ "$FORCE_BREW" == true ]] && [[ "$(uname -s)" == "Linux" ]]; then
        echo "macos"
        return
    fi
    
    if [[ -z "$DETECTED_OS" ]]; then
        DETECTED_OS="$(detect_os)"
    fi
    echo "$DETECTED_OS"
}

is_macos() {
    [[ "$(get_os)" == "macos" ]]
}

is_linux() {
    [[ "$(get_os)" == linux* ]]
}

is_fedora() {
    [[ "$(get_os)" == "linux-fedora" ]]
}

is_generic_linux() {
    [[ "$(get_os)" == "linux" ]]
}

# Show warning for non-Fedora Linux systems
warn_non_fedora_linux() {
    if is_generic_linux; then
        log_warning "Non-Fedora Linux detected"
        log_info "Native package installation only supports Fedora (DNF)"
        log_info "Options:"
        log_info "  1. Use --force-brew flag: ./main.sh --force-brew"
        log_info "     (Installs packages via Homebrew on Linux)"
        log_info "  2. Install packages manually for your distribution"
        echo ""
    fi
}

# =============================================================================
# CONTAINER DETECTION
# =============================================================================

# Check if running inside a container (Docker, Podman, etc.)
is_container() {
    # Check for .dockerenv file (Docker)
    [[ -f /.dockerenv ]] && return 0
    
    # Check for container environment variable (Podman, etc.)
    [[ -n "${container:-}" ]] && return 0
    
    # Check cgroup for docker/lxc/podman
    if [[ -f /proc/1/cgroup ]]; then
        grep -qE '(docker|lxc|podman|containerd)' /proc/1/cgroup 2>/dev/null && return 0
    fi
    
    # Check for Kubernetes
    [[ -n "${KUBERNETES_SERVICE_HOST:-}" ]] && return 0
    
    return 1
}

# =============================================================================
# LOGGING (with gum fallback)
# =============================================================================

# Check if gum is available and set flag
check_gum() {
    if command -v gum &>/dev/null; then
        GUM_AVAILABLE=true
    else
        GUM_AVAILABLE=false
    fi
}

# Initialize gum check
check_gum

# Print a styled header/section
log_header() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --bold --foreground 212 "$message"
    else
        echo ""
        echo "=== $message ==="
        echo ""
    fi
}

# Print an info message
log_info() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --foreground 39 "  $message"
    else
        echo "  $message"
    fi
}

# Print a success message with checkmark
log_success() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --foreground 82 "  ✓ $message"
    else
        echo "  ✓ $message"
    fi
}

# Print a warning message
log_warning() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --foreground 214 "  ⚠ $message"
    else
        echo "  ⚠ WARNING: $message"
    fi
}

# Print an error message
log_error() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --foreground 196 --bold "  ✗ ERROR: $message"
    else
        echo "  ✗ ERROR: $message" >&2
    fi
}

# Print a step being executed (with optional spinner in real mode)
log_step() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --foreground 75 "→ $message"
    else
        echo "→ $message"
    fi
}

# Print dry-run specific message
log_dry_run() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        gum style --foreground 99 --italic "  [DRY-RUN] $message"
    else
        echo "  [DRY-RUN] $message"
    fi
}

# =============================================================================
# DEBUG/VERBOSE LOGGING
# =============================================================================

# Initialize debug logging
# Sets up file descriptor 3 to either /dev/null (quiet) or debug.log (verbose)
init_debug_logging() {
    if [[ "$VERBOSE" == true ]]; then
        local debug_log="$PROJECT_DIR/debug.log"
        # Create/truncate debug log file
        : > "$debug_log"
        # Open FD 3 for writing to debug.log
        exec 3>>"$debug_log"
        log_info "Verbose mode enabled - debug output: $debug_log"
        log_debug "Debug logging initialized at $(date)"
        log_debug "OS: $(uname -s) $(uname -r)"
        log_debug "Working directory: $PROJECT_DIR"
    else
        # Redirect FD 3 to /dev/null (discard all debug output)
        exec 3>/dev/null
    fi
}

# Log debug message (only visible in verbose mode)
# Usage: log_debug "Processing package: $name"
log_debug() {
    local message="$1"
    # Write to FD 3 (either debug.log or /dev/null)
    echo "[DEBUG $(date +%H:%M:%S)] $message" >&3
}

# Run command with debug output capture
# Usage: run_with_debug "dnf install package" command args...
run_with_debug() {
    local description="$1"
    shift
    
    log_debug "Running: $*"
    
    if [[ "$VERBOSE" == true ]]; then
        # In verbose mode, capture both stdout and stderr to debug log
        # but also show output to user
        "$@" 2>&1 | tee -a /dev/fd/3
        local exit_code=${PIPESTATUS[0]}
        log_debug "Command exited with code: $exit_code"
        return $exit_code
    else
        # In quiet mode, just run the command normally
        "$@"
    fi
}

# Print a boxed message (for manual steps, summaries)
log_box() {
    local message="$1"
    if [[ "$GUM_AVAILABLE" == true ]]; then
        echo "$message" | gum style --border rounded --padding "1 2" --border-foreground 212
    else
        echo ""
        echo "┌────────────────────────────────────────────────┐"
        echo "$message" | while IFS= read -r line; do
            printf "│ %-46s │\n" "$line"
        done
        echo "└────────────────────────────────────────────────┘"
        echo ""
    fi
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

# Exit with error message
die() {
    local message="$1"
    local suggestion="${2:-}"
    
    log_error "$message"
    
    if [[ -n "$suggestion" ]]; then
        echo ""
        if [[ "$GUM_AVAILABLE" == true ]]; then
            gum style --foreground 245 "  Suggested fix: $suggestion"
        else
            echo "  Suggested fix: $suggestion"
        fi
    fi
    
    exit 1
}

# Run a command and handle errors
run_cmd() {
    local description="$1"
    shift
    local cmd=("$@")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would run: ${cmd[*]}"
        return 0
    fi
    
    log_step "$description"
    
    local output
    local exit_code=0
    
    if output=$("${cmd[@]}" 2>&1); then
        log_success "$description"
    else
        exit_code=$?
        log_error "$description failed (exit code: $exit_code)"
        echo ""
        echo "Command: ${cmd[*]}"
        echo "Output:"
        echo "$output"
        return $exit_code
    fi
}

# Run a command with a spinner (gum spin)
run_with_spinner() {
    local title="$1"
    shift
    local cmd=("$@")
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would run: ${cmd[*]}"
        return 0
    fi
    
    if [[ "$GUM_AVAILABLE" == true ]]; then
        if gum spin --spinner dot --title "$title" -- "${cmd[@]}"; then
            log_success "$title"
        else
            local exit_code=$?
            log_error "$title failed"
            return $exit_code
        fi
    else
        log_step "$title"
        if "${cmd[@]}"; then
            log_success "$title"
        else
            local exit_code=$?
            log_error "$title failed"
            return $exit_code
        fi
    fi
}

# =============================================================================
# COMMAND CHECKS
# =============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if a brew formula is installed
brew_formula_installed() {
    local formula="$1"
    brew list --formula "$formula" &>/dev/null
}

# Check if a brew cask is installed
brew_cask_installed() {
    local cask="$1"
    brew list --cask "$cask" &>/dev/null
}

# =============================================================================
# ARGUMENT PARSING HELPERS
# =============================================================================

show_help() {
    cat << EOF
Usage: ./main.sh [OPTIONS]

Dotfiles bootstrap - Setup development environment

Options:
    --work              Include work packages (excluded by default)
    --skip-packages     Skip package installation and LazyVim (only run stow/asdf)
    --skip-stow         Skip stow, only install packages
    --dry-run           Preview changes without applying them
    --verbose, -v       Enable verbose debug logging to debug.log
    --force             Force stow to adopt existing files (uses --adopt)
    --force-brew        Force using Homebrew on Linux (for container testing)
    --help              Show this help message

Examples:
    ./main.sh                          # Standard personal setup (CLI + GUI)
    ./main.sh --work                   # Include work packages
    ./main.sh --skip-packages          # Only symlink dotfiles
    ./main.sh --dry-run                # Preview what would happen
    ./main.sh --verbose                # Run with debug logging enabled
    ./main.sh --force                  # Force override existing dotfiles
    ./main.sh --force-brew             # Force Homebrew usage on Linux (for testing)
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --work)
                INCLUDE_WORK=true
                shift
                ;;
            --skip-packages)
                SKIP_PACKAGES=true
                shift
                ;;
            --skip-stow)
                SKIP_STOW=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE_STOW=true
                shift
                ;;
            --force-brew)
                FORCE_BREW=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1" "Run with --help for usage information"
                ;;
        esac
    done
    
    # Initialize debug logging after parsing args
    init_debug_logging
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Create backup directory for this run
get_backup_dir() {
    echo "$DOTFILES_BACKUP_DIR/$RUN_TIMESTAMP"
}

# Ensure a directory exists
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
    fi
}
