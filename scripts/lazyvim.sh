#!/usr/bin/env bash
# lazyvim.sh - Install and configure LazyVim for Neovim
# Follows official installation guide: https://www.lazyvim.org/installation
# Idempotent: safe to run multiple times

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    LAZYVIM_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$LAZYVIM_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly NVIM_CONFIG_DIR="$HOME/.config/nvim"
readonly LAZYVIM_STARTER_REPO="https://github.com/LazyVim/starter"
readonly LAZYVIM_SIGNATURE_FILE="$NVIM_CONFIG_DIR/lua/config/lazy.lua"

# =============================================================================
# DETECTION FUNCTIONS
# =============================================================================

# Check if neovim is installed
is_neovim_installed() {
    command -v nvim &>/dev/null
}

# Check if LazyVim is already installed
# Looks for the signature file and checks for "lazyvim" string
is_lazyvim_installed() {
    if [[ ! -f "$LAZYVIM_SIGNATURE_FILE" ]]; then
        return 1
    fi
    
    # Check if file contains "lazyvim" (case-insensitive)
    grep -qi "lazyvim" "$LAZYVIM_SIGNATURE_FILE" 2>/dev/null
}

# Check if any nvim config exists (but is not LazyVim)
has_existing_nvim_config() {
    [[ -d "$NVIM_CONFIG_DIR" ]] && ! is_lazyvim_installed
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

# Backup existing nvim config
backup_nvim_config() {
    if [[ ! -d "$NVIM_CONFIG_DIR" ]]; then
        return 0
    fi
    
    local backup_dir
    backup_dir="$(get_backup_dir)/nvim"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would backup $NVIM_CONFIG_DIR to $backup_dir"
        return 0
    fi
    
    log_step "Backing up existing nvim config"
    ensure_dir "$(dirname "$backup_dir")"
    
    if mv "$NVIM_CONFIG_DIR" "$backup_dir"; then
        log_success "Backed up nvim config to $backup_dir"
    else
        log_warning "Failed to backup nvim config"
        return 1
    fi
}

# =============================================================================
# INSTALLATION
# =============================================================================

# Install LazyVim starter
install_lazyvim() {
    log_header "Setting up LazyVim"
    
    # Check if neovim is installed
    if ! is_neovim_installed; then
        log_warning "Neovim is not installed - skipping LazyVim setup"
        log_info "Install neovim first, then run this script again"
        return 0
    fi
    
    # Check if LazyVim is already installed
    if is_lazyvim_installed; then
        log_success "LazyVim is already installed"
        return 0
    fi
    
    # Backup existing config if present
    if has_existing_nvim_config; then
        log_info "Found existing nvim config (not LazyVim)"
        backup_nvim_config || return 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would clone LazyVim starter to $NVIM_CONFIG_DIR"
        log_dry_run "Would remove .git folder from $NVIM_CONFIG_DIR"
        return 0
    fi
    
    # Clone LazyVim starter
    log_step "Cloning LazyVim starter"
    
    # Configure git to avoid interactive prompts and force HTTPS
    # In containers, we may not have SSH keys configured
    export GIT_TERMINAL_PROMPT=0  # Disable git credential prompts
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new"  # Auto-accept SSH keys if SSH is used
    
    # Temporarily disable git SSH URL rewriting (some systems rewrite https:// to git@)
    # Save original config, set to empty, then restore after clone
    local git_ssh_config
    git_ssh_config=$(git config --global --get url."git@github.com:".insteadOf 2>/dev/null || echo "")
    
    # Disable any SSH URL rewriting for this operation
    git config --global --unset url."git@github.com:".insteadOf 2>/dev/null || true
    git config --global --unset url."ssh://git@github.com/".insteadOf 2>/dev/null || true
    
    # Clone using HTTPS
    local clone_result=0
    if ! git clone --depth 1 "$LAZYVIM_STARTER_REPO" "$NVIM_CONFIG_DIR" 2>&1; then
        clone_result=1
    fi
    
    # Restore original git config if it existed
    if [[ -n "$git_ssh_config" ]]; then
        git config --global url."git@github.com:".insteadOf "$git_ssh_config"
    fi
    
    # Check clone result
    if [[ $clone_result -ne 0 ]]; then
        log_error "Failed to clone LazyVim starter"
        return 1
    fi
    
    # Remove .git folder (per official instructions)
    log_step "Removing .git folder"
    rm -rf "$NVIM_CONFIG_DIR/.git"
    
    log_success "LazyVim installed successfully"
    echo ""
    log_info "Next steps:"
    log_info "  1. Run 'nvim' to complete plugin installation"
    log_info "  2. Run ':LazyHealth' inside nvim to verify setup"
}

# =============================================================================
# DRY-RUN CHECK
# =============================================================================

check_lazyvim_dry_run() {
    log_header "LAZYVIM"
    
    if ! is_neovim_installed; then
        log_warning "Neovim not installed - LazyVim setup will be skipped"
        return 0
    fi
    
    if is_lazyvim_installed; then
        log_success "LazyVim (already installed)"
        return 0
    fi
    
    if has_existing_nvim_config; then
        log_info "Existing nvim config found (not LazyVim)"
        log_dry_run "Would backup to $(get_backup_dir)/nvim"
    fi
    
    log_dry_run "Would install LazyVim from $LAZYVIM_STARTER_REPO"
}
