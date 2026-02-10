#!/usr/bin/env bash
# main.sh - Dotfiles bootstrap entry point
# Sets up development environment on a new machine

set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
# shellcheck source=scripts/utils.sh
source "$SCRIPT_DIR/scripts/utils.sh"

# shellcheck source=scripts/prerequisites.sh
source "$SCRIPT_DIR/scripts/prerequisites.sh"

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Show dry-run banner if applicable
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        if [[ "$GUM_AVAILABLE" == true ]]; then
            gum style --bold --foreground 99 --border double --padding "0 2" \
                "DRY-RUN MODE - No changes will be made"
        else
            echo "=========================================="
            echo "  DRY-RUN MODE - No changes will be made"
            echo "=========================================="
        fi
        echo ""
    fi
    
    # Show what we're about to do
    log_header "Dotfiles Bootstrap"
    log_info "OS: $(get_os)"
    log_info "Include work packages: $INCLUDE_WORK"
    log_info "Skip packages: $SKIP_PACKAGES"
    log_info "Skip stow: $SKIP_STOW"
    echo ""
    
    # Step 1: Prerequisites
    if [[ "$DRY_RUN" == true ]]; then
        check_prerequisites_dry_run
    else
        install_prerequisites
    fi
    
    # Ensure asdf is in PATH for this session (if prerequisites installed it)
    if [[ -d "$HOME/.asdf/bin" ]] && [[ ! "$PATH" =~ "$HOME/.asdf/bin" ]]; then
        export PATH="$HOME/.asdf/bin:$PATH"
    fi
    
    # Step 2: Package installation
    if [[ "$SKIP_PACKAGES" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/packages.sh" ]]; then
            # shellcheck source=scripts/packages.sh
            source "$SCRIPT_DIR/scripts/packages.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_packages_dry_run
            else
                install_packages
            fi
        else
            log_warning "packages.sh not found - skipping package installation"
        fi
    else
        log_info "Skipping package installation (--skip-packages)"
    fi
    
    # Step 3: Oh My Zsh setup (after packages, before dotfiles)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/ohmyzsh.sh" ]]; then
            # shellcheck source=scripts/ohmyzsh.sh
            source "$SCRIPT_DIR/scripts/ohmyzsh.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_ohmyzsh_dry_run
            else
                setup_ohmyzsh
            fi
        fi
    else
        log_info "Skipping Oh My Zsh setup (--skip-packages)"
    fi
    
    # Step 4: Dotfiles stow
    if [[ "$SKIP_STOW" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/stow.sh" ]]; then
            # shellcheck source=scripts/stow.sh
            source "$SCRIPT_DIR/scripts/stow.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_stow_dry_run
            else
                run_stow
            fi
        else
            log_warning "stow.sh not found - skipping dotfiles stow"
        fi
    else
        log_info "Skipping dotfiles stow (--skip-stow)"
    fi
    
    # Step 5: asdf setup (runtime environments and global packages)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/asdf.sh" ]]; then
            # shellcheck source=scripts/asdf.sh
            source "$SCRIPT_DIR/scripts/asdf.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_asdf_dry_run
            else
                setup_asdf
            fi
        fi
    else
        log_info "Skipping asdf setup (--skip-packages)"
    fi
    
    # Step 6: VSCode extensions (requires GUI packages installed first)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/vscode.sh" ]]; then
            # shellcheck source=scripts/vscode.sh
            source "$SCRIPT_DIR/scripts/vscode.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_vscode_dry_run
            else
                install_vscode_extensions
            fi
        fi
    else
        log_info "Skipping VSCode extensions (--skip-packages)"
    fi
    
    # Step 7: LazyVim setup (tied to --skip-packages flag)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/lazyvim.sh" ]]; then
            # shellcheck source=scripts/lazyvim.sh
            source "$SCRIPT_DIR/scripts/lazyvim.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_lazyvim_dry_run
            else
                install_lazyvim
            fi
        fi
    else
        log_info "Skipping LazyVim setup (--skip-packages)"
    fi
    
    # Step 8: kubectl krew setup (tied to --skip-packages flag)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        if [[ -f "$SCRIPT_DIR/scripts/krew.sh" ]]; then
            # shellcheck source=scripts/krew.sh
            source "$SCRIPT_DIR/scripts/krew.sh"
            if [[ "$DRY_RUN" == true ]]; then
                check_krew_dry_run
            else
                setup_krew
            fi
        fi
    else
        log_info "Skipping kubectl krew setup (--skip-packages)"
    fi
    
    # Step 9: Print manual steps
    echo ""
    if [[ "$DRY_RUN" == false ]]; then
        print_manual_steps
    fi
    
    # Done!
    echo ""
    if [[ "$DRY_RUN" == true ]]; then
        log_box "Run without --dry-run to apply changes."
    else
        log_success "Setup complete!"
    fi
}

# =============================================================================
# MANUAL STEPS
# =============================================================================

print_manual_steps() {
    local steps=""
    steps+="Manual Steps Required:"
    steps+=$'\n'
    steps+=$'\n'
    steps+="1. Install Github CLI dash extention:"
    steps+=$'\n'
    steps+="   gh extension install mislav/gh-dash"
    steps+=$'\n'
    steps+="2. Install tmux plugins"
    steps+=$'\n'
    steps+="   Execute tmux and then CRTL-a + I (capital i) to install tmux plugins via tpm"
    steps+=$'\n'
    steps+="3. [Optional] Install Nix to use Nix-Shells"
    steps+=$'\n'
    steps+="   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    steps+=$'\n'

    log_box "$steps"
}

# =============================================================================
# RUN
# =============================================================================

main "$@"
