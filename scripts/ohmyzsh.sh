#!/usr/bin/env bash
# ohmyzsh.sh - Install Oh My Zsh and set zsh as default shell
# Installs Oh My Zsh framework and configures zsh as the default shell

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    OHMYZSH_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$OHMYZSH_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# CONFIGURATION
# =============================================================================

OH_MY_ZSH_DIR="${HOME}/.oh-my-zsh"
OH_MY_ZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Check if Oh My Zsh is installed
is_ohmyzsh_installed() {
    [[ -d "$OH_MY_ZSH_DIR" ]]
}

# Check if zsh is the default shell
is_zsh_default_shell() {
    [[ "$SHELL" == */zsh ]]
}

# Get the path to zsh binary
get_zsh_path() {
    if command_exists zsh; then
        command -v zsh
    else
        echo ""
    fi
}

# =============================================================================
# ZSH INSTALLATION
# =============================================================================

# Ensure zsh is installed
ensure_zsh_installed() {
    if command_exists zsh; then
        log_success "zsh already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install zsh"
        return 0
    fi
    
    log_step "Installing zsh..."
    
    if is_macos; then
        # zsh comes pre-installed on modern macOS
        if command_exists brew; then
            brew install zsh || {
                die "Failed to install zsh" \
                    "Try: brew install zsh"
            }
        else
            die "zsh not found and Homebrew not available" \
                "Install Homebrew first: https://brew.sh"
        fi
    elif is_fedora; then
        sudo dnf install -y zsh || {
            die "Failed to install zsh" \
                "Try: sudo dnf install zsh"
        }
    elif is_generic_linux; then
        warn_non_fedora_linux
        die "zsh not installed on non-Fedora Linux" \
            "Install zsh manually or use --force-brew flag to use Homebrew"
    else
        die "Unsupported OS for zsh installation"
    fi
    
    log_success "zsh installed"
}

# =============================================================================
# OH MY ZSH INSTALLATION
# =============================================================================

install_ohmyzsh() {
    # Check if already installed
    if is_ohmyzsh_installed; then
        log_success "Oh My Zsh already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would install Oh My Zsh from: $OH_MY_ZSH_INSTALL_URL"
        return 0
    fi
    
    log_step "Installing Oh My Zsh..."
    
    # Install Oh My Zsh non-interactively
    # RUNZSH=no prevents it from launching zsh immediately
    # KEEP_ZSHRC=yes preserves existing .zshrc (important for dotfiles)
    if RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)" "" --unattended; then
        log_success "Oh My Zsh installed"
    else
        die "Failed to install Oh My Zsh" \
            "Try running manually: sh -c \"\$(curl -fsSL $OH_MY_ZSH_INSTALL_URL)\""
    fi
}

# =============================================================================
# DEFAULT SHELL CONFIGURATION
# =============================================================================

set_zsh_as_default() {
    local zsh_path
    zsh_path=$(get_zsh_path)
    
    if [[ -z "$zsh_path" ]]; then
        log_warning "zsh not found - cannot set as default shell"
        return 1
    fi
    
    # Check if already default
    if is_zsh_default_shell; then
        log_success "zsh is already the default shell"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_dry_run "Would set zsh ($zsh_path) as default shell"
        return 0
    fi
    
    log_step "Setting zsh as default shell..."
    
    # Ensure zsh is in /etc/shells
    if ! grep -q "^${zsh_path}$" /etc/shells 2>/dev/null; then
        log_step "Adding zsh to /etc/shells..."
        echo "$zsh_path" | sudo tee -a /etc/shells > /dev/null || {
            log_warning "Failed to add zsh to /etc/shells"
        }
    fi
    
    # Change default shell
    # Use sudo in containers to avoid password prompt
    if is_container; then
        # Get current user (USER may not be set in containers)
        local current_user="${USER:-$(whoami)}"
        if sudo chsh -s "$zsh_path" "$current_user"; then
            log_success "zsh set as default shell (restart terminal to apply)"
        else
            log_warning "Failed to set zsh as default shell"
        fi
    else
        if chsh -s "$zsh_path"; then
            log_success "zsh set as default shell (restart terminal to apply)"
        else
            log_warning "Failed to set zsh as default shell"
        fi
    fi
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

setup_ohmyzsh() {
    log_header "Oh My Zsh Setup"
    
    # Step 1: Ensure zsh is installed
    ensure_zsh_installed
    
    # Step 2: Install Oh My Zsh
    install_ohmyzsh
    
    # Step 3: Set zsh as default shell
    set_zsh_as_default
    
    echo ""
    log_success "Oh My Zsh setup complete"
    
    # Reminder about shell restart
    if ! is_zsh_default_shell && [[ "$DRY_RUN" == false ]]; then
        log_info "Note: Restart your terminal to use zsh as default shell"
    fi
}

# =============================================================================
# DRY-RUN CHECK
# =============================================================================

check_ohmyzsh_dry_run() {
    log_header "OH MY ZSH"
    
    # Check zsh
    if command_exists zsh; then
        log_info "zsh              installed ($(get_zsh_path))"
    else
        log_info "zsh              would install"
    fi
    
    # Check Oh My Zsh
    if is_ohmyzsh_installed; then
        log_info "Oh My Zsh        installed ($OH_MY_ZSH_DIR)"
    else
        log_info "Oh My Zsh        would install"
    fi
    
    # Check default shell
    if is_zsh_default_shell; then
        log_info "Default shell    zsh (already set)"
    else
        log_info "Default shell    would set to zsh"
    fi
}
