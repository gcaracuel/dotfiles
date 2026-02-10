#!/usr/bin/env bash
# vscode.sh - Install VSCode extensions
# Idempotent: safe to run multiple times

# Source utils if not already sourced
if [[ -z "${UTILS_SOURCED:-}" ]]; then
    VSCODE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=utils.sh
    source "$VSCODE_SCRIPT_DIR/utils.sh"
fi

# =============================================================================
# PACKAGE LOADING FROM YAML
# =============================================================================

# Load VSCode extensions from packages.yaml into VSCODE_EXTENSIONS array
load_vscode_extensions() {
    VSCODE_EXTENSIONS=()
    
    if [[ ! -f "$PACKAGES_YAML" ]]; then
        log_warning "packages.yaml not found at $PACKAGES_YAML"
        return 0
    fi
    
    local extensions
    extensions=$(yq '.vscode_extensions[]? // empty' "$PACKAGES_YAML" 2>/dev/null) || true
    
    if [[ -n "$extensions" ]]; then
        while IFS= read -r extension; do
            # Remove surrounding quotes if present
            extension="${extension%\"}"
            extension="${extension#\"}"
            [[ -n "$extension" ]] && VSCODE_EXTENSIONS+=("$extension")
        done <<< "$extensions"
    fi
}

# Initialize extensions array (call load_vscode_extensions before using)
VSCODE_EXTENSIONS=()

# =============================================================================
# VSCODE FUNCTIONS
# =============================================================================

# Check if VSCode CLI is available
is_vscode_available() {
    command -v code &>/dev/null
}

# Check if a VSCode extension is installed
is_extension_installed() {
    local extension="$1"
    # Convert to lowercase for comparison (VSCode normalizes IDs to lowercase)
    local extension_lower="${extension,,}"
    code --list-extensions 2>/dev/null | grep -iq "^${extension_lower}$"
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

# Install VSCode extensions from packages.yaml
install_vscode_extensions() {
    log_header "Setting up VSCode extensions"
    
    # Load extensions from YAML
    load_vscode_extensions
    
    if [[ ${#VSCODE_EXTENSIONS[@]} -eq 0 ]]; then
        log_info "No VSCode extensions defined in packages.yaml"
        return 0
    fi
    
    log_info "VSCode extensions (${#VSCODE_EXTENSIONS[@]} total):"
    
    # Check if VSCode is available
    if ! is_vscode_available; then
        log_warning "VSCode CLI not available - install VSCode first (via GUI packages)"
        log_info "Skipping VSCode extensions installation"
        return 0
    fi
    
    local installed=0
    local failed=0
    
    for extension in "${VSCODE_EXTENSIONS[@]}"; do
        if is_extension_installed "$extension"; then
            log_success "$extension (already installed)"
            installed=$((installed + 1))
        else
            log_step "Installing extension: $extension"
            if code --install-extension "$extension" --force &>/dev/null; then
                log_success "$extension installed"
                installed=$((installed + 1))
            else
                log_warning "Failed to install $extension"
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo ""
    if [[ $failed -gt 0 ]]; then
        log_warning "VSCode extensions: $installed installed, $failed failed"
    else
        log_success "VSCode extensions complete"
    fi
}

# =============================================================================
# DRY-RUN CHECK
# =============================================================================

# Check what would be installed (dry-run mode)
check_vscode_dry_run() {
    log_header "VSCODE EXTENSIONS"
    
    # Load extensions from YAML
    load_vscode_extensions
    
    if [[ ${#VSCODE_EXTENSIONS[@]} -eq 0 ]]; then
        log_info "No VSCode extensions defined in packages.yaml"
        return 0
    fi
    
    # Check if VSCode is available
    if ! is_vscode_available; then
        log_warning "VSCode CLI not available (would skip extension installation)"
        return 0
    fi
    
    local installed=0
    local would_install=0
    
    echo "Extensions:"
    for extension in "${VSCODE_EXTENSIONS[@]}"; do
        if is_extension_installed "$extension"; then
            log_success "$extension (installed)"
            installed=$((installed + 1))
        else
            log_dry_run "$extension (would install)"
            would_install=$((would_install + 1))
        fi
    done
    
    echo ""
    log_info "VSCode summary: $installed installed, $would_install would install"
}
